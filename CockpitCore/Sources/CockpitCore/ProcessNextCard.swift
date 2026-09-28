/// The next item shown in Process' reader footer. Position is local to that item's role section.
public struct ProcessNextCard: Equatable, Sendable {
  public let row: TodayReadingQueueRequest.Row
  public let roleIndex: Int
  public let roleCount: Int

  public static func after(
    _ contentPieceID: ContentPiece.ID,
    in rows: [TodayReadingQueueRequest.Row]
  ) -> ProcessNextCard? {
    guard let index = rows.firstIndex(where: { $0.id == contentPieceID }),
      rows.indices.contains(index + 1)
    else { return nil }
    let next = rows[index + 1]
    let sectionRows = rows.filter { $0.role == next.role }
    guard let roleIndex = sectionRows.firstIndex(where: { $0.id == next.id }) else { return nil }
    return ProcessNextCard(row: next, roleIndex: roleIndex + 1, roleCount: sectionRows.count)
  }

  public init(row: TodayReadingQueueRequest.Row, roleIndex: Int, roleCount: Int) {
    self.row = row
    self.roleIndex = roleIndex
    self.roleCount = roleCount
  }
}
