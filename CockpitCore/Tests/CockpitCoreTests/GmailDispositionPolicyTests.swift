@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
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
  private func seedOffer(id: String, withFind: Bool) async throws -> ContentPiece.ID {
    let pieceID = try await seedGmailMessage(id: id)
    try await database.write { db in
      try ContentPiece.find(pieceID)
        .update { $0.emailTreatment = #bind(EmailTreatment.offer) }.execute(db)
      if withFind {
        try PendingFind.insert {
          PendingFind.Draft(
            PendingFind(
              id: UUID(7_000), contentPieceID: pieceID, kind: "wine",
              name: "2023 Example Estate Pinot Noir", descriptor: "A limited allocation offer.",
              rationale: "The offer identifies a specific bottle to consider later."
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
