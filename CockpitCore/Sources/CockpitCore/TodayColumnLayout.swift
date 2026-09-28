import Foundation

/// Assigns whole Today sections to columns while preserving their reading order within each
/// column. The caller supplies stable IDs and sort order so role sections and the Edition tail can
/// share the same balancing rule without becoming a persisted domain hierarchy.
public enum TodayColumnLayout {
  public struct Section: Equatable, Sendable, Identifiable {
    public let id: String
    public let sortOrder: Int
    public let rowCount: Int

    public init(id: String, sortOrder: Int, rowCount: Int) {
      self.id = id
      self.sortOrder = sortOrder
      self.rowCount = max(0, rowCount)
    }
  }

  /// Splits the ordered sections into consecutive columns. The primary objective minimizes the
  /// tallest column; ties prefer the smallest height spread. Equal scores retain the first split
  /// found, making the result deterministic.
  public static func columns(for sections: [Section], count: Int) -> [[Section]] {
    guard count > 0, !sections.isEmpty else { return [] }

    let ordered = sections.enumerated().sorted {
      if $0.element.sortOrder != $1.element.sortOrder {
        return $0.element.sortOrder < $1.element.sortOrder
      }
      return $0.offset < $1.offset
    }.map(\.element)

    let columnCount = min(count, ordered.count)
    var bestColumns: [[Section]] = []
    var bestTallest = Int.max
    var bestSpread = Int.max

    func consider(_ columns: [[Section]]) {
      let heights = columns.map { $0.reduce(0) { $0 + $1.rowCount } }
      let tallest = heights.max() ?? 0
      let spread = tallest - (heights.min() ?? 0)
      if tallest < bestTallest || (tallest == bestTallest && spread < bestSpread) {
        bestColumns = columns
        bestTallest = tallest
        bestSpread = spread
      }
    }

    func split(start: Int, remainingColumns: Int, columns: [[Section]]) {
      if remainingColumns == 1 {
        consider(columns + [Array(ordered[start...])])
        return
      }

      let lastEnd = ordered.count - remainingColumns + 1
      guard start < lastEnd else { return }
      for end in (start + 1)...lastEnd {
        split(
          start: end,
          remainingColumns: remainingColumns - 1,
          columns: columns + [Array(ordered[start..<end])])
      }
    }

    split(start: 0, remainingColumns: columnCount, columns: [])
    return bestColumns
  }
}
