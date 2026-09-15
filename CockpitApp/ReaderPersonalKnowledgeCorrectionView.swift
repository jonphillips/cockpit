import CockpitCore
import SwiftUI

/// A Reader-local host for the established S2 correction form. It loads and targets exactly the
/// current claim taught from this ContentPiece, never opening the broader stewardship list.
struct ReaderPersonalKnowledgeCorrectionView: View {
  let claim: PersonalKnowledgeRequest.Row
  @State private var model = PersonalKnowledgeModel()
  @State private var openedCorrection = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if openedCorrection {
        PersonalKnowledgeCorrectionView(model: model)
      } else {
        ProgressView()
      }
    }
    .task {
      try? await model.$knowledge.load()
      guard let currentClaim = model.currentClaims.first(where: { $0.id == claim.id }) else {
        dismiss()
        return
      }
      model.correctButtonTapped(currentClaim)
      openedCorrection = true
    }
    .onChange(of: model.isCorrecting) { wasCorrecting, isCorrecting in
      if openedCorrection && wasCorrecting && !isCorrecting { dismiss() }
    }
  }
}
