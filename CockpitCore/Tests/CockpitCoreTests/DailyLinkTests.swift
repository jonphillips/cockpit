import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing
@testable import CockpitCore

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_000)
    try $0.bootstrapDatabase()
  }
)
struct DailyLinkTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Daily links add, move, and delete with dense stable order")
  func orderedLifecycle() async throws {
    let ids = [UUID(12_001), UUID(12_002), UUID(12_003)]
    try await database.write { db in
      try DailyLinkOperations.add(.init(title: "One", url: "https://one.example"), id: ids[0], at: .distantPast, in: db)
      try DailyLinkOperations.add(.init(title: "Two", url: "https://two.example"), id: ids[1], at: .distantPast, in: db)
      try DailyLinkOperations.add(.init(title: "Three", url: "https://three.example"), id: ids[2], at: .distantPast, in: db)
      try DailyLinkOperations.update(
        .init(id: ids[1], title: "Two revised", url: "https://revised.example", symbolName: "globe"),
        in: db)
      try DailyLinkOperations.move(from: 0, to: 3, in: db)
    }
    var links = try await database.read { db in try DailyLinkOperations.orderedLinks(in: db) }
    #expect(links.map(\.id) == [ids[1], ids[2], ids[0]])
    #expect(links.map(\.sortOrder) == [0, 1, 2])
    #expect(links[0].title == "Two revised")
    #expect(links[0].url == "https://revised.example")
    #expect(links[0].symbolName == "globe")

    try await database.write { db in try DailyLinkOperations.delete(ids[2], in: db) }
    links = try await database.read { db in try DailyLinkOperations.orderedLinks(in: db) }
    #expect(links.map(\.id) == [ids[1], ids[0]])
    #expect(links.map(\.sortOrder) == [0, 1])
  }

  @Test("Daily link URLs allow only trimmed http and https URLs with hosts")
  func validatesURLs() throws {
    #expect(try DailyLinkOperations.validatedURL("https://apple.news/Tabc") == "https://apple.news/Tabc")
    #expect(try DailyLinkOperations.validatedURL("https://example.com") == "https://example.com")
    #expect(try DailyLinkOperations.validatedURL(" http://x.y/ ") == "http://x.y/")
    for invalid in ["applenews://channel", "ftp://example.com", "example.com", ""] {
      #expect(throws: DailyLinkOperations.Failure.invalidURL) {
        try DailyLinkOperations.validatedURL(invalid)
      }
    }
  }

  @Test("Visited state rolls over at local midnight")
  func localDayBoundary() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let visit = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 23, minute: 59))!
    let beforeMidnight = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 23, minute: 59, second: 30))!
    let nextDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 0, minute: 1))!
    let link = DailyLink(
      id: UUID(12_004), title: "News", url: "https://apple.news/Tabc", symbolName: "newspaper",
      sortOrder: 0, lastVisitedAt: visit, createdAt: .distantPast)
    #expect(link.isVisited(on: beforeMidnight, calendar: calendar))
    #expect(!link.isVisited(on: nextDay, calendar: calendar))
  }

  @Test("Recording a visit changes only lastVisitedAt")
  func recordsOnlyVisitTime() async throws {
    let id = UUID(12_005)
    let createdAt = Date(timeIntervalSince1970: 123)
    try await database.write { db in
      try DailyLinkOperations.add(
        .init(title: "News", url: " https://apple.news/Tabc ", symbolName: "newspaper"),
        id: id, at: createdAt, in: db)
      try DailyLinkOperations.recordVisit(id, at: Date(timeIntervalSince1970: 456), in: db)
    }
    let link = try await database.read { db in try DailyLink.find(id).fetchOne(db) }
    #expect(link?.title == "News")
    #expect(link?.url == "https://apple.news/Tabc")
    #expect(link?.symbolName == "newspaper")
    #expect(link?.sortOrder == 0)
    #expect(link?.createdAt == createdAt)
    #expect(link?.lastVisitedAt == Date(timeIntervalSince1970: 456))
  }
}
