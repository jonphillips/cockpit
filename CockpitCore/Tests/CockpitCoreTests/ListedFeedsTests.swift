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
    let fallback = UUID(97_113)
    let old = UUID(97_112)
    try await database.write { db in
      for stream in [firstStream, secondStream, screened] {
        try Stream.insert { Stream.Draft(stream) }.execute(db)
      }
      for piece in [
        ContentPiece(id: recent, kind: .article, title: "Recent", publisher: "Publisher",
          publishedAt: recentDate, canonicalURL: "https://example.com/recent", createdAt: now),
        ContentPiece(id: fallback, kind: .article, title: "Fallback date", publisher: "Publisher",
          canonicalURL: "https://example.com/fallback", createdAt: now),
        ContentPiece(id: old, kind: .article, title: "Old", publisher: "Publisher",
          publishedAt: oldDate, canonicalURL: "https://example.com/old", createdAt: now),
      ] {
        try ContentPiece.insert {
          ContentPiece.Draft(piece)
        }.execute(db)
      }
      for (id, stream, acquired, text): (UUID, CockpitCore.Stream, Date, String?) in [
        (UUID(97_121), firstStream, now, "<p>First &amp; clear.</p>"),
        (UUID(97_122), secondStream, now.addingTimeInterval(1), "Second source."),
        (UUID(97_123), screened, now, "Screened artifact."),
        (UUID(97_124), firstStream, now, "Too old."),
        (UUID(97_125), secondStream, now.addingTimeInterval(-167 * 3_600), nil),
        (UUID(97_126), secondStream, now.addingTimeInterval(-160 * 3_600), "Later artifact."),
      ] {
        try Artifact.insert {
          Artifact.Draft(Artifact(id: id, streamID: stream.id, transport: stream.transport,
            acquiredAt: acquired, rawSourceText: text,
            contentPieceID: id == UUID(97_124) ? old : (id == UUID(97_125) || id == UUID(97_126) ? fallback : recent)))
        }.execute(db)
      }
    }

    let request = ListedFeedsRequest(now: now, calendar: calendar)
    var value = try await database.read { db in try request.fetch(db) }
    #expect(value.hasListedStreams)
    #expect(value.items.count == 2)
    #expect(value.items.first?.id == recent)
    #expect(value.items.first?.streamID == firstStream.id)
    #expect(value.items.first?.description == "First & clear.")
    let fallbackItem = try #require(value.items.first(where: { $0.id == fallback }))
    #expect(fallbackItem.streamID == secondStream.id)
    #expect(fallbackItem.listedDate == now.addingTimeInterval(-167 * 3_600))
    #expect(fallbackItem.description == "")
    #expect(value.totalNewCount == 2)
    #expect(value.sources.first(where: { $0.id == firstStream.id })?.newCount == 1)
    #expect(value.sources.first(where: { $0.id == secondStream.id })?.newCount == 1)
    #expect(value.showsPublisherLabel)
    try await database.write { db in
      try Stream.find(secondStream.id).update { $0.publisher = #bind("NYT") }.execute(db)
    }
    let singlePublisherValue = try await database.read { db in try request.fetch(db) }
    #expect(!singlePublisherValue.showsPublisherLabel)
    try await database.write { db in
      try Stream.find(secondStream.id).update { $0.publisher = #bind("Eater") }.execute(db)
    }
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
    #expect(plannedIDs.contains(fallback))
    try await database.write { db in
      for id in [firstStream.id, secondStream.id] {
        try Stream.find(id).update { $0.handling = #bind(.listed) }.execute(db)
      }
    }

    var clockNow = now
    let model = ListedFeedsModel(database: database, now: { clockNow })
    try await model.reload()
    #expect(model.items.count == 2)
    clockNow = now.addingTimeInterval(2 * 3_600)
    try await model.reload()
    #expect(model.items.isEmpty)
    clockNow = now
    try await model.reload()
    try await model.recordOpened(id: recent)
    try await model.recordOpened(id: recent)
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.totalNewCount == 1)
    let firstOpen = try await database.read { db in try ListedPieceState.find(recent).fetchOne(db)?.openedAt }
    try await model.dismissAll(streamID: firstStream.id)
    try await model.reload()
    #expect(model.items.map(\.id) == [fallback])
    try await model.dismiss(id: recent)
    try await model.undo()
    try await model.reload()
    #expect(Set(model.items.map(\.id)) == [recent, fallback])
    try await model.undo()
    value = try await database.read { db in try request.fetch(db) }
    #expect(Set(value.items.map(\.id)) == [recent, fallback])
    #expect(try await database.read { db in try ListedPieceState.find(recent).fetchOne(db)?.openedAt } == firstOpen)
    try await model.dismissAll()
    try await model.reload()
    value = try await database.read { db in try request.fetch(db) }
    #expect(value.items.isEmpty)
    try await model.undo()
    try await model.reload()
    try await model.undo()
    value = try await database.read { db in try request.fetch(db) }
    #expect(Set(value.items.map(\.id)) == [recent, fallback])
  }

  @Test("Listed day groups roll over at midnight and sort newest first")
  func dayGrouping() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = ISO8601DateFormatter().date(from: "2026-10-03T00:15:00Z")!
    func item(_ id: Int, _ title: String, _ date: String) -> ListedFeedsRequest.Item {
      ListedFeedsRequest.Item(
        id: UUID(98_000 + id), title: title, creator: nil, canonicalURL: nil,
        listedDate: ISO8601DateFormatter().date(from: date)!, streamID: UUID(98_100),
        streamName: "Travel", isOpened: false, description: "")
    }
    let groups = ListedFeedGrouping.dayGroups([
      item(1, "Today", "2026-10-03T00:05:00Z"),
      item(2, "Yesterday", "2026-10-02T23:55:00Z"),
      item(3, "Earlier", "2026-09-28T12:00:00Z"),
    ], now: now, calendar: calendar)

    #expect(groups.map(\.title) == ["Today", "Yesterday", "Monday"])
    #expect(groups.map { $0.items.first?.title } == ["Today", "Yesterday", "Earlier"])
  }
}
