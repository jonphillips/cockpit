@testable import CockpitCore
import CustomDump
import Foundation
import Testing

@Suite("Today reading queue")
struct TodayReadingQueueTests {
  @Test("reading list width is clamped to the usable divider range")
  func dividerWidthClamping() {
    #expect(ReadingPaneWidth.clamped(100) == ReadingPaneWidth.minimum)
    #expect(ReadingPaneWidth.clamped(ReadingPaneWidth.defaultValue) == ReadingPaneWidth.defaultValue)
    #expect(ReadingPaneWidth.clamped(900) == ReadingPaneWidth.maximum)
  }

  @Test("queue order is one role-priority sequence across section boundaries")
  func rolePriorityOrder() {
    let rows = [
      TodayReadingQueueRequest.Row(
        id: UUID(10_003), title: "Offer", publisher: "Shop", role: .offers,
        arrivedAt: Date(timeIntervalSince1970: 300)),
      TodayReadingQueueRequest.Row(
        id: UUID(10_005), title: "Food", publisher: "Publisher", role: .food,
        arrivedAt: Date(timeIntervalSince1970: 250)),
      TodayReadingQueueRequest.Row(
        id: UUID(10_001), title: "Opinion", publisher: "Author", role: .opinion,
        arrivedAt: Date(timeIntervalSince1970: 100)),
      TodayReadingQueueRequest.Row(
        id: UUID(10_002), title: "News", publisher: "Publisher", role: .dailyNews,
        arrivedAt: Date(timeIntervalSince1970: 200)),
      TodayReadingQueueRequest.Row(
        id: UUID(10_004), title: "For you", publisher: "Person", role: .forYou,
        arrivedAt: Date(timeIntervalSince1970: 400)),
    ]

    expectNoDifference(
      ReadingQueueOrdering.ordered(rows).map(\.role),
      [.forYou, .dailyNews, .opinion, .food, .offers]
    )
  }

  @Test("rows within a role stay newest first with stable ID tie-breaking")
  func stableWithinRoleOrder() {
    let date = Date(timeIntervalSince1970: 100)
    let rows = [
      TodayReadingQueueRequest.Row(
        id: UUID(10_012), title: "B", publisher: "Publisher", role: .opinion, arrivedAt: date),
      TodayReadingQueueRequest.Row(
        id: UUID(10_011), title: "A", publisher: "Publisher", role: .opinion, arrivedAt: date),
      TodayReadingQueueRequest.Row(
        id: UUID(10_013), title: "New", publisher: "Publisher", role: .opinion,
        arrivedAt: Date(timeIntervalSince1970: 200)),
    ]

    #expect(ReadingQueueOrdering.ordered(rows).map(\.id) == [UUID(10_013), UUID(10_011), UUID(10_012)])
  }
}
