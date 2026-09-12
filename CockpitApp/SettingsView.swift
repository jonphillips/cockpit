import CockpitCore
import SwiftUI

struct SettingsView: View {
  var body: some View {
    List {
      Section("You") {
        NavigationLink {
          PersonalKnowledgeView()
        } label: {
          Label("Personal Knowledge", systemImage: "person.text.rectangle")
        }
      }
    }
    .navigationTitle("Settings")
  }
}

private struct PersonalKnowledgeView: View {
  @State private var model = PersonalKnowledgeModel()

  var body: some View {
    @Bindable var model = model
    List {
      Section {
        ForEach(model.claims) { claim in
          PersonalKnowledgeClaimRow(claim: claim)
        }
      } header: {
        Text("Current Understanding")
      } footer: {
        Text("Cockpit stores only things you teach it explicitly. It does not learn durable facts from behavior.")
      }

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

      Section("Jon Brain Import") {
        Text("Paste copyable Fact, Taste, and Interest claims from ChatGPT or another source. Cockpit will show every material change before saving it.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        TextEditor(text: $model.importText)
          .frame(minHeight: 150)
          .accessibilityLabel("Jon Brain import text")
        Button("Review Import") {
          Task { await model.reviewImportButtonTapped() }
        }
        .disabled(model.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if !model.proposals.isEmpty {
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
          Button("Import Selected") {
            Task { await model.importSelectedButtonTapped() }
          }
          .disabled(model.selectedProposalIDs.isEmpty)
        } header: {
          Text("Import Review")
        } footer: {
          Text("New or uncertain claims require an explicit check. Semantically faithful consolidations are selected for review, never written by the model itself.")
        }
      }
    }
    .navigationTitle("Personal Knowledge")
    .task {
      try? await model.$knowledge.load()
    }
    .safeAreaInset(edge: .bottom) {
      if let error = model.errorMessage {
        HStack {
          Text(error)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private struct PersonalKnowledgeClaimRow: View {
  let claim: PersonalKnowledgeRequest.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(claim.claim)
      if let scope = claim.scope {
        Text(scope)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text("\(claim.kind.displayName) · \(claim.provenance.displayName)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
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
