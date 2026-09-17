import Dependencies
import Foundation
import SQLiteData

/// A read-only snapshot of Gmail's current Inbox. The client is injected so persistence and
/// normalization are deterministic in tests; the live constructor issues GET requests only.
public struct GmailInboxClient: Sendable {
  public var currentInbox: @Sendable () async throws -> GmailInboxSnapshot

  public init(currentInbox: @escaping @Sendable () async throws -> GmailInboxSnapshot) {
    self.currentInbox = currentInbox
  }

  public static func live(accessToken: String) -> Self {
    Self { try await GmailInboxAPI(accessToken: accessToken).currentInbox() }
  }
}

public struct GmailInboxSnapshot: Equatable, Sendable {
  public let accountID: String
  public let historyID: String?
  public let pageCount: Int
  public let messages: [GmailInboxMessage]

  public init(
    accountID: String,
    historyID: String? = nil,
    pageCount: Int = 1,
    messages: [GmailInboxMessage]
  ) {
    self.accountID = accountID
    self.historyID = historyID
    self.pageCount = pageCount
    self.messages = messages
  }
}

public struct GmailInboxMessage: Equatable, Sendable {
  public let id: String
  public let threadID: String
  public let headers: [GmailInboxHeader]
  public let bodyHTML: String?
  public let bodyPlainText: String?

  public init(
    id: String,
    threadID: String,
    headers: [GmailInboxHeader],
    bodyHTML: String? = nil,
    bodyPlainText: String? = nil
  ) {
    self.id = id
    self.threadID = threadID
    self.headers = headers
    self.bodyHTML = bodyHTML
    self.bodyPlainText = bodyPlainText
  }

  public func header(named name: String) -> String? {
    headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  var normalizedText: String? {
    if let bodyPlainText, !bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return HTMLText.normalizedText(from: bodyPlainText)
    }
    return HTMLText.normalizedText(from: bodyHTML)
  }

  var sourceText: String? { bodyHTML ?? bodyPlainText }
}

public struct GmailInboxHeader: Codable, Equatable, Sendable {
  public let name: String
  public let value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }
}

public struct GmailInboxIngestReport: Equatable, Sendable {
  public let accountID: String
  public let historyID: String?
  public let pageCount: Int
  public let messageCount: Int
  public let contentPieces: [ContentPiece]

  public init(snapshot: GmailInboxSnapshot, contentPieces: [ContentPiece]) {
    accountID = snapshot.accountID
    historyID = snapshot.historyID
    pageCount = snapshot.pageCount
    messageCount = snapshot.messages.count
    self.contentPieces = contentPieces
  }
}

public struct GmailInboxIngestor {
  @Dependency(\.uuid) private var uuid

  public let client: GmailInboxClient
  public let identityNamespace: UUID
  public let now: @Sendable () -> Date
  /// S8 processing is opt-in at this boundary so S4's read-only ingest remains independently
  /// testable and callers can surface a model failure without treating it as a Gmail failure.
  public let treatmentProcessor: EmailTreatmentProcessor?

  public init(
    client: GmailInboxClient,
    identityNamespace: UUID = ContentIdentity.cockpitNamespace,
    now: @escaping @Sendable () -> Date = Date.init,
    treatmentProcessor: EmailTreatmentProcessor? = nil
  ) {
    self.client = client
    self.identityNamespace = identityNamespace
    self.now = now
    self.treatmentProcessor = treatmentProcessor
  }

  @discardableResult
  public func ingest(into database: any DatabaseWriter) async throws -> GmailInboxIngestReport {
    let snapshot = try await client.currentInbox()
    let acquiredAt = now()
    let artifactIDs = snapshot.messages.map { _ in uuid() }
    let namespace = identityNamespace
    let pieces = try await database.write { db in
      let recorded = try zip(snapshot.messages, artifactIDs).map { message, artifactID in
        try Self.record(
          message: message,
          artifactID: artifactID,
          accountID: snapshot.accountID,
          acquiredAt: acquiredAt,
          namespace: namespace,
          in: db
        )
      }
      // A manually configured Gmail Stream may have been added after an earlier inbox read. Link
      // its retained source evidence before routing, then reroute only the affected curated mail.
      let reconciled = try GmailStreamResolver.linkUnresolvedArtifacts(in: db)
      // S5 routing is part of email ingest, so every new Gmail ContentPiece receives a visible
      // treatment immediately. It writes only Cockpit's local projection, never Gmail.
      return try EmailTreatmentOperations.classify(
        emailContentPieceIDs: recorded.map(\.id) + reconciled, in: db)
    }
    if let treatmentProcessor {
      _ = try? await treatmentProcessor.process(emailContentPieceIDs: pieces.map(\.id), in: database)
    }
    return GmailInboxIngestReport(snapshot: snapshot, contentPieces: pieces)
  }

  private static func record(
    message: GmailInboxMessage,
    artifactID: UUID,
    accountID: String,
    acquiredAt: Date,
    namespace: UUID,
    in db: Database
  ) throws -> ContentPiece {
    let providerID = stableProviderID(accountID: accountID, messageID: message.id)
    let existingID = ContentIdentity.derive(
      for: ContentIdentityInput(
        providerStableID: providerID,
        title: message.subject,
        publisher: message.sender,
        publishedAt: message.date
      ),
      namespace: namespace
    )
    let existing = try ContentPiece.find(existingID).fetchOne(db)
    let piece = ContentPiece(
      id: existingID,
      kind: .email,
      title: message.subject,
      creator: message.sender,
      publisher: message.sender,
      publishedAt: message.date ?? existing?.publishedAt,
      canonicalURL: nil,
      summary: existing?.summary,
      subjects: existing?.subjects,
      isSubstantivePrimary: existing?.isSubstantivePrimary,
      bodyCompleteness: BodyCompletenessDetector.detect(normalizedText: message.normalizedText)
        ?? existing?.bodyCompleteness,
      createdAt: existing?.createdAt ?? acquiredAt
    )
    try ContentPiece.upsert { ContentPiece.Draft(piece) }.execute(db)
    if let text = message.normalizedText {
      try NormalizedTextOperations.store(text, for: piece.id, in: db)
    }
    try NormalizedTextOperations.supplyLibraryTextIfMissing(for: piece.id, in: db)

    let provenance = GmailArtifactProvenance.make(accountID: accountID, message: message)
    let matchedStreamID = try GmailStreamResolver.streamID(
      for: provenance, sender: message.sender, in: db)
    if let artifact = try Artifact.where({ $0.providerID.eq(providerID) }).fetchOne(db) {
      // Provider IDs are account-scoped (`gmail:<account>:message:<id>`), so they identify one
      // Artifact regardless of whether this new deterministic lookup now finds its Stream.
      if artifact.streamID == nil, let matchedStreamID {
        try Artifact.find(artifact.id).update { $0.streamID = #bind(matchedStreamID) }.execute(db)
      }
    } else {
      let provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: artifactID,
            streamID: matchedStreamID,
            transport: .gmail,
            providerID: providerID,
            acquiredAt: acquiredAt,
            rawSourceText: message.sourceText,
            providerProvenance: provenanceJSON,
            contentPieceID: piece.id
          )
        )
      }.execute(db)
    }
    return piece
  }

  static func stableProviderID(accountID: String, messageID: String) -> String {
    "gmail:\(canonicalAccountID(accountID)):message:\(messageID)"
  }

  static func canonicalAccountID(_ accountID: String) -> String {
    accountID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}

private extension GmailInboxMessage {
  var subject: String { header(named: "Subject")?.trimmedNonEmpty ?? "(No subject)" }
  var sender: String { header(named: "From")?.trimmedNonEmpty ?? "Unknown sender" }
  var date: Date? { header(named: "Date").flatMap(GmailIngestDateParser.date(from:)) }
}

private enum GmailIngestDateParser {
  static func date(from value: String) -> Date? {
    let withoutComment = String(value.prefix { $0 != "(" }).trimmingCharacters(in: .whitespaces)
    for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = format
      if let date = formatter.date(from: withoutComment) { return date }
    }
    return nil
  }
}
