import SQLiteData

extension EmailTreatmentProcessor {
  /// Processes pending Gmail details at the moved locator through canonical CurationRouting.
  @discardableResult
  public func processUnextractedPieces(
    for locator: String, in database: any DatabaseWriter
  ) async throws -> [EmailTreatmentDetails] {
    let canonicalLocator = CurationRouting.canonicalLocator(locator)
    let ids = try await database.read { db in
      let extractedIDs = Set(try EmailTreatmentDetails.all.fetchAll(db)
        .filter { $0.offerSummary != nil }.map(\.contentPieceID))
      let pieceIDs = Set(try Artifact.where { $0.transport.eq(StreamTransport.gmail) }
        .fetchAll(db).compactMap(\.contentPieceID))
      var pendingIDs: [ContentPiece.ID] = []
      for id in pieceIDs where !extractedIDs.contains(id) {
        if try CurationRouting.resolution(for: id, in: db).locator == canonicalLocator {
          pendingIDs.append(id)
        }
      }
      return pendingIDs
    }
    return try await process(emailContentPieceIDs: ids, in: database)
  }
}
