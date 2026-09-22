import CockpitCore
import SwiftUI

struct SubfeedRoutingView: View {
  @Bindable var model: FollowingModel

  var body: some View {
    List {
      Section {
        Text(
          "New List-IDs appear below after mail is ingested and stay on the default route until "
            + "explicitly configured. Per-feed classification remains deferred. "
            + "Routing uses the sub-feed locator, not whether mail arrived through Gmail or RSS."
        )
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if !model.discoveredLocators.isEmpty {
        Section("Discovered — not yet routed") {
          ForEach(model.discoveredLocators) { discovered in
            SubfeedRoutingRow(
              rule: ContentRoleRoutingRule(locator: discovered.locator, role: .forYou),
              displayLabel: discovered.displayLabel,
              pieceCount: discovered.pieceCount
            ) { updatedRule in
              Task { await model.saveRoutingRule(updatedRule) }
            }
          }
        }
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
  var displayLabel: String?
  var pieceCount: Int?
  let update: (ContentRoleRoutingRule) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let displayLabel {
        Text(displayLabel)
          .font(.headline)
        if let pieceCount {
          Text(pieceCount == 1 ? "1 piece seen" : String(pieceCount) + " pieces seen")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      Text(rule.locator)
        .font(displayLabel == nil ? .headline : .caption)
        .foregroundStyle(displayLabel == nil ? .primary : .secondary)
        .textSelection(.enabled)

      Picker("Section", selection: Binding(
        get: { rule.role },
        set: { role in
          var updated = rule
          updated.role = role
          update(updated)
        })) {
        ForEach(ContentRole.allCases.filter { $0 != .transactional }, id: \.self) { role in
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
