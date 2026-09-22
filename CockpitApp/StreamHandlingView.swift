import CockpitCore
import SwiftUI

/// The reachable-first surface for a followed Stream. It intentionally lives under Settings /
/// Following for now: the Gate 4 question is whether a Stream list serves real recurring material,
/// not whether it deserves a new top-level destination before the device review.
struct StreamHandlingView: View {
  let streamID: CockpitCore.Stream.ID
  @State private var model: StreamHandlingModel
  @State private var selectedContentPieceID: ContentPiece.ID?

  init(streamID: CockpitCore.Stream.ID) {
    self.streamID = streamID
    _model = State(initialValue: StreamHandlingModel(streamID: streamID))
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedContentPieceID) {
        StreamHandlingSummary(
          publisher: model.stream?.publisher,
          guidance: model.stream?.handlingGuidance,
          count: model.rows.count
        )

        Section("Issues") {
          ForEach(model.rows) { row in
            StreamHandlingRow(row: row)
              .tag(row.id)
          }
        }
      }
      .overlay {
        if model.stream != nil && model.rows.isEmpty {
          ContentUnavailableView(
            "No Issues Yet", systemImage: "tray",
            description: Text("New issues from this Stream will appear here."))
        } else if model.stream == nil {
          ContentUnavailableView("Stream Not Found", systemImage: "questionmark.circle")
        }
      }
      .navigationTitle(model.stream?.name ?? "Stream")
    } detail: {
      if let selectedContentPieceID {
        ReaderView(contentPieceID: selectedContentPieceID, isReachableStreamPiece: true)
          .id(selectedContentPieceID)
      } else {
        ContentUnavailableView(
          "Select an Issue", systemImage: "doc.text",
          description: Text("Stream issues stay reachable here without consuming Today's package."))
      }
    }
    .task { try? await model.$content.load() }
  }
}

private struct StreamHandlingSummary: View {
  let publisher: String?
  let guidance: String?
  let count: Int

  var body: some View {
    if publisher != nil || guidance?.isEmpty == false {
      VStack(alignment: .leading, spacing: 4) {
        if let publisher {
          Text(publisher).font(.subheadline).foregroundStyle(.secondary)
        }
        if let guidance, !guidance.isEmpty {
          Text(guidance).font(.subheadline)
        }
        Text("\(count) issue\(count == 1 ? "" : "s")")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .listRowSeparator(.hidden)
    }
  }
}

private struct StreamHandlingRow: View {
  let row: StreamHandlingRequest.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(.headline)
      Text(row.publisher).font(.subheadline).foregroundStyle(.secondary)
      if let date = row.publishedAt {
        Text(date, format: .dateTime.year().month().day())
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 3)
  }
}
