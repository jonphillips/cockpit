@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMClientKit
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 10_000)
    try $0.bootstrapDatabase()
  }
)
struct GmailDispositionPolicyTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("An established offer policy Trashes an offer with a committed Find, logged and reversible (D1/D3)")
  func offerPolicyTrashesThroughBarrier() async throws {
    let pieceID = try await seedOffer(id: "message-offer", withFind: true)
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
    }
    let log = CallLog()

    let applied = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(in: database)

    expectNoDifference(log.calls, ["trash:message-offer"])
    expectNoDifference(applied.map(\.operation), [.trash])
    expectNoDifference(applied.first?.providerID, "gmail:jon@example.com:message:message-offer")
    _ = pieceID
  }

  @Test("An offer with no committed Find is left in place — the barrier blocks the policy (D1)")
  func offerPolicyRespectsBarrier() async throws {
    _ = try await seedOffer(id: "message-offer-nofind", withFind: false)
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
    }
    let log = CallLog()

    let applied = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(in: database)

    expectNoDifference(log.calls, [])
    expectNoDifference(applied.isEmpty, true)
  }

  @Test("Only confirmed or handed-off Finds satisfy the offer policy barrier")
  func offerBarrierRequiresConfirmation() async throws {
    let pending = try await seedOffer(id: "find-pending", state: .pending)
    let confirmed = try await seedOffer(id: "find-confirmed", state: .confirmed)
    let handedOff = try await seedOffer(id: "find-handed-off", state: .handedOff)
    let dismissed = try await seedOffer(id: "find-dismissed", state: .dismissed)

    let candidates = try await database.read { db in
      try GmailDispositionPolicyOperations.candidatePieceIDs(for: .offerWithFind, in: db)
    }
    #expect(!candidates.contains(pending))
    #expect(candidates.contains(confirmed))
    #expect(candidates.contains(handedOff))
    #expect(!candidates.contains(dismissed))
  }

  @Test("Re-persisting a proposal preserves confirmed and dismissed state")
  func persistDoesNotDowngradeState() async throws {
    let confirmedPiece = try await seedGmailMessage(id: "repersist-confirmed")
    let dismissedPiece = try await seedGmailMessage(id: "repersist-dismissed")
    let confirmedFind = JudgmentFind(
      kind: "wine", name: "Confirmed bottle", descriptor: "Updated descriptor",
      rationale: "Updated rationale", sourceURL: nil, hints: [:])
    let dismissedFind = JudgmentFind(
      kind: "wine", name: "Dismissed bottle", descriptor: "Updated descriptor",
      rationale: "Updated rationale", sourceURL: nil, hints: [:])
    try await database.write { db in
      try PendingFindOperations.persist([confirmedFind], for: confirmedPiece, in: db)
      try PendingFindOperations.persist([dismissedFind], for: dismissedPiece, in: db)
    }
    let ids = try await database.read { db in
      (
        try PendingFind.where { $0.contentPieceID.eq(confirmedPiece) }.fetchOne(db)?.id,
        try PendingFind.where { $0.contentPieceID.eq(dismissedPiece) }.fetchOne(db)?.id
      )
    }
    let confirmedID = try #require(ids.0)
    let dismissedID = try #require(ids.1)
    try await database.write { db in
      try PendingFindOperations.confirm(confirmedID, in: db)
      try PendingFindOperations.dismiss(dismissedID, in: db)
      try PendingFindOperations.persist([confirmedFind, dismissedFind], for: confirmedPiece, in: db)
      try PendingFindOperations.persist([dismissedFind], for: dismissedPiece, in: db)
    }
    let states = try await database.read { db in
      (
        try PendingFind.find(confirmedID).fetchOne(db)?.state,
        try PendingFind.find(dismissedID).fetchOne(db)?.state
      )
    }
    #expect(states.0 == .confirmed)
    #expect(states.1 == .dismissed)
  }

  @MainActor
  @Test("Reader confirmation reports policy match for queue Trash and Undo")
  func confirmingFindAppliesEnabledPolicy() async throws {
    let pieceID = try await seedOffer(id: "confirm-applies", state: .pending)
    _ = try await seedGmailMessage(id: "confirm-applies-adjacent")
    let findID = try await database.read { db in
      try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)?.id
    }
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
    }
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
      $0.date.now = .distantPast
    } operation: {
      let model = ContentPieceReaderModel(contentPieceID: pieceID)
      try await model.$content.load()
      try await model.$pendingFindContent.load()
      #expect(model.pendingFind?.id == findID)
      let shouldTrash = await model.confirmPendingFind()
      #expect(shouldTrash)
      #expect(model.pendingFind == nil)
      #expect(model.errorMessage == nil)

      // Confirmation establishes eligibility only. The queue owns the provider action, Undo, and
      // selection advance, matching Archive/Trash from the toolbar.
      #expect(log.calls.isEmpty)
      let queue = TodayReadingQueueModel()
      try await queue.$content.load()
      let row = try #require(queue.rows.first { $0.id == pieceID })
      let expectedNext = try #require(ReadingQueueSelection.neighbour(of: pieceID, in: queue.rows))
      queue.selectedContentPieceID = pieceID
      await queue.trash(row)
      #expect(queue.selectedContentPieceID == expectedNext)
      #expect(queue.lastDisposition?.contentPieceID == pieceID)
      #expect(!queue.rows.contains { $0.id == pieceID })
    }
    let entries = try await database.read { db in try GmailDispositionLogEntry.fetchAll(db) }
    expectNoDifference(log.calls, ["trash:confirm-applies"])
    #expect(entries.count == 1)
    #expect(entries.first?.operation == .trash)
  }

  @Test("Confirming a Find with the offer policy disabled does not dispose it")
  func confirmingWithDisabledPolicyDoesNothing() async throws {
    let pieceID = try await seedOffer(id: "confirm-disabled", state: .pending)
    let findID = try await database.read { db in
      try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)?.id
    }
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
      try GmailDispositionPolicyOperations.setEnabled(.offerWithFind, false, in: db)
      try PendingFindOperations.confirm(try #require(findID), in: db)
    }
    let log = CallLog()
    let applied = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(forContentPieceID: pieceID, in: database)
    expectNoDifference(log.calls, [])
    #expect(applied.isEmpty)
  }

  @Test("A full ingest's model-proposed Find does not satisfy the policy barrier")
  func ingestProposalDoesNotDisposeOffer() async throws {
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
    }
    let message = GmailInboxMessage(
      id: "ingest-proposal", threadID: "thread-ingest-proposal",
      headers: [
        GmailInboxHeader(name: "From", value: "Wine Shop <offers@example.com>"),
        GmailInboxHeader(name: "Subject", value: "Fall wine allocation offer"),
        GmailInboxHeader(name: "List-ID", value: "Offers <offers.example.com>"),
      ], bodyHTML: "<p>2023 Example Estate Pinot Noir allocation. Shop now.</p>")
    let processor = EmailTreatmentProcessor(modelClient: StubModelClient { _ in
      ModelResponse(text: #"{"summary":"A Pinot Noir allocation.","find":{"kind":"wine","name":"2023 Example Estate Pinot Noir","descriptor":"A bottle allocation.","rationale":"A specific wine offer.","sourceURL":"https://example.com/pinot","hints":{}}}"#)
    })
    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: {
        GmailInboxSnapshot(accountID: "jon@example.com", messages: [message])
      }),
      now: { .distantPast }, treatmentProcessor: processor
    ).ingest(into: database)
    let pieceID = try #require(report.contentPieces.first?.id)
    let find = try await database.read { db in
      try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)
    }
    #expect(find?.state == .pending)
    let log = CallLog()
    let applied = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(in: database)
    expectNoDifference(log.calls, [])
    #expect(applied.isEmpty)
  }

  @Test("An established login-code policy Trashes an ephemeral transactional message (D1)")
  func loginCodePolicyTrashesEphemeral() async throws {
    _ = try await seedLoginCode(id: "message-otp")
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.loginCode, at: .distantPast, in: db)
    }
    let log = CallLog()

    _ = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(in: database)

    expectNoDifference(log.calls, ["trash:message-otp"])
  }

  @Test("With no policy established, matching messages are classified but never disposed (D2)")
  func noPolicyMeansNoAuthority() async throws {
    let offerID = try await seedOffer(id: "message-offer-unowned", withFind: true)
    _ = try await seedLoginCode(id: "message-otp-unowned")
    let log = CallLog()

    let applied = try await GmailDispositionPolicyService(client: log.client, now: { .distantPast })
      .applyEnabledPolicies(in: database)

    // Nothing disposed and nothing logged: authority never arises from classification alone.
    expectNoDifference(log.calls, [])
    expectNoDifference(applied.isEmpty, true)
    let logged = try await database.read { db in try GmailDispositionLogEntry.fetchCount(db) }
    expectNoDifference(logged, 0)

    // Yet the classifier can still *propose*: the offer is a candidate for the un-established policy.
    let candidates = try await database.read { db in
      try GmailDispositionPolicyOperations.candidatePieceIDs(for: .offerWithFind, in: db)
    }
    expectNoDifference(candidates, [offerID])
  }

  @Test("Moving newsletter mail to Offers does not widen offer-disposition candidates")
  func roleMoveDoesNotAuthorizeOfferDisposition() async throws {
    let pieceID = try await seedOffer(id: "section-moved-newsletter", withFind: true)
    try await database.write { db in
      try ContentPiece.find(pieceID)
        .update { $0.emailTreatment = #bind(EmailTreatment.newsletter) }.execute(db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "sender@example.com", role: .offers), in: db)
    }

    let values = try await database.read { db in
      (
        try CurationRouting.snapshot(in: db).role(for: pieceID),
        try GmailDispositionPolicyOperations.candidatePieceIDs(for: .offerWithFind, in: db)
      )
    }
    #expect(values.0 == .offers)
    #expect(!values.1.contains(pieceID))
  }

  @Test("Turning a policy off halts future dispositions without un-disposing past ones (D3/D4)")
  func disablingHaltsFutureOnly() async throws {
    _ = try await seedLoginCode(id: "message-otp-1")
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.loginCode, at: .distantPast, in: db)
    }
    let log = CallLog()
    let service = GmailDispositionPolicyService(client: log.client, now: { .distantPast })

    _ = try await service.applyEnabledPolicies(in: database)
    // Re-running with the policy still on does not re-Trash the same message (once per message).
    _ = try await service.applyEnabledPolicies(in: database)
    expectNoDifference(log.calls, ["trash:message-otp-1"])

    // Turn it off, then a new matching message arrives.
    try await database.write { db in
      try GmailDispositionPolicyOperations.setEnabled(.loginCode, false, in: db)
    }
    _ = try await seedLoginCode(id: "message-otp-2")
    _ = try await service.applyEnabledPolicies(in: database)

    // No new disposition, and the earlier one is untouched (disabling is not an Undo).
    expectNoDifference(log.calls, ["trash:message-otp-1"])
    let entries = try await database.read { db in try GmailDispositionLogEntry.all.fetchAll(db) }
    expectNoDifference(entries.count, 1)
    expectNoDifference(entries.first?.reversedAt, nil)
    // The persistence is one small record per policy kind, not a rules engine.
    let policyCount = try await database.read { db in try GmailDispositionPolicy.fetchCount(db) }
    expectNoDifference(policyCount, 1)
  }

  // MARK: - Helpers

  @discardableResult
  private func seedOffer(
    id: String, withFind: Bool = true, state: PendingFindState = .confirmed
  ) async throws -> ContentPiece.ID {
    let pieceID = try await seedGmailMessage(id: id)
    try await database.write { db in
      try ContentPiece.find(pieceID)
        .update { $0.emailTreatment = #bind(EmailTreatment.offer) }.execute(db)
      if withFind {
        try PendingFind.insert {
          PendingFind.Draft(
            PendingFind(
              id: ContentIdentity.uuidV5(namespace: ContentIdentity.cockpitNamespace, name: id),
              contentPieceID: pieceID, kind: "wine",
              name: "2023 Example Estate Pinot Noir", descriptor: "A limited allocation offer.",
              rationale: "The offer identifies a specific bottle to consider later.", state: state
            )
          )
        }.execute(db)
      }
    }
    return pieceID
  }

  @discardableResult
  private func seedLoginCode(id: String) async throws -> ContentPiece.ID {
    let pieceID = try await seedGmailMessage(id: id)
    try await database.write { db in
      try ContentPiece.find(pieceID).update {
        $0.emailTreatment = #bind(EmailTreatment.transactional)
        $0.emailTransactionalKind = #bind(EmailTransactionalKind.ephemeral)
      }.execute(db)
    }
    return pieceID
  }

  private func seedGmailMessage(id: String) async throws -> ContentPiece.ID {
    let message = GmailInboxMessage(
      id: id, threadID: "thread-\(id)",
      headers: [
        GmailInboxHeader(name: "From", value: "Sender <sender@example.com>"),
        GmailInboxHeader(name: "Subject", value: "Subject \(id)"),
      ],
      bodyHTML: "<p>A readable body for \(id).</p>"
    )
    let snapshot = GmailInboxSnapshot(accountID: "jon@example.com", messages: [message])
    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    return try #require(report.contentPieces.first).id
  }
}
