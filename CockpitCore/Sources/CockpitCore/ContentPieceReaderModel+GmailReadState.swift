import Foundation

extension ContentPieceReaderModel {
  public var isUnread: Bool { row?.isUnread == true }

  /// Called after the Reader loads its source row. A provider failure is intentionally quiet and
  /// leaves the mirror unread so a later open retries.
  public func markReadOnOpenIfNeeded() async {
    guard isGmailSource, isUnread else { return }
    await GmailReadStateService(client: readStateClient)
      .markReadOnOpen(contentPieceID: contentPieceID, in: database)
    try? await $content.load()
  }

  public func markUnread() async {
    guard isGmailSource, !isUnread else { return }
    await GmailReadStateService(client: readStateClient)
      .markUnread(contentPieceID: contentPieceID, in: database)
    try? await $content.load()
  }
}
