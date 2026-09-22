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
    #expect(snapshot.todayTriageGmailContentPieceIDs == [pausedPieceID, loosePieceID])
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

  @Test("Locator routing fans one publisher into roles and preserves mute")
  func routesPublisherSubfeedsByListID() async throws {
    let morningID = UUID(9_301)
    let opinionID = UUID(9_302)
    let foodID = UUID(9_303)
    let sender = "Washington Post <news@washingtonpost.com>"
    let pieces = [
      (morningID, "Morning <list.washingtonpost.com/morning>"),
      (opinionID, "Opinion <list.washingtonpost.com/opinions>"),
      (foodID, "Food <list.washingtonpost.com/food>"),
    ]

    try await database.write { db in
      for (pieceID, listID) in pieces {
        let provenance = GmailArtifactProvenance(
          accountID: "jon@example.com", messageID: pieceID.uuidString, threadID: "thread",
          rfcMessageID: nil, listUnsubscribe: nil, listID: listID, precedence: "bulk",
          senderAddress: sender, sendingDomain: "washingtonpost.com", dkimDomain: nil,
          toRecipientCount: 1, ccRecipientCount: 0)
        let provenanceJSON = String(
          data: try JSONEncoder().encode(provenance), encoding: .utf8)
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(
            id: pieceID, kind: .email, title: listID, publisher: "Washington Post",
            emailTreatment: .newsletter, createdAt: .distantPast))
        }.execute(db)
        try Artifact.insert {
          Artifact.Draft(Artifact(
            id: UUID(), transport: .gmail, acquiredAt: .distantPast,
            providerProvenance: provenanceJSON,
            contentPieceID: pieceID))
        }.execute(db)
      }
    }

    let snapshot = try await database.read { db in try CurationRouting.snapshot(in: db) }
    #expect(snapshot.role(for: morningID) == .dailyNews)
    #expect(snapshot.role(for: opinionID) == .opinion)
    #expect(snapshot.role(for: foodID) == nil)
    #expect(snapshot.mutedContentPieceIDs == [foodID])
  }

  @Test("Author and transport do not change a locator's configured role")
  func roleIsLocatorBasedAcrossTransport() async throws {
    let rssID = UUID(9_401)
    let gmailID = UUID(9_402)
    let streamID = UUID(9_403)
    let locator = "substack.com/slowboring"

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: streamID, name: "Slow Boring", publisher: "Matthew Yglesias",
          transport: .rss, locator: locator))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: rssID, kind: .article, title: "RSS issue", publisher: "Matthew Yglesias",
          createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), streamID: streamID, transport: .rss, acquiredAt: .distantPast,
          contentPieceID: rssID))
      }.execute(db)

      let provenance = GmailArtifactProvenance(
        accountID: "jon@example.com", messageID: gmailID.uuidString, threadID: "thread",
        rfcMessageID: nil, listUnsubscribe: nil, listID: "Slow Boring <\(locator)>",
        precedence: "bulk", senderAddress: "Matthew Yglesias <slow@example.com>",
        sendingDomain: "substack.com", dkimDomain: nil, toRecipientCount: 1, ccRecipientCount: 0)
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: gmailID, kind: .email, title: "Gmail issue", publisher: "Matthew Yglesias",
          emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      let provenanceJSON = String(
        data: try JSONEncoder().encode(provenance), encoding: .utf8)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail, acquiredAt: .distantPast,
          providerProvenance: provenanceJSON,
          contentPieceID: gmailID))
      }.execute(db)
    }

    let snapshot = try await database.read { db in try CurationRouting.snapshot(in: db) }
    #expect(snapshot.role(for: rssID) == .opinion)
    #expect(snapshot.role(for: gmailID) == .opinion)
    #expect(CurationRouting.role(for: locator) == .opinion)
    #expect(CurationRouting.role(for: "SUBSTACK.COM/SLOWBORING") == .opinion)
  }

  @Test("Multi-artifact pieces resolve once using explicit locator precedence")
  func resolvesMultiArtifactPieceDeterministically() async throws {
    let pieceID = UUID(9_501)
    let streamID = UUID(9_502)

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: streamID, name: "Slow Boring", publisher: "Matthew Yglesias",
          transport: .rss, locator: "substack.com/slowboring"))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: "Converged issue", publisher: "Washington Post",
          emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_503), streamID: streamID, transport: .rss,
          acquiredAt: .distantPast, contentPieceID: pieceID))
      }.execute(db)

      let provenance = GmailArtifactProvenance(
        accountID: "jon@example.com", messageID: "multi-artifact", threadID: "thread",
        rfcMessageID: nil, listUnsubscribe: nil, listID: "Food <list.washingtonpost.com/food>",
        precedence: "bulk", senderAddress: "news@washingtonpost.com",
        sendingDomain: "washingtonpost.com", dkimDomain: nil, toRecipientCount: 1,
        ccRecipientCount: 0)
      let provenanceJSON = String(
        data: try JSONEncoder().encode(provenance), encoding: .utf8)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_504), transport: .gmail, acquiredAt: .distantPast,
          providerProvenance: provenanceJSON,
          contentPieceID: pieceID))
      }.execute(db)
    }

    let snapshot = try await database.read { db in try CurationRouting.snapshot(in: db) }
    #expect(snapshot.role(for: pieceID) == .opinion)
    #expect(!snapshot.mutedContentPieceIDs.contains(pieceID))
  }

  @Test("An explicit sub-feed edit persists and changes the next routing snapshot")
  func editableRoutingRuleReroutesPieces() async throws {
    let locator = "list.washingtonpost.com/morning-edit"
    let pieceID = UUID(9_601)

    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: "Morning", publisher: "Washington Post",
          emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      let provenance = GmailArtifactProvenance(
        accountID: "jon@example.com", messageID: "editable", threadID: "thread",
        rfcMessageID: nil, listUnsubscribe: nil, listID: "Morning <\(locator)>",
        precedence: "bulk", senderAddress: "news@washingtonpost.com",
        sendingDomain: "washingtonpost.com", dkimDomain: nil, toRecipientCount: 1,
        ccRecipientCount: 0)
      let provenanceJSON = String(
        data: try JSONEncoder().encode(provenance), encoding: .utf8)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_602), transport: .gmail, acquiredAt: .distantPast,
          providerProvenance: provenanceJSON, contentPieceID: pieceID))
      }.execute(db)

      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: locator, role: .opinion), in: db)
    }

    let initial = try await database.read { db in
      try CurationRouting.snapshot(in: db).role(for: pieceID)
    }
    #expect(initial == .opinion)

    try await database.write { db in
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "Morning <\(locator)>", role: .opinion, isMuted: true), in: db)
    }

    let updated = try await database.read { db in
      let snapshot = try CurationRouting.snapshot(in: db)
      return (snapshot.role(for: pieceID), snapshot.mutedContentPieceIDs.contains(pieceID))
    }
    #expect(updated.0 == nil)
    #expect(updated.1)
  }
}
