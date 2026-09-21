@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  try $0.bootstrapDatabase()
})
struct StreamHandlingTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Stream Handling lists every piece linked through the Stream, including Gmail issues")
  func listsStreamPieces() async throws {
    let streamID = UUID(9_401)
    let gmailPieceID = UUID(9_402)
    let rssPieceID = UUID(9_403)
    let loosePieceID = UUID(9_404)

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: streamID, name: "Morning Brief", publisher: "Publisher", transport: .gmail,
          locator: "morning.example.com", handlingGuidance: "Read every issue.", followState: .active
        ))
      }.execute(db)

      for (pieceID, title, kind) in [
        (gmailPieceID, "Email issue", ContentKind.email),
        (rssPieceID, "RSS issue", ContentKind.article),
        (loosePieceID, "Loose mail", ContentKind.email),
      ] {
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(
            id: pieceID, kind: kind, title: title, publisher: "Publisher",
            publishedAt: .distantPast,
            createdAt: .distantPast
          ))
        }.execute(db)
      }

      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_411), streamID: streamID, transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: gmailPieceID
        ))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_412), streamID: streamID, transport: .rss,
          acquiredAt: .distantPast, contentPieceID: rssPieceID
        ))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_413), transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: loosePieceID
        ))
      }.execute(db)
    }

    let rows = try await database.read { db in
      try StreamHandlingRequest(streamID: streamID).fetch(db).rows
    }
    #expect(Set(rows.map(\.id)) == [gmailPieceID, rssPieceID])
    #expect(rows.map(\.title).contains("Loose mail") == false)
  }

  @Test("Today keeps loose and paused Gmail mail while routing active Stream mail to Stream Handling")
  func todayExcludesOnlyActiveFollowedStreamMail() async throws {
    let activeStreamID = UUID(9_421)
    let pausedStreamID = UUID(9_422)
    let activePieceID = UUID(9_431)
    let pausedPieceID = UUID(9_432)
    let loosePieceID = UUID(9_433)

    try await database.write { db in
      try Stream.insert {
        Stream.Draft(Stream(
          id: activeStreamID, name: "Active", publisher: "Publisher", transport: .gmail,
          locator: "active.example.com", followState: .active
        ))
      }.execute(db)
      try Stream.insert {
        Stream.Draft(Stream(
          id: pausedStreamID, name: "Paused", publisher: "Publisher", transport: .gmail,
          locator: "paused.example.com", followState: .paused
        ))
      }.execute(db)

      for pieceID in [activePieceID, pausedPieceID, loosePieceID] {
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(
            id: pieceID, kind: .email, title: pieceID.uuidString, publisher: "Publisher",
            emailTreatment: .newsletter, createdAt: .distantPast
          ))
        }.execute(db)
      }

      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_441), streamID: activeStreamID, transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: activePieceID
        ))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_442), streamID: pausedStreamID, transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: pausedPieceID
        ))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9_443), transport: .gmail,
          acquiredAt: .distantPast, contentPieceID: loosePieceID
        ))
      }.execute(db)
    }

    let rows = try await database.read { db in try TodayRequest().fetch(db).rows }
    #expect(Set(rows.map(\.id)) == [pausedPieceID, loosePieceID])
    #expect(rows.contains(where: { $0.id == activePieceID }) == false)
  }
}
