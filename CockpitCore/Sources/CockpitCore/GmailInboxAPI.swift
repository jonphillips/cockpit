import Foundation

/// The transport is intentionally isolated from persistence: every request is an authenticated
/// Gmail GET, and `GmailInboxIngestor` owns the resulting canonical writes.
struct GmailInboxAPI {
  let accessToken: String

  /// Gmail bills each `messages.get` at 20 quota units against a 6,000 unit/user/minute ceiling.
  /// Fetching every Inbox message at once trips HTTP 429, so per-message reads run through a
  /// bounded window rather than an unbounded fan-out.
  static let maxConcurrentMessageReads = 6

  func currentInbox() async throws -> GmailInboxSnapshot {
    async let profile: GmailProfile = get(path: "profile")
    let listed = try await listMessages()
    let reads = try await fetchMessages(ids: listed.ids)
    let resolvedProfile = try await profile
    return GmailInboxSnapshot(
      accountID: resolvedProfile.emailAddress, historyID: resolvedProfile.historyID,
      pageCount: listed.pageCount, messages: reads.messages, failures: reads.failures
    )
  }

  /// Returns the changed Primary-Inbox messages from Gmail's history feed. The profile request
  /// verifies the persisted account before Cockpit touches its local state; the returned profile
  /// history ID is the committed cursor only after every message is persisted by the ingestor.
  ///
  /// Primary membership is resolved by the *same* `category:primary` query the bounded backfill uses,
  /// not a per-message label heuristic. Gmail folds whichever category tabs the account has disabled
  /// (commonly Updates/Forums) back into the Primary tab, so a label-exclusion filter and
  /// `category:primary` disagree exactly for that mail — a divergence that made the delta silently drop
  /// Primary messages the backfill would have kept. Asking Gmail the one authoritative question keeps
  /// the two reads in lockstep.
  func inboxChanges(
    accountID: String, since historyID: String, promotionsSince: Date? = nil
  ) async throws -> GmailInboxSnapshot {
    async let profile: GmailProfile = get(path: "profile")
    let history = try await listHistory(since: historyID)
    let resolvedProfile = try await profile
    guard GmailInboxIngestor.canonicalAccountID(resolvedProfile.emailAddress)
      == GmailInboxIngestor.canonicalAccountID(accountID)
    else { throw GmailInboxError.accountChanged }

    let primaryInboxIDs = try await primaryInboxMessageIDs()
    let promotionsInboxIDs: Set<String>
    if let promotionsSince {
      promotionsInboxIDs = try await promotionsInboxMessageIDs(since: promotionsSince)
    } else {
      promotionsInboxIDs = []
    }
    let membership = Self.changedInboxMembership(
      changedIDs: history.messageIDs, primaryInboxIDs: primaryInboxIDs,
      promotionsInboxIDs: promotionsInboxIDs)
    let targetIDs = history.messageIDs.filter { membership[$0] != nil }
    let reads = try await fetchMessages(ids: targetIDs, categories: membership)
    let heldIDs = Set(primaryInboxIDs).union(promotionsInboxIDs)
    return GmailInboxSnapshot(
      accountID: resolvedProfile.emailAddress,
      historyID: resolvedProfile.historyID,
      pageCount: history.pageCount,
      messages: reads.messages,
      failures: reads.failures,
      departedMessageIDs: Self.departedChangedIDs(
        changedIDs: history.messageIDs, inboxMessageIDs: heldIDs)
    )
  }

  /// Changed messages currently held by the Primary or epoch-scoped Promotions membership. If
  /// Gmail ever returns an id in both searches, Primary is the more specific attention category.
  static func changedInboxMembership(
    changedIDs: [String], primaryInboxIDs: Set<String>, promotionsInboxIDs: Set<String>
  ) -> [String: GmailInboxCategory] {
    var result: [String: GmailInboxCategory] = [:]
    for id in changedIDs {
      if primaryInboxIDs.contains(id) { result[id] = .primary }
      else if promotionsInboxIDs.contains(id) { result[id] = .promotions }
    }
    return result
  }

  /// The intersection at the heart of the delta: keep only changed messages that are currently in the
  /// Primary set. Membership decides inclusion, so a message Gmail tagged `CATEGORY_UPDATES`/`FORUMS`
  /// but shows in Primary is kept, and a message that just left Primary (archived/trashed) is dropped.
  static func primaryChangedIDs(changedIDs: [String], primaryInboxIDs: Set<String>) -> [String] {
    changedIDs.filter(primaryInboxIDs.contains)
  }

  /// The complement of `primaryChangedIDs`: changed messages that are *no longer* in the Primary set.
  /// These left the Inbox in Gmail (archived/trashed/re-categorized) since the cursor, so the ingestor
  /// clears them from Today. This is the read half of the fix for "trashed in Gmail still shows in
  /// Cockpit" — the same intersection, kept rather than discarded.
  static func departedChangedIDs(changedIDs: [String], primaryInboxIDs: Set<String>) -> [String] {
    changedIDs.filter { !primaryInboxIDs.contains($0) }
  }

  static func departedChangedIDs(changedIDs: [String], inboxMessageIDs: Set<String>) -> [String] {
    changedIDs.filter { !inboxMessageIDs.contains($0) }
  }
}

extension GmailInboxAPI {
  /// Reads each message with at most `maxConcurrentMessageReads` requests in flight, refilling the
  /// window as each completes. Order is not preserved; ingestion derives identity per message.
  private func fetchMessages(
    ids: [String], categories: [String: GmailInboxCategory] = [:]
  ) async throws -> GmailMessageReads {
    try Task.checkCancellation()
    var result = GmailMessageReads()
    result.messages.reserveCapacity(ids.count)
    await withTaskGroup(of: GmailMessageReadResult.self) { group in
      var iterator = ids.makeIterator()
      for _ in 0..<Self.maxConcurrentMessageReads {
        guard let id = iterator.next() else { break }
        group.addTask { await readMessage(id: id, category: categories[id] ?? .primary) }
      }
      while let fetched = await group.next() {
        switch fetched {
        case let .success(message): result.messages.append(message)
        case let .failure(failure): result.failures.append(failure)
        }
        if let id = iterator.next() {
          group.addTask { await readMessage(id: id, category: categories[id] ?? .primary) }
        }
      }
    }
    try Task.checkCancellation()
    return result
  }

  private func readMessage(id: String, category: GmailInboxCategory) async -> GmailMessageReadResult {
    do {
      return .success(try await message(id: id, category: category))
    } catch is CancellationError {
      return .failure(GmailInboxMessageFailure(messageID: id, description: "Read cancelled."))
    } catch {
      return .failure(GmailInboxMessageFailure(messageID: id, description: error.localizedDescription))
    }
  }

  /// A viability probe reads the Primary tab only, bounded, not the whole mailbox. Gmail's category
  /// tabs (Primary/Promotions/Social/…) all carry the `INBOX` label, so `labelIds=INBOX` alone pulls
  /// every promotional message too; a large Promotions backlog then trips `userRateLimitExceeded`
  /// (each `messages.get` bills 5 quota units against a per-minute per-user ceiling).
  ///
  /// The Primary tab is "INBOX minus the other categories", and Gmail does not stamp
  /// `CATEGORY_PERSONAL` on every Primary message (newsletters and other uncategorized mail carry no
  /// category label at all), so filtering by that label under-reads. The `category:primary` search
  /// operator resolves to the tab as the user sees it. Primary is the attention surface S4 needs; the
  /// other categories are in scope for later stages (promo sifting, retail/wine Finds) but their
  /// read/quota/delta strategy is a Gate-3 ADR decision, not S4's — see docs/m4-s4-gmail-observations.md.
  private static let maxMessagesToRead = 100

  private func listMessages() async throws -> (ids: [String], pageCount: Int) {
    let query = [
      URLQueryItem(name: "labelIds", value: "INBOX"),
      URLQueryItem(name: "q", value: "category:primary"),
      URLQueryItem(name: "maxResults", value: String(Self.maxMessagesToRead)),
    ]
    let page: GmailMessageList = try await get(path: "messages", query: query)
    let ids = Array((page.messages?.map(\.id) ?? []).prefix(Self.maxMessagesToRead))
    return (ids, 1)
  }

  /// The current Primary set, by the same `category:primary` query as the backfill. Delta changes are
  /// recent and Primary is returned most-recent-first, so one bounded page covers any changed message.
  private func primaryInboxMessageIDs() async throws -> Set<String> {
    let query = [
      URLQueryItem(name: "labelIds", value: "INBOX"),
      URLQueryItem(name: "q", value: "category:primary"),
      URLQueryItem(name: "maxResults", value: "500"),
    ]
    let page: GmailMessageList = try await get(path: "messages", query: query)
    return Set(page.messages?.map(\.id) ?? [])
  }

  /// One bounded page covers any changed message. `after:` uses Unix seconds rather than a
  /// date-only query, whose timezone interpretation is ambiguous.
  private func promotionsInboxMessageIDs(since date: Date) async throws -> Set<String> {
    let query = Self.promotionsQuery(since: date)
    let page: GmailMessageList = try await get(path: "messages", query: query)
    return Set(page.messages?.map(\.id) ?? [])
  }

  static func promotionsQuery(since date: Date) -> [URLQueryItem] {
    let epochSeconds = Int(date.timeIntervalSince1970.rounded(.down))
    return [
      URLQueryItem(name: "labelIds", value: "INBOX"),
      URLQueryItem(name: "q", value: "category:promotions after:\(epochSeconds)"),
      URLQueryItem(name: "maxResults", value: "500"),
    ]
  }

  private func listHistory(since historyID: String) async throws -> (messageIDs: [String], pageCount: Int) {
    var messageIDs: [String] = []
    var seenMessageIDs = Set<String>()
    var pageToken: String?
    var pageCount = 0
    repeat {
      var query = [
        URLQueryItem(name: "startHistoryId", value: historyID),
        URLQueryItem(name: "labelId", value: "INBOX"),
        URLQueryItem(name: "maxResults", value: "500"),
      ]
      if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
      let page: GmailHistoryList = try await get(path: "history", query: query)
      pageCount += 1
      for id in page.messageIDs where seenMessageIDs.insert(id).inserted {
        messageIDs.append(id)
      }
      pageToken = page.nextPageToken
      try Task.checkCancellation()
    } while pageToken != nil
    return (messageIDs, pageCount)
  }

  private func message(id: String, category: GmailInboxCategory = .primary) async throws -> GmailInboxMessage {
    let response: GmailMessageResponse = try await get(
      path: "messages/\(id)", query: [URLQueryItem(name: "format", value: "full")]
    )
    return GmailInboxMessage(
      id: response.id, threadID: response.threadID, headers: response.payload.headers,
      bodyHTML: response.payload.text(matching: "text/html"),
      bodyPlainText: response.payload.text(matching: "text/plain"),
      labelIDs: response.labelIDs,
      inboxCategory: category
    )
  }

  func get<Response: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> Response {
    var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/\(path)")!
    components.queryItems = query
    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    for attempt in 0...Self.maxRetries {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw GmailInboxError.noResponse }
      if 200..<300 ~= http.statusCode {
        return try JSONDecoder().decode(Response.self, from: data)
      }
      let failure = GmailInboxError(status: http.statusCode, body: data)
      guard failure.isRetryable, attempt < Self.maxRetries else { throw failure }
      try await Task.sleep(for: Self.retryDelay(response: http, attempt: attempt))
    }
    throw GmailInboxError.noResponse
  }

  private static let maxRetries = 4

  /// Honors a `Retry-After` header (seconds) when present, otherwise backs off exponentially.
  private static func retryDelay(response: HTTPURLResponse, attempt: Int) -> Duration {
    if let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(value) {
      return .seconds(seconds)
    }
    return .seconds(Double(1 << attempt))
  }
}
