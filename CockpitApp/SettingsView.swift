import CockpitCore
import LLMClientKit
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

      Section("Intelligence") {
        NavigationLink {
          AISettingsView()
        } label: {
          Label("AI Settings", systemImage: "brain")
        }
      }
    }
    .navigationTitle("Settings")
  }
}

private struct AISettingsView: View {
  @State private var model = AISettingsModel()

  var body: some View {
    @Bindable var model = model
    List {
      Section {
        Picker("Active provider", selection: $model.provider) {
          ForEach(model.providers) { provider in
            Text(provider.displayName).tag(provider)
          }
        }
        .onChange(of: model.provider) { model.persistPreferredProvider() }
        SecureField("API key", text: $model.draftKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .accessibilityLabel("\(model.provider.displayName) API key")
        Button("Save Key") { model.saveButtonTapped() }
          .disabled(model.draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if model.maskedKeyForSelected == nil {
          Text("No key saved for \(model.provider.displayName) yet — Cockpit will use whichever other provider is configured, or the on-device model.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Frontier Model")
      } footer: {
        Text("Cockpit uses the on-device model for everyday work. When a frontier model is needed — like reviewing a Jon Brain import — it uses the active provider above. Enter a key for each provider you want available. Keys are stored in your Keychain, synced across your own devices via iCloud, and never in a synced database table.")
      }

      if !model.maskedKeys.isEmpty {
        Section("Configured Keys") {
          ForEach(model.providers) { provider in
            if let masked = model.maskedKeys[provider] {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(provider.displayName)
                  Text(masked)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Remove", role: .destructive) {
                  model.clearButtonTapped(provider)
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle("AI Settings")
    .onAppear { model.refresh() }
    .safeAreaInset(edge: .bottom) {
      if let status = model.statusMessage {
        HStack {
          Text(status)
          Spacer()
          Button("Dismiss") { model.statusMessage = nil }
        }
        .font(.callout)
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private struct PersonalKnowledgeView: View {
  @State private var model = PersonalKnowledgeModel()

  var body: some View {
    @Bindable var model = model
    List {
      Section {
        ForEach(model.currentClaims) { claim in
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
