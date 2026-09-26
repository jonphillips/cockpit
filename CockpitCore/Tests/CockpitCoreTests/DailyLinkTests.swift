import CustomDump
import Dependencies
import DependenciesTestSupport
import CoreGraphics
import Foundation
import ImageIO
import SQLiteData
import Testing
import UniformTypeIdentifiers
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
      try DailyLinkOperations.reorder(moving: [ids[0]], before: ids[2], in: db)
      #expect(try DailyLinkOperations.orderedLinks(in: db).map(\.id) == [ids[1], ids[0], ids[2]])
      try DailyLinkOperations.reorder(moving: [ids[2]], before: ids[1], in: db)
      #expect(try DailyLinkOperations.orderedLinks(in: db).map(\.id) == [ids[2], ids[1], ids[0]])
      try DailyLinkOperations.reorder(moving: [ids[2]], before: nil, in: db)
    }
    var links = try await database.read { db in try DailyLinkOperations.orderedLinks(in: db) }
    #expect(links.map(\.id) == [ids[1], ids[0], ids[2]])
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

  @Test("Reordering keeps moved links together, ignores unknown ids, and appends on a moved anchor")
  func reorderedEdges() {
    let links = (0..<4).map { index in
      DailyLink(
        id: UUID(12_010 + index), title: "\(index)", url: "https://\(index).example",
        sortOrder: index, createdAt: .distantPast)
    }
    let ids = links.map(\.id)
    #expect(
      DailyLinkOperations.reordered(links, moving: [ids[3], ids[1]], before: ids[0]).map(\.id)
        == [ids[1], ids[3], ids[0], ids[2]])
    #expect(
      DailyLinkOperations.reordered(links, moving: [ids[1]], before: ids[1]).map(\.id)
        == [ids[0], ids[2], ids[3], ids[1]])
    #expect(
      DailyLinkOperations.reordered(links, moving: [UUID(99_999)], before: ids[0]).map(\.id) == ids)
  }

  @Test("Thumbnails normalize any photo to a small square JPEG")
  func normalizesThumbnail() throws {
    let wide = try Self.png(width: 1_200, height: 600)
    let thumbnail = try DailyLinkThumbnail.make(from: wide)
    let source = try #require(CGImageSourceCreateWithData(thumbnail as CFData, nil))
    #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == DailyLinkThumbnail.pixelSize)
    #expect(image.height == DailyLinkThumbnail.pixelSize)
    #expect(thumbnail.count < DailyLinkThumbnail.maximumBytes)

    let small = try DailyLinkThumbnail.make(from: Self.png(width: 40, height: 90))
    let smallImage = try #require(
      CGImageSourceCreateWithData(small as CFData, nil).flatMap {
        CGImageSourceCreateImageAtIndex($0, 0, nil)
      })
    #expect(smallImage.width == 40)
    #expect(smallImage.height == 40)

    #expect(throws: DailyLinkThumbnail.Failure.unreadableImage) {
      try DailyLinkThumbnail.make(from: Data("not an image".utf8))
    }
  }

  @Test("Thumbnails save, replace, and clear with the link; oversized data is rejected")
  func thumbnailLifecycle() async throws {
    let id = UUID(12_020)
    let first = try DailyLinkThumbnail.make(from: Self.png(width: 300, height: 300))
    try await database.write { db in
      try DailyLinkOperations.add(
        .init(title: "News", url: "https://apple.news/Tabc", thumbnail: first),
        id: id, at: .distantPast, in: db)
    }
    var link = try await database.read { db in try DailyLink.find(id).fetchOne(db) }
    #expect(link?.thumbnail == first)

    let draft = try #require(link.map(DailyLinkDraft.init(editing:)))
    #expect(draft.thumbnail == first)

    var clearing = draft
    clearing.thumbnail = nil
    let cleared = clearing
    try await database.write { db in try DailyLinkOperations.update(cleared, in: db) }
    link = try await database.read { db in try DailyLink.find(id).fetchOne(db) }
    #expect(link?.thumbnail == nil)

    var oversizing = draft
    oversizing.thumbnail = Data(count: DailyLinkThumbnail.maximumBytes + 1)
    let oversized = oversizing
    await #expect(throws: DailyLinkOperations.Failure.thumbnailTooLarge) {
      try await database.write { db in try DailyLinkOperations.update(oversized, in: db) }
    }
  }

  private static func png(width: Int, height: Int) throws -> Data {
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
  }
}
