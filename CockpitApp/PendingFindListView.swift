import CockpitCore
import SwiftUI

struct PendingFindListView: View {
  @State private var model = PendingFindListModel()

  var body: some View {
    List(model.rows) { row in
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
        if RecipeCandidateKind.matches(row.kind), (row.state == .pending || row.state == .confirmed) {
          Button("Send to Yes Chef", systemImage: "arrow.up.forward.app") {
            Task { await model.sendToYesChef(row.id) }
          }
          .font(.subheadline)
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
    .task { try? await model.$content.load() }
  }

  private func stateLabel(_ state: PendingFindState) -> String {
    switch state {
    case .referred: "Sent to Yes Chef"
    case .pending, .confirmed, .handedOff, .declined, .dismissed: state.rawValue.capitalized
    }
  }
}
