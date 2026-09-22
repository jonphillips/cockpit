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
          SenderTreatmentSubmenu(currentTreatment: model.currentTreatment) { treatment in
            Task { await model.setSenderOverride(treatment) }
          }
          ReaderContentRoleRoutingSubmenu(model: model)
          Divider()
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

private struct ReaderContentRoleRoutingSubmenu: View {
  let model: ContentPieceReaderModel

  private let routingRoles: [ContentRole] = [
    .forYou, .dailyNews, .opinion, .grabBag, .offers
  ]

  var body: some View {
    Menu("Move to section…", systemImage: "arrow.right") {
      ForEach(routingRoles, id: \.self) { role in
        Button {
          guard let locator = model.resolvedRoutingLocator else { return }
          Task {
            await model.saveRoutingRule(
              ContentRoleRoutingRule(locator: locator, role: role, isFollowed: true, isMuted: false)
            )
          }
        } label: {
          Label(
            role.displayName,
            systemImage: model.currentRoutingRule?.role == role
              && model.currentRoutingRule?.isRouted == true ? "checkmark" : "circle"
          )
        }
      }
    }
    .disabled(model.resolvedRoutingLocator == nil)
  }
}
