import CockpitCore
import SwiftUI

/// The Gmail source dispositions, shared by the Today row menu and the Reader so both offer the same
/// actions. Meant to be placed inside a `Menu`. State is not shown: `undo` reverses the message's
/// current disposition if any, and is a no-op otherwise.
struct GmailDispositionButtons: View {
  let archive: () -> Void
  let trash: () -> Void
  let undo: () -> Void

  var body: some View {
    Button("Archive", systemImage: "archivebox", action: archive)
    Button("Trash", systemImage: "trash", role: .destructive, action: trash)
    Button("Undo disposition", systemImage: "arrow.uturn.backward", action: undo)
  }
}

struct MoveToSectionMenu: View {
  let currentRole: ContentRole
  let isTransactional: Bool
  var isTransactionalCorrection = false
  var sender = "this sender"
  var isAvailable = true
  let move: (ContentRole) -> Void
  var removeTransactionalCorrection: () -> Void = {}
  @State private var confirmsTransactionalCorrection = false

  private let routingRoles = ContentRole.allCases.filter { $0 != .transactional }

  var body: some View {
    Menu("Move to section…", systemImage: "arrow.right") {
      if isTransactional {
        if isTransactionalCorrection {
          Button("Stop treating this sender as transactional", role: .destructive) {
            removeTransactionalCorrection()
          }
        } else {
          Button("Transactional is detected automatically") {}
            .disabled(true)
        }
      } else {
        ForEach(routingRoles, id: \.self) { role in
          Button {
            move(role)
          } label: {
            Label(role.displayName, systemImage: currentRole == role ? "checkmark" : "circle")
          }
          .disabled(currentRole == role)
        }
        Button("Transactional", systemImage: "creditcard") {
          confirmsTransactionalCorrection = true
        }
      }
    }
    .confirmationDialog(
      "Treat all mail from \(sender) as transactional?",
      isPresented: $confirmsTransactionalCorrection,
      titleVisibility: .visible
    ) {
      Button("Treat Sender as Transactional") { move(.transactional) }
      Button("Cancel", role: .cancel) {}
    }
    .disabled(!isAvailable)
  }
}
