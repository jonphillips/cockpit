import Foundation

extension ContentPieceReaderModel {
  /// Resolves the local Artifact provenance once for the Reader. Artifacts are device-local, so a
  /// message link is available only on the device that ingested the Gmail message.
  public func loadMailMessageLink() async {
    guard isGmailSource else {
      mailMessageURL = nil
      return
    }
    do {
      let provenance = try await database.read { db in
        try GmailArtifactProvenance.latest(forContentPiece: contentPieceID, in: db)
      }
      mailMessageURL = MailMessageLink.url(rfcMessageID: provenance?.rfcMessageID)
    } catch is CancellationError {
    } catch {
      mailMessageURL = nil
    }
  }
}
