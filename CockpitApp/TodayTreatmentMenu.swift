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

struct SenderTreatmentSubmenu: View {
  let currentTreatment: EmailTreatment?
  let setTreatment: (EmailTreatment) -> Void

  var body: some View {
    Menu("Treat sender as", systemImage: "tag") {
      ForEach(EmailTreatment.allCases, id: \.rawValue) { treatment in
        Button {
          setTreatment(treatment)
        } label: {
          Label(
            treatment.displayName,
            systemImage: currentTreatment == treatment ? "checkmark" : "circle")
        }
        .disabled(
          currentTreatment == treatment
            || (currentTreatment == .transactional && treatment != .transactional))
      }
      if currentTreatment == .transactional {
        Divider()
        Text("Transactional type is detected automatically")
      }
    }
  }
}
