import Foundation

extension TodayReadingQueueModel {
  public func markPresented(_ contentPieceID: ContentPiece.ID) {
    guard rows.contains(where: { $0.id == contentPieceID }) else { return }
    presentedProcessContentPieceIDs.insert(contentPieceID)
  }

  public func selectPrevious() {
    guard !rows.isEmpty else {
      selectedContentPieceID = nil
      return
    }
    guard let selectedContentPieceID,
      let index = rows.firstIndex(where: { $0.id == selectedContentPieceID })
    else {
      self.selectedContentPieceID = rows.first?.id
      return
    }
    guard index > rows.startIndex else { return }
    self.selectedContentPieceID = rows[index - 1].id
  }

  public func selectNext() {
    guard !rows.isEmpty else {
      selectedContentPieceID = nil
      return
    }
    guard let selectedContentPieceID,
      let index = rows.firstIndex(where: { $0.id == selectedContentPieceID })
    else {
      self.selectedContentPieceID = rows.first?.id
      return
    }
    let nextIndex = index + 1
    guard rows.indices.contains(nextIndex) else { return }
    self.selectedContentPieceID = rows[nextIndex].id
  }

  public func archive(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.archive, to: row.id)
  }

  public func trash(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.trash, to: row.id)
  }

  public func clear(_ row: TodayReadingQueueRequest.Row) async {
    resetDoneTrackingIfNeeded(at: now)
    let shouldAdvance = selectedContentPieceID == row.id
    let nextSelection = shouldAdvance ? ReadingQueueSelection.neighbour(of: row.id, in: rows) : nil
    let date = now
    do {
      try await database.write { db in
        try TodayAttentionOperations.clear(row.id, at: date, in: db)
      }
      recordDone(row)
      presentedProcessContentPieceIDs.remove(row.id)
      if shouldAdvance { selectedContentPieceID = nextSelection }
      await reload()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func undoLastDisposition() async {
    guard let lastDisposition else { return }
    await undoDisposition(contentPieceID: lastDisposition.contentPieceID)
  }

  public func undoDisposition(contentPieceID: ContentPiece.ID) async {
    resetDoneTrackingIfNeeded(at: now)
    do {
      guard let entry = try await database.read({ db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: contentPieceID, in: db)
      }) else { return }
      try await dispositionService.undo(entry, in: database)
      doneByID.removeValue(forKey: contentPieceID)
      await reload()
      if let movedAwayFrom = selectedContentPieceID, movedAwayFrom != contentPieceID {
        presentedProcessContentPieceIDs.remove(movedAwayFrom)
      }
      selectedContentPieceID = contentPieceID
      if lastDisposition?.contentPieceID == contentPieceID {
        lastDisposition = nil
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Process series-trash applies only after the row was actually presented while Process was active.
  @discardableResult
  public func applySeriesTrashOnLeave(_ contentPieceID: ContentPiece.ID) async -> Bool {
    resetDoneTrackingIfNeeded(at: now)
    guard presentedProcessContentPieceIDs.remove(contentPieceID) != nil else { return false }
    return await applySeriesTrash(contentPieceID)
  }

  /// A quick-look row was explicitly presented even though it is not part of Process presentation state.
  @discardableResult
  public func applySeriesTrashOnQuickLookLeave(_ contentPieceID: ContentPiece.ID) async -> Bool {
    resetDoneTrackingIfNeeded(at: now)
    presentedProcessContentPieceIDs.remove(contentPieceID)
    return await applySeriesTrash(contentPieceID)
  }

  /// Applies the Process-tab leave boundary. A declared series may trash the selected piece; when it
  /// does, selection advances to the neighbour that was visible before the queue changed.
  public func leaveProcess() async {
    guard let selectedContentPieceID,
      rows.contains(where: { $0.id == selectedContentPieceID })
    else { return }

    let nextSelection = ReadingQueueSelection.neighbour(of: selectedContentPieceID, in: rows)
    guard await applySeriesTrashOnLeave(selectedContentPieceID) else { return }
    self.selectedContentPieceID = nextSelection
  }

  public func recordDismissed(_ row: TodayReadingQueueRequest.Row) async {
    await recordRemoved(row)
  }

  private func recordRemoved(_ row: TodayReadingQueueRequest.Row) async {
    resetDoneTrackingIfNeeded(at: now)
    let shouldAdvance = selectedContentPieceID == row.id
    let nextSelection = shouldAdvance
      ? ReadingQueueSelection.neighbour(of: row.id, in: rows)
      : nil
    recordDone(row)
    presentedProcessContentPieceIDs.remove(row.id)
    if shouldAdvance { selectedContentPieceID = nextSelection }
    await reload()
  }

  private func applySeriesTrash(_ contentPieceID: ContentPiece.ID) async -> Bool {
    guard let row = rows.first(where: { $0.id == contentPieceID }) else { return false }
    do {
      let didTrash = try await GmailSeriesDispositionOperations.applyTrashOnLeave(
        contentPieceID: contentPieceID, in: database, using: dispositionService)
      guard didTrash else { return false }
      recordDone(row)
      lastDisposition = LastDisposition(
        contentPieceID: contentPieceID, title: row.title, disposition: .trash)
      await reload()
      errorMessage = nil
      return true
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition, to id: ContentPiece.ID) async {
    resetDoneTrackingIfNeeded(at: now)
    guard let row = rows.first(where: { $0.id == id }), row.isGmailSource else { return }
    let shouldAdvance = selectedContentPieceID == id
    let nextSelection = shouldAdvance ? ReadingQueueSelection.neighbour(of: id, in: rows) : nil
    do {
      _ = try await dispositionService.apply(disposition, toContentPieceID: id, in: database)
      recordDone(row)
      presentedProcessContentPieceIDs.remove(id)
      lastDisposition = LastDisposition(
        contentPieceID: row.id, title: row.title, disposition: disposition)
      if shouldAdvance { selectedContentPieceID = nextSelection }
      await reload()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

public enum ReadingQueueSelection {
  /// The queue is already in reading order: advance, then fall back to the previous row.
  public static func neighbour(
    of id: ContentPiece.ID, in rows: [TodayReadingQueueRequest.Row]
  ) -> ContentPiece.ID? {
    guard let index = rows.firstIndex(where: { $0.id == id }) else { return nil }
    if rows.indices.contains(index + 1) { return rows[index + 1].id }
    if index > rows.startIndex { return rows[index - 1].id }
    return nil
  }
}
