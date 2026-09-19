import CockpitCore
import SwiftUI

/// The Reader's Gmail source-disposition menu, offered only for email pieces. It carries the same
/// actions as the Today row menu (`GmailDispositionButtons`) so status can be changed while reading.
struct ReaderDispositionToolbar: ToolbarContent {
  let model: ContentPieceReaderModel

  var body: some ToolbarContent {
    if model.isGmailSource {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          GmailDispositionButtons(
            archive: { Task { await model.archiveSource() } },
            trash: { Task { await model.trashSource() } },
            undo: { Task { await model.undoDisposition() } }
          )
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }
}
