import CockpitCore
import LLMClientKit
import SwiftUI

struct SettingsView: View {
  let model: ShellModel
  let followingModel: FollowingModel
  @State private var gmailAuthorizationProbe = GmailAuthorizationProbe()
  @State private var dispositionPolicyModel = GmailDispositionPolicyModel()

  var body: some View {
    @Bindable var model = model
    NavigationStack(path: $model.settingsPath) {
      List {
        Section("You") {
          NavigationLink(value: SettingsRoute.personalKnowledge(claimID: nil)) {
            Label("You", systemImage: "person.text.rectangle")
          }
        }

        Section("Following") {
          NavigationLink(value: SettingsRoute.following) {
            Label("Following", systemImage: "dot.radiowaves.left.and.right")
          }
          NavigationLink(value: SettingsRoute.interestAreas) {
            Label("Interest Areas", systemImage: "square.grid.2x2")
          }
        }

        Section("Intelligence") {
          NavigationLink(value: SettingsRoute.ai) {
            Label("AI Settings", systemImage: "brain")
          }
          NavigationLink(value: SettingsRoute.pendingFinds) {
            Label("Pending Finds", systemImage: "sparkle.magnifyingglass")
          }
        }

        Section {
          ForEach(dispositionPolicyModel.allKinds, id: \.rawValue) { kind in
            Toggle(
              kind.displayName,
              isOn: Binding(
                get: { dispositionPolicyModel.isEnabled(kind) },
                set: { on in Task { await dispositionPolicyModel.setEnabled(kind, on) } }
              )
            )
          }
        } header: {
          Text("Automatic dispositions")
        } footer: {
          Text("When on, Cockpit disposes matching messages through the same barrier and Undo log as a manual Archive or Trash. You turn each policy on yourself — Cockpit never establishes one for you, and turning one off leaves past dispositions in place.")
        }

        Section("Developer") {
          NavigationLink(value: SettingsRoute.gmailAuthorizationProbe) {
            Label("Gmail authorization probe", systemImage: "envelope.badge")
          }
        }
      }
      .navigationTitle("Settings")
      .task { try? await dispositionPolicyModel.$policies.load() }
      .navigationDestination(for: SettingsRoute.self) { route in
        switch route {
        case .following:
          FollowingView(model: followingModel)
        case .interestAreas:
          InterestAreasView()
        case .personalKnowledge:
          PersonalKnowledgeView()
        case .ai:
          AISettingsView()
        case .pendingFinds:
          PendingFindListView()
        case .gmailAuthorizationProbe:
          GmailAuthorizationProbeView(probe: gmailAuthorizationProbe)
        }
      }
    }
  }
}

private struct InterestAreasView: View {
  var body: some View {
    ContentUnavailableView(
      "No Interest Areas Yet", systemImage: "square.grid.2x2",
      description: Text("Interest Areas are created while you set up Streams."))
      .navigationTitle("Interest Areas")
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
