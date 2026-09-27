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

  /// Greedily places each section, in sort order, in the currently shortest column. Ties go to
  /// the leading column, which makes the result stable and keeps the first section on the left.
  public static func columns(for sections: [Section], count: Int) -> [[Section]] {
    guard count > 0, !sections.isEmpty else { return [] }

    let ordered = sections.enumerated().sorted {
      if $0.element.sortOrder != $1.element.sortOrder {
        return $0.element.sortOrder < $1.element.sortOrder
      }
      return $0.offset < $1.offset
    }.map(\.element)

    var columns = Array(repeating: [Section](), count: count)
    var heights = Array(repeating: 0, count: count)
    for section in ordered {
      let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
      columns[column].append(section)
      heights[column] += section.rowCount
    }
    return columns
  }
}
