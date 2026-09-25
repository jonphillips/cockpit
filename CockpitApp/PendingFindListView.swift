import CockpitCore
import SwiftUI

struct PendingFindListView: View {
  let model: PendingFindListModel

  var body: some View {
    List(model.rows) { row in
      VStack(alignment: .leading, spacing: 4) {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(row.name).font(.headline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text(row.kind.capitalized).font(.caption).foregroundStyle(.secondary)
              Text(stateLabel(row.state)).font(.caption2).foregroundStyle(.secondary)
            }
          }
          if !row.descriptor.isEmpty {
            Text(row.descriptor).font(.subheadline)
          }
          if !row.rationale.isEmpty {
            Text(row.rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
        }
        .accessibilityElement(children: .combine)
        if let referralID = model.strandedReferrals[row.id] {
          Text("Yes Chef hasn't picked up this referral yet.")
            .font(.caption)
            .foregroundStyle(.orange)
          HStack {
            Button("Open Yes Chef Again", systemImage: "arrow.clockwise") {
              Task { await model.retryStrandedReferral(for: row.id) }
            }
            Button("Return to Confirmed", systemImage: "arrow.uturn.backward") {
              Task { await model.returnStrandedReferralToConfirmed(for: row.id) }
            }
            .tint(.secondary)
          }
          .font(.caption)
          .buttonStyle(.borderless)
          .accessibilityIdentifier("stranded-referral-\(referralID.uuidString.lowercased())")
        }
        if RecipeCandidateKind.matches(row.kind), (row.state == .pending || row.state == .confirmed) {
          Button("Send to Yes Chef", systemImage: "arrow.up.forward.app") {
            Task { await model.sendToYesChef(row.id) }
          }
          .font(.subheadline)
          .buttonStyle(.borderless)
        }
      }
      .swipeActions(edge: .trailing) {
        if row.state == .pending {
          Button("Dismiss", systemImage: "xmark", role: .destructive) {
            Task { await model.dismiss(row.id) }
          }
          Button("Save", systemImage: "bookmark.fill") {
            Task { await model.confirm(row.id) }
          }
          .tint(.accentColor)
        }
      }
    }
    .overlay {
      if model.rows.isEmpty {
        ContentUnavailableView(
          "No Pending Finds", systemImage: "sparkle.magnifyingglass",
          description: Text("Useful things extracted from judgment will appear here."))
      }
    }
    .navigationTitle("Finds")
    .alert("Couldn't Send Find", isPresented: Binding(
      get: { model.errorMessage != nil },
      set: { if !$0 { model.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Please try again.")
    }
    .task {
      try? await model.$content.load()
      await model.refreshHandoffState()
    }
  }

  private func stateLabel(_ state: PendingFindState) -> String {
    switch state {
    case .referred: "Sent to Yes Chef"
    case .handedOff: "Added to Yes Chef"
    case .declined: "Declined by Yes Chef"
    case .pending, .confirmed, .dismissed: state.rawValue.capitalized
    }
  }
}
