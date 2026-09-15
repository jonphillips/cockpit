import CockpitCore
import SwiftUI

struct ContentPieceRowView: View {
  let row: ContentPieceListRequest.Row

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
    }
  }
}
