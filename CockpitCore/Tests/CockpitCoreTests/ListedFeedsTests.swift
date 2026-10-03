@testable import CockpitCore
import Dependencies
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  try $0.bootstrapDatabase()
})
@MainActor
struct ListedFeedsTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Listed posture persists, clears Essential, and rejects Gmail")
  func streamPosture() async throws {
    let streamID = UUID(97_001)
    let areaID = UUID(97_002)
    let draft = StreamDraft(
      name: "Listed", publisher: "Publisher", transport: .rss, locator: "https://example.com/feed",
      handling: .listed, isEssential: true)
    try await database.write { db in
      try StreamOperations.save(draft, streamID: streamID, interestAreaID: areaID, in: db)
      let maybeStream = try Stream.find(streamID).fetchOne(db)
      let stream = try #require(maybeStream)
      #expect(stream.handling == .listed)
      #expect(stream.isEssential == false)
      #expect(throws: StreamOperations.Failure.listedRequiresFeedTransport) {
        try StreamOperations.save(
          StreamDraft(name: "Mail", publisher: "Publisher", transport: .gmail,
            locator: "sender@example.com", handling: .listed),
          streamID: UUID(97_003), interestAreaID: areaID, in: db)
      }
    }
  }

  @Test("Window, ownership, description, opened counts, and dismiss undo are deterministic")
  func readModelAndState() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let fixedCalendar = calendar
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let recentDate = fixedCalendar.date(byAdding: .hour, value: -167, to: now)!
    let oldDate = fixedCalendar.date(byAdding: .hour, value: -169, to: now)!
    let firstStream = Stream(id: UUID(97_101), name: "A Feed", publisher: "NYT", transport: .rss,
      locator: "https://nyt.example/feed", handling: .listed)
    let secondStream = Stream(id: UUID(97_102), name: "B Feed", publisher: "Eater", transport: .atom,
      locator: "https://eater.example/feed", handling: .listed)
    let screened = Stream(id: UUID(97_103), name: "Screened", publisher: "NYT", transport: .rss,
      locator: "https://screened.example/feed")
    let recent = UUID(97_111)
    let old = UUID(97_112)
    try await database.write { db in
      for stream in [firstStream, secondStream, screened] {
        try Stream.insert { Stream.Draft(stream) }.execute(db)
      }
      for (id, title, publishedAt) in [
        (recent, "Recent", recentDate),
        (old, "Old", oldDate),
      ] {
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(id: id, kind: .article, title: title, publisher: "Publisher",
            publishedAt: publishedAt, canonicalURL: "https://example.com/\(title.lowercased())", createdAt: now))
        }.execute(db)
      }
      for (id, stream, acquired, text) in [
        (UUID(97_121), firstStream, now, "<p>First &amp; clear.</p>"),
        (UUID(97_122), secondStream, now.addingTimeInterval(1), "Second source."),
        (UUID(97_123), screened, now, "Screened artifact."),
        (UUID(97_124), firstStream, now, "Too old."),
      ] {
        try Artifact.insert {
          Artifact.Draft(Artifact(id: id, streamID: stream.id, transport: stream.transport,
            acquiredAt: acquired, rawSourceText: text, contentPieceID: id == UUID(97_124) ? old : recent))
        }.execute(db)
      }
    }

    let request = ListedFeedsRequest(now: now, calendar: calendar)
    var value = try await database.read { db in try request.fetch(db) }
    #expect(value.items.count == 1)
    #expect(value.items.first?.id == recent)
    #expect(value.items.first?.streamID == firstStream.id)
    #expect(value.items.first?.description == "First & clear.")
    #expect(value.totalNewCount == 1)
    #expect(value.sources.first(where: { $0.id == firstStream.id })?.newCount == 1)
    #expect(value.sources.first(where: { $0.id == secondStream.id })?.newCount == 0)
    #expect(value.showsPublisherLabel)
    #expect(try await database.read { db in try ListedFeeds.contentPieceIDs(in: db) }.contains(recent))
    let previousEdition = UUID(97_131)
    try await database.write { db in
      try Edition.insert { Edition.Draft(Edition(id: previousEdition, date: now)) }.execute(db)
      try EditionEntry.insert {
        EditionEntry.Draft(EditionEntry(id: UUID(97_132), editionID: previousEdition,
          contentPieceID: recent, section: .forYou, rank: 1, entryState: .carried,
          firstAdmittedEditionID: previousEdition))
      }.execute(db)
    }
    var plannedIDs = try await database.read { db in
      try EditionPlanner().buildPlan(previousEditionID: previousEdition, since: nil, in: db).candidates.map(\.id)
    }
    #expect(!plannedIDs.contains(recent))
    try await database.write { db in
      for id in [firstStream.id, secondStream.id] {
        try Stream.find(id).update { $0.handling = #bind(.following) }.execute(db)
      }
    }
    plannedIDs = try await database.read { db in
      try EditionPlanner().buildPlan(previousEditionID: previousEdition, since: nil, in: db).candidates.map(\.id)
    }
    #expect(plannedIDs.contains(recent))
    try await database.write { db in
      for id in [firstStream.id, secondStream.id] {
        try Stream.find(id).update { $0.handling = #bind(.listed) }.execute(db)
      }
    }

    let model = ListedFeedsModel(database: database, now: { now })
    try await model.recordOpened(id: recent)
    try await model.recordOpened(id: recent)
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.totalNewCount == 0)
    let firstOpen = try await database.read { db in try ListedPieceState.find(recent).fetchOne(db)?.openedAt }
    try await model.dismissAll(streamID: firstStream.id)
    try await model.undo()
    try await model.undo()
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.items.map(\.id) == [recent])
    #expect(try await database.read { db in try ListedPieceState.find(recent).fetchOne(db)?.openedAt } == firstOpen)
    try await model.dismissAll()
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.items.isEmpty)
    try await model.undo()
    try await model.undo()
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.items.map(\.id) == [recent])
  }
}
