@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  try $0.bootstrapDatabase()
})
struct CurationRoutingTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Gmail transport carries separate followed-Stream and loose-Primary roles")
  func separatesGmailRolesFromTransport() async throws {
    let activeStreamID = UUID(9_101)
    let pausedStreamID = UUID(9_102)
    let activePieceID = UUID(9_111)
    let pausedPieceID = UUID(9_112)
    let loosePieceID = UUID(9_113)
    let rssPieceID = UUID(9_114)

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: activeStreamID, name: "Morning", publisher: "Publisher", transport: .gmail,
          locator: "morning.example.com", followState: .active))
      }.execute(db)
      try Stream.insert {
        Stream.Draft(Stream(
          id: pausedStreamID, name: "Paused", publisher: "Publisher", transport: .gmail,
          locator: "paused.example.com", followState: .paused))
      }.execute(db)

      for pieceID in [activePieceID, pausedPieceID, loosePieceID, rssPieceID] {
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(
            id: pieceID, kind: pieceID == rssPieceID ? .article : .email,
            title: pieceID.uuidString, publisher: "Publisher",
            emailTreatment: pieceID == rssPieceID ? nil : .newsletter, createdAt: .distantPast))
        }.execute(db)
      }

      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_121), streamID: activeStreamID, transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: activePieceID))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_122), streamID: pausedStreamID, transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: pausedPieceID))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_123), transport: .gmail, acquiredAt: .distantPast,
          contentPieceID: loosePieceID))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_124), transport: .rss, acquiredAt: .distantPast,
          contentPieceID: rssPieceID))
      }.execute(db)
    }

    let snapshot = try await database.read { db in try CurationRouting.snapshot(in: db) }
    #expect(snapshot.followedGmailStreamContentPieceIDs == [activePieceID])
    #expect(snapshot.primaryGmailContentPieceIDs == [pausedPieceID, loosePieceID])
    #expect(snapshot.editionExcludedContentPieceIDs == [activePieceID, pausedPieceID, loosePieceID])
    #expect(!snapshot.editionExcludedContentPieceIDs.contains(rssPieceID))
  }

  @Test("Gmail Stream resolution and series identity share the normalized List-ID")
  func gmailLocatorIdentityStaysUnified() async throws {
    let streamID = UUID(9_201)
    let pieceID = UUID(9_202)
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: "message", threadID: "thread",
      rfcMessageID: nil, listUnsubscribe: nil, listID: "Morning <morning.example.com>",
      precedence: "bulk", senderAddress: "digest@example.com", sendingDomain: "example.com",
      dkimDomain: "example.com", toRecipientCount: 3, ccRecipientCount: 0)
    let provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: streamID, name: "Morning", publisher: "Publisher", transport: .gmail,
          locator: "Morning <morning.example.com>"))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: "Morning issue", publisher: "Publisher",
          emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_203), transport: .gmail, providerID: "gmail:message",
          acquiredAt: .distantPast, providerProvenance: provenanceJSON, contentPieceID: pieceID))
      }.execute(db)
    }

    let values = try await database.read { db in
      (
        try GmailStreamResolver.streamID(
          for: provenance, sender: "Digest <digest@example.com>", in: db),
        try GmailSeriesKey.seriesKey(forContentPieceID: pieceID, in: db)
      )
    }
    #expect(values.0 == streamID)
    #expect(values.1 == "morning.example.com")
  }
}
