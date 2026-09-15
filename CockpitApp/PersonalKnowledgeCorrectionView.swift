import CockpitCore
import SwiftUI

struct PersonalKnowledgeCorrectionView: View {
  let model: PersonalKnowledgeModel

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Form {
        Picker("Kind", selection: $model.correctionDraft.kind) {
          ForEach(PersonalKnowledgeKind.allCases, id: \.self) { kind in
            Text(kind.displayName).tag(kind)
          }
        }
        TextField("What should Cockpit understand instead?", text: $model.correctionDraft.claim, axis: .vertical)
        TextField("Scope, if needed", text: $model.correctionDraft.scope, axis: .vertical)
      }
      .navigationTitle("Correct Understanding")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { model.cancelCorrectionButtonTapped() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await model.saveCorrectionButtonTapped() }
          }
          .disabled(model.correctionDraft.claim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
