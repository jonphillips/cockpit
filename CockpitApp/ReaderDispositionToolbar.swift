import CockpitCore
import SwiftUI

/// The Reader's Gmail source-disposition menu, offered only for email pieces. It carries the same
/// actions as the Today row menu (`GmailDispositionButtons`) so status can be changed while reading.
struct ReaderDispositionToolbar: ToolbarContent {
  let model: ContentPieceReaderModel

  var body: some ToolbarContent {
    if model.isGmailSource {
      // Archive is the one-tap default; Trash and Undo stay under the menu so the common gesture does
      // not require choosing between dispositions first.
      ToolbarItem(placement: .topBarTrailing) {
        Button("Archive", systemImage: "archivebox") { Task { await model.archiveSource() } }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Trash", systemImage: "trash", role: .destructive) {
            Task { await model.trashSource() }
          }
          Button("Undo disposition", systemImage: "arrow.uturn.backward") {
            Task { await model.undoDisposition() }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }
}
