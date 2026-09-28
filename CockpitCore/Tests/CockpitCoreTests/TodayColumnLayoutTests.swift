import CockpitCore
import Testing

@Suite struct TodayColumnLayoutTests {
  @Test func splitsConsecutiveSectionsInOrderAndBalancesColumnHeights() {
    let sections = [
      TodayColumnLayout.Section(id: "opinion", sortOrder: 3, rowCount: 6),
      TodayColumnLayout.Section(id: "for-you", sortOrder: 0, rowCount: 4),
      TodayColumnLayout.Section(id: "tail", sortOrder: 4, rowCount: 2),
      TodayColumnLayout.Section(id: "daily-news", sortOrder: 2, rowCount: 3),
      TodayColumnLayout.Section(id: "transactional", sortOrder: 1, rowCount: 1),
    ]

    let columns = TodayColumnLayout.columns(for: sections, count: 3)
    let orderedIDs = sections.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)

    #expect(columns.count == 3)
    #expect(columns.flatMap { $0.map(\.id) } == orderedIDs)
    let heights = columns.map { $0.reduce(0) { $0 + $1.rowCount } }
    #expect((heights.max() ?? 0) - (heights.min() ?? 0) <= (sections.map(\.rowCount).max() ?? 0))
  }

  @Test func oneSectionUsesOneColumnAndEmptyInputUsesNoColumns() {
    let section = TodayColumnLayout.Section(id: "only", sortOrder: 0, rowCount: 3)
    #expect(TodayColumnLayout.columns(for: [section], count: 3) == [[section]])
    #expect(TodayColumnLayout.columns(for: [], count: 3).isEmpty)
    #expect(TodayColumnLayout.columns(for: [section], count: 0).isEmpty)
  }
}
