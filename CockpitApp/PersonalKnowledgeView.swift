import CockpitCore
import SwiftUI

struct PersonalKnowledgeView: View {
  @State private var model = PersonalKnowledgeModel()
  @State private var retirementCandidate: PersonalKnowledgeRequest.Row?

  var body: some View {
    @Bindable var model = model
    List {
      Section {
        ForEach(model.currentClaims) { claim in
          PersonalKnowledgeClaimRow(
            claim: claim,
            successor: model.claims.first { $0.id == claim.supersededByID },
            onCorrect: { model.correctButtonTapped(claim) },
            onRetire: { retirementCandidate = claim }
          )
        }
      } header: {
        Text("Current Understanding")
      } footer: {
        Text("Cockpit stores only things you teach it explicitly. It does not learn durable facts from behavior.")
      }

      PersonalKnowledgeDirectTeachingSection(model: model)

      if let hypothesis = model.hypothesis {
        PersonalKnowledgeHypothesisSection(hypothesis: hypothesis, model: model)
      }

      PersonalKnowledgeStewardshipSection(model: model)

      Section("Jon Brain Import") {
        Text("Paste copyable Fact, Taste, and Interest claims from ChatGPT or another source. Cockpit will show every material change before saving it.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        TextEditor(text: $model.importText)
          .frame(minHeight: 150)
          .accessibilityLabel("Jon Brain import text")
        HStack {
          Button("Review Import") {
            Task { await model.reviewImportButtonTapped() }
          }
          .disabled(
            model.isReviewingImport
              || model.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          if model.isReviewingImport {
            Spacer()
            ProgressView()
          }
        }
        if model.isReviewingImport {
          Text("Reviewing with \(model.importProviderDescription ?? "the model"). This can take several seconds…")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let review = model.proposalReview, !model.proposals.isEmpty {
        Section {
          ForEach(model.proposals) { proposal in
            PersonalKnowledgeProposalRow(
              proposal: proposal,
              isSelected: model.selectedProposalIDs.contains(proposal.id),
              toggleSelection: {
                if model.selectedProposalIDs.contains(proposal.id) {
                  model.selectedProposalIDs.remove(proposal.id)
                } else {
                  model.selectedProposalIDs.insert(proposal.id)
                }
              }
            )
          }
          Button(review == .importText ? "Import Selected" : "Apply Selected") {
            Task { await model.importSelectedButtonTapped() }
          }
          .disabled(model.selectedProposalIDs.isEmpty)
        } header: {
          Text(review.title)
        } footer: {
          Text("New or uncertain claims require an explicit check. Semantically faithful consolidations are selected for review, never written by the model itself.")
        }
      }

      PersonalKnowledgeHistorySection(model: model)
    }
    .navigationTitle("Personal Knowledge")
    .task {
      try? await model.$knowledge.load()
      await model.loadHypothesis()
    }
    .sheet(isPresented: $model.isCorrecting) {
      PersonalKnowledgeCorrectionView(model: model)
    }
    .confirmationDialog(
      "Retire this understanding?", item: $retirementCandidate,
      titleVisibility: .visible
    ) { claim in
      Button("Retire", role: .destructive) {
        Task { await model.retireButtonTapped(claim) }
      }
    } message: { claim in
      Text("\"\(claim.claim)\" will stop shaping Cockpit's understanding but remain in its history.")
    }
    .safeAreaInset(edge: .bottom) {
      if let error = model.errorMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .accessibilityHidden(true)
          Text(error)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .font(.callout)
        .padding()
        .background(.red.opacity(0.12), in: .rect(cornerRadius: 12))
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private struct PersonalKnowledgeHypothesisSection: View {
  let hypothesis: PersonalKnowledgeHypothesisRequest.Candidate
  let model: PersonalKnowledgeModel

  var body: some View {
    Section("A question for you") {
      Text(
        "You’ve deliberately saved, added to Library, or taught Cockpit about \(hypothesis.subject) \(hypothesis.explicitActionCount) times. Should Cockpit treat it as an Interest?"
      )
      Button("Yes, Treat It as an Interest", systemImage: "checkmark.circle") {
        Task { await model.confirmHypothesisButtonTapped() }
      }
      .disabled(model.isConfirmingHypothesis)
      Button("Not Now", role: .cancel) {
        model.dismissHypothesisButtonTapped()
      }
    } footer: {
      Text("This is only a question. Cockpit will not save anything unless you confirm it.")
    }
  }
}

private struct PersonalKnowledgeDirectTeachingSection: View {
  let model: PersonalKnowledgeModel

  var body: some View {
    @Bindable var model = model
    Section("Teach Cockpit") {
      Picker("Kind", selection: $model.directTeaching.kind) {
        ForEach(PersonalKnowledgeKind.allCases, id: \.self) { kind in
          Text(kind.displayName).tag(kind)
        }
      }
      TextField("What should Cockpit know?", text: $model.directTeaching.claim, axis: .vertical)
      TextField("Scope, if needed", text: $model.directTeaching.scope, axis: .vertical)
      Button("Save Teaching") {
        Task { await model.teachButtonTapped() }
      }
      .disabled(model.directTeaching.claim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
}

private struct PersonalKnowledgeStewardshipSection: View {
  let model: PersonalKnowledgeModel

  var body: some View {
    if model.canReviewConsolidation {
      Section {
        Button("Review Consolidation") {
          Task { await model.reviewConsolidationButtonTapped() }
        }
        .disabled(model.isReviewingConsolidation)
        if model.isReviewingConsolidation {
          HStack {
            ProgressView()
            Text("Reviewing accumulated teaching with \(model.importProviderDescription ?? "the model")…")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("Stewardship")
      } footer: {
        Text("Cockpit only proposes a rewrite when it preserves the meaning of every explicit claim. It never runs this as a daily chore.")
      }
    }
  }
}

private struct PersonalKnowledgeProposalRow: View {
  let proposal: PersonalKnowledgeProposal
  let isSelected: Bool
  let toggleSelection: () -> Void

  var body: some View {
    Button(action: toggleSelection) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(proposal.claim)
            .foregroundStyle(.primary)
          if !proposal.scope.isEmpty {
            Text(proposal.scope)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Text(proposal.requiresConfirmation ? "Needs confirmation" : "Semantic consolidation")
            .font(.caption)
            .foregroundStyle(proposal.requiresConfirmation ? .orange : .secondary)
          Text(proposal.rationale)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(proposal.claim), \(isSelected ? "selected" : "not selected")")
  }
}
