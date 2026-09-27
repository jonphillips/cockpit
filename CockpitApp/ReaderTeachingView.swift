import CockpitCore
import SwiftUI

/// Reader teaching is an explicit sheet: collect the reason, review Cockpit's proposed durable
/// understanding, then save only after the existing confirmation step.
struct ReaderTeachingView: View {
  @Environment(\.dismiss) private var dismiss
  let model: ContentPieceReaderModel

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Group {
        if let stage = model.teachingStage {
          switch stage {
          case let .proposal(proposal):
            proposalReview(proposal: proposal, model: model)
          }
        } else {
          teachingForm(model: model)
        }
      }
      .navigationTitle("Teach Cockpit")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            model.cancelTeaching()
            dismiss()
          }
        }
      }
    }
    .interactiveDismissDisabled(!model.teachingReason.isEmpty)
  }

  private func teachingForm(model: ContentPieceReaderModel) -> some View {
    @Bindable var model = model
    return Form {
      Section("Why this matters") {
        TextField(
          "Tell Cockpit why this matters",
          text: $model.teachingReason,
          axis: .vertical
        )
        .lineLimit(2 ... 6)
        .disabled(model.isReviewingTeaching)

        if model.isReviewingTeaching {
          HStack {
            ProgressView()
            Text("Reviewing teaching…")
              .foregroundStyle(.secondary)
          }
        }
      }

      Section {
        Button("Review Teaching") {
          Task { await model.submitTeachingReason() }
        }
        .disabled(
          model.isReviewingTeaching
            || model.teachingReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
      } footer: {
        Text("Cockpit will propose a durable understanding for you to confirm before saving it.")
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
          Task {
            await model.saveTeachingButtonTapped()
            if model.teachingStage == nil { dismiss() }
          }
        }
      } footer: {
        Text("This is a proposed understanding. Cockpit will not save it unless you explicitly confirm it.")
      }
    }
  }
}
