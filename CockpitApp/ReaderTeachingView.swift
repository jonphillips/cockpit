import CockpitCore
import SwiftUI

/// The Reader's explicit-teaching sheet. It keeps the free-text reason and the model proposal in
/// one short flow, while `ContentPieceReaderModel` owns the durable state transition for testing.
struct ReaderTeachingView: View {
  let model: ContentPieceReaderModel
  let stage: ReaderTeachingStage

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Group {
        switch stage {
        case .reason:
          reasonForm(model: model)
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
  private func reasonForm(model: ContentPieceReaderModel) -> some View {
    @Bindable var model = model
    Form {
      Section {
        Text("Tell Cockpit what this reveals about what matters to you. It will propose a narrow Taste or Interest for you to confirm.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        TextEditor(text: $model.teachingReason)
          .frame(minHeight: 140)
          .accessibilityLabel("Why this matters")
      } header: {
        Text("Why this matters")
      }

      Section {
        Button("Review Teaching") {
          Task { await model.reviewTeachingButtonTapped() }
        }
        .disabled(
          model.isReviewingTeaching
            || model.teachingReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        if model.isReviewingTeaching {
          HStack {
            ProgressView()
            Text("Drafting with \(model.teachingProviderDescription ?? "the model")…")
              .foregroundStyle(.secondary)
          }
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
