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
          Text(row.kind.capitalized).font(.caption).foregroundStyle(.secondary)
        }
        if !row.descriptor.isEmpty {
          Text(row.descriptor).font(.subheadline)
        }
        if !row.rationale.isEmpty {
          Text(row.rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      .accessibilityElement(children: .combine)
    }
    .overlay {
      if model.rows.isEmpty {
        ContentUnavailableView(
          "No Pending Finds", systemImage: "sparkle.magnifyingglass",
          description: Text("Useful things extracted from judgment will appear here."))
      }
    }
    .navigationTitle("Finds")
    .task { try? await model.$content.load() }
  }
}
