import CockpitCore
import SwiftUI

struct ContentPieceListView: View {
  let destination: ContentPieceListModel.Destination
  @State private var model = ContentPieceListModel()
  @State private var selectedContentPieceID: ContentPiece.ID?

  private var title: String { destination.rawValue }

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedContentPieceID) {
        ForEach(model.rows) { row in
          ContentPieceRowView(row: row)
            .tag(row.id)
        }
      }
      .overlay {
        if model.rows.isEmpty {
          ContentUnavailableView(
            "Nothing in \(title)", systemImage: destination == .later ? "clock" : "books.vertical",
            description: Text(destination == .later
              ? "Save a piece when you want to return to it."
              : "Add a piece to keep it in your Library."))
        }
      }
      .navigationTitle(title)
    } detail: {
      if let selectedContentPieceID {
        ReaderView(contentPieceID: selectedContentPieceID)
          .id(selectedContentPieceID)
      } else {
        ContentUnavailableView("Select a Piece", systemImage: "doc.text")
      }
    }
    .task { await loadDestination() }
  }

  private func loadDestination() async {
    model.destination = destination
    try? await model.$content.load()
  }
}
