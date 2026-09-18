import CockpitCore
import SwiftUI

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
        .disabled(currentTreatment == treatment)
      }
    }
  }
}
