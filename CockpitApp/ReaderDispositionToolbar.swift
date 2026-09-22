import CockpitCore
import SwiftUI

/// The Reader's Gmail source-disposition menu, offered only for email pieces. It carries the same
/// actions as the Today row menu (`GmailDispositionButtons`) so status can be changed while reading.
struct ReaderDispositionToolbar: ToolbarContent {
  let model: ContentPieceReaderModel
  var queueContext: ReaderQueueContext? = nil

  var body: some ToolbarContent {
    if model.isGmailSource {
      // Archive is the one-tap default; Trash and Undo stay under the menu so the common gesture does
      // not require choosing between dispositions first.
      ToolbarItem(placement: .topBarTrailing) {
        Button("Archive", systemImage: "archivebox") {
          Task { await archive() }
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          MoveToSectionMenu(
            currentRole: model.currentRoutingRule?.role ?? model.resolvedContentRole ?? .forYou,
            isTransactional: model.currentTreatment == .transactional,
            isAvailable: model.resolvedRoutingLocator != nil
          ) { role in
            Task { await model.moveToSection(to: role) }
          }
          Divider()
          Button("Trash", systemImage: "trash", role: .destructive) {
            Task { await trash() }
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

  private func archive() async {
    if let queueContext { await queueContext.archive() }
    else { await model.archiveSource() }
  }

  private func trash() async {
    if let queueContext { await queueContext.trash() }
    else { await model.trashSource() }
  }
}
