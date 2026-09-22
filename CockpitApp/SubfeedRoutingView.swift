import CockpitCore
import SwiftUI

struct SubfeedRoutingView: View {
  @Bindable var model: FollowingModel

  var body: some View {
    List {
      Section {
        Text(
          "This editor covers configured sub-feeds known to Cockpit. New List-IDs stay on the "
            + "default route until explicitly configured; per-feed classification remains deferred. "
            + "Routing uses the sub-feed locator, not whether mail arrived through Gmail or RSS."
        )
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Section("Configured sub-feeds") {
        ForEach(model.routingRules) { rule in
          SubfeedRoutingRow(rule: rule) { updatedRule in
            Task { await model.saveRoutingRule(updatedRule) }
          }
        }
      }
    }
    .navigationTitle("Sub-feed routing")
    .task { await model.loadRoutingRules() }
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

private struct SubfeedRoutingRow: View {
  let rule: ContentRoleRoutingRule
  let update: (ContentRoleRoutingRule) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(rule.locator)
        .font(.headline)
        .textSelection(.enabled)

      Picker("Section", selection: Binding(
        get: { rule.role },
        set: { role in
          var updated = rule
          updated.role = role
          update(updated)
        })) {
        ForEach(ContentRole.allCases, id: \.self) { role in
          Text(role.displayName).tag(role)
        }
      }
      .disabled(!rule.isRouted)

      Toggle("Follow this sub-feed", isOn: Binding(
        get: { rule.isFollowed },
        set: { isFollowed in
          var updated = rule
          updated.isFollowed = isFollowed
          update(updated)
        }))

      Toggle("Mute this sub-feed", isOn: Binding(
        get: { rule.isMuted },
        set: { isMuted in
          var updated = rule
          updated.isMuted = isMuted
          update(updated)
        }))

      if !rule.isFollowed {
        Text("Not followed — this sub-feed stays out of Today.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if rule.isMuted {
        Text("Muted — this sub-feed stays out of Today.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .contain)
  }
}
