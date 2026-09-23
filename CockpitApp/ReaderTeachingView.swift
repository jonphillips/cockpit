import CockpitCore
import SwiftUI

/// The Reader's explicit confirmation sheet. The free-text reason is collected inline in the Reader;
/// this sheet appears only after the model has produced a Personal Knowledge proposal.
struct ReaderTeachingView: View {
  let model: ContentPieceReaderModel
  let stage: ReaderTeachingStage

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Group {
        switch stage {
        case let .proposal(proposal):
          proposalReview(proposal: proposal, model: model)
        }
      }
      .navigationTitle("Teach Cockpit")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { model.cancelTeaching() }
        }
      }
    }
  }

  @ViewBuilder
  private func proposalReview(
    proposal: PersonalKnowledgeProposal, model: ContentPieceReaderModel
  ) -> some View {
    Form {
      Section("Proposed Understanding") {
        Text(proposal.claim)
        if !proposal.scope.isEmpty {
          LabeledContent("Scope", value: proposal.scope)
        }
        Text(proposal.kind.displayName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text(proposal.rationale)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section {
        Button("Teach Cockpit") {
          Task { await model.saveTeachingButtonTapped() }
        }
      } footer: {
        Text("This is a proposed understanding. Cockpit will not save it unless you explicitly confirm it.")
      }
    }
  }
}
