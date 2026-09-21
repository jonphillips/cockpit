import CockpitCore
import SwiftUI

struct RecentTrashSheet: View {
  @Bindable var model: TodayModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if model.recentTrashes.rows.isEmpty {
          ContentUnavailableView(
            "No Recent Trashes", systemImage: "trash",
            description: Text("Messages trashed by Cockpit will appear here."))
        } else {
          List(model.recentTrashes.rows) { row in
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 3) {
                Text(row.subject).font(.headline)
                Text(row.senderLabel).font(.subheadline).foregroundStyle(.secondary)
                Text(row.appliedAt, format: .dateTime.month().day().hour().minute())
                  .font(.caption).foregroundStyle(.tertiary)
              }
              Spacer()
              if row.isUndoable {
                Button("Undo") {
                  Task { await model.undoDisposition(forContentPieceID: row.contentPieceID) }
                }
                .buttonStyle(.bordered)
              } else {
                Text("Undone").font(.caption).foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 3)
          }
        }
      }
      .navigationTitle("Recently trashed")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
