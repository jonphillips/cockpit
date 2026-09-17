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
    try $0.bootstrapDatabase()
  }
)
struct GmailIngestionTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Inbox messages become one provider Artifact and derived email ContentPiece")
  func inboxMessageUsesExistingPersistenceSpine() async throws {
    let snapshot = sampleSnapshot
    let ingestor = GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }),
      identityNamespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
      now: { Date(timeIntervalSince1970: 1) }
    )

    let first = try await ingestor.ingest(into: database)
    let second = try await ingestor.ingest(into: database)

    expectNoDifference(first.messageCount, 1)
    expectNoDifference(first.pageCount, 2)
    expectNoDifference(first.historyID, "history-7")
    expectNoDifference(first.contentPieces.map(\.id), second.contentPieces.map(\.id))
    let expectedProviderID = "gmail:jon@example.com:message:message-1"
    let expectedID = ContentIdentity.derive(
      for: ContentIdentityInput(providerStableID: expectedProviderID, title: "Inbox dispatch", publisher: "Dispatch <letters@example.com>"),
      namespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    )
    expectNoDifference(first.contentPieces.first?.id, expectedID)

    try await database.read { db in
      let persistedPiece = try ContentPiece.find(expectedID).fetchOne(db)
      let piece = try #require(persistedPiece)
      expectNoDifference(piece.kind, .email)
      expectNoDifference(piece.emailTreatment, .newsletter)
      expectNoDifference(piece.bodyCompleteness, .full)
      expectNoDifference(try NormalizedTextOperations.text(for: piece.id, in: db), "A readable email body.")
      let artifacts = try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
      expectNoDifference(artifacts.count, 1)
      let artifact = try #require(artifacts.first)
      expectNoDifference(artifact.id == piece.id, false)
      expectNoDifference(artifact.transport, .gmail)
      expectNoDifference(artifact.providerID, expectedProviderID)
      expectNoDifference(artifact.rawSourceText, "<p>A readable <strong>email</strong> body.</p>")
      let provenance = try JSONDecoder().decode(
        GmailArtifactProvenance.self, from: try #require(artifact.providerProvenance?.data(using: .utf8))
      )
      expectNoDifference(provenance.accountID, "jon@example.com")
      expectNoDifference(provenance.messageID, "message-1")
      expectNoDifference(provenance.threadID, "thread-1")
      expectNoDifference(provenance.rfcMessageID, "<rfc-1@example.com>")
      expectNoDifference(provenance.listUnsubscribe, "<https://example.com/unsubscribe>")
      expectNoDifference(provenance.listID, "Letters <letters.example.com>")
      expectNoDifference(provenance.precedence, "bulk")
      expectNoDifference(provenance.sendingDomain, "example.com")
      expectNoDifference(provenance.dkimDomain, "example.com")
      expectNoDifference(provenance.toRecipientCount, 2)
      expectNoDifference(provenance.ccRecipientCount, 1)
    }
  }

  @Test("Missing body is an honest teaser while classification headers remain readable")
  func bodylessMessageRetainsProvenance() async throws {
    let message = GmailInboxMessage(
      id: "message-2", threadID: "thread-2",
      headers: [
        GmailInboxHeader(name: "From", value: "Jordan <jordan@friends.example>"),
        GmailInboxHeader(name: "Subject", value: "Dinner"),
        GmailInboxHeader(name: "To", value: "jon@example.com"),
      ]
    )
    let snapshot = GmailInboxSnapshot(accountID: "jon@example.com", messages: [message])
    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)

    expectNoDifference(report.contentPieces.first?.bodyCompleteness, .teaser)
    let contentPieceID = try #require(report.contentPieces.first).id
    let artifact = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(contentPieceID) }.fetchOne(db)
    }
    let provenance = try JSONDecoder().decode(
      GmailArtifactProvenance.self, from: try #require(artifact?.providerProvenance?.data(using: .utf8))
    )
    expectNoDifference(provenance.sendingDomain, "friends.example")
    expectNoDifference(provenance.toRecipientCount, 1)
    expectNoDifference(provenance.ccRecipientCount, 0)
  }

  private var sampleSnapshot: GmailInboxSnapshot {
    GmailInboxSnapshot(
      accountID: "Jon@Example.com", historyID: "history-7", pageCount: 2,
      messages: [
        GmailInboxMessage(
          id: "message-1", threadID: "thread-1",
          headers: [
            GmailInboxHeader(name: "From", value: "Dispatch <letters@example.com>"),
            GmailInboxHeader(name: "Subject", value: "Inbox dispatch"),
            GmailInboxHeader(name: "Date", value: "Tue, 16 Sep 2026 10:00:00 -0400"),
            GmailInboxHeader(name: "Message-ID", value: "<rfc-1@example.com>"),
            GmailInboxHeader(name: "List-Unsubscribe", value: "<https://example.com/unsubscribe>"),
            GmailInboxHeader(name: "List-ID", value: "Letters <letters.example.com>"),
            GmailInboxHeader(name: "Precedence", value: "bulk"),
            GmailInboxHeader(name: "DKIM-Signature", value: "v=1; d=example.com; s=mail;"),
            GmailInboxHeader(name: "To", value: "jon@example.com, assistant@example.com"),
            GmailInboxHeader(name: "Cc", value: "copy@example.com"),
          ],
          bodyHTML: "<p>A readable <strong>email</strong> body.</p>"
        ),
      ]
    )
  }
}
