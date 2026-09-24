import SQLiteData

extension ContentPieceReaderModel {
  public func saveForLater() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.saveForLater(id, at: date, in: $0) }
  }

  public func addToLibrary() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.addToLibrary(id, at: date, in: $0) }
  }

  public func correctIsSubstantivePrimary(to value: Bool) async {
    guard let id = row?.id else { return }
    await run {
      try ContentPiece.find(id).update { $0.isSubstantivePrimary = #bind(value) }.execute($0)
    }
  }
}
