import CockpitCore
import SwiftUI

struct ContentPieceRowView: View {
  let row: ContentPieceListRequest.Row
  let model: ContentPieceListModel

  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        Text(row.title).font(.headline)
        Text(row.publisher).foregroundStyle(.secondary)
        HStack {
          if let date = row.publishedAt {
            Text(date, format: .dateTime.year().month().day())
          }
          if let streamName = row.streamName { Text(streamName) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      HStack {
        Button(row.laterAddedAt == nil ? "Save for Later" : "Remove from Later", systemImage: "clock") {
          Task { await model.laterButtonTapped(row) }
        }
        Button(row.libraryAddedAt == nil ? "Add to Library" : "Remove from Library", systemImage: "books.vertical") {
          Task { await model.libraryButtonTapped(row) }
        }
      }
      .buttonStyle(.borderless)
      .font(.subheadline)
    }
  }
}
