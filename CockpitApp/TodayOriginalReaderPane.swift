import CockpitCore
import SwiftUI

struct TodayOriginalReaderPane: View {
  let model: TodayOriginalReaderModel
  let presentation: TodayOriginalReaderPresentation
  let todayModel: TodayModel
  @Environment(\.dismiss) private var dismiss
  @State var seriesTrashStateLoaded = false
  @State var isSeriesTrashDeclared = false

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ZStack {
        if model.hasBody {
          TodayOriginalWebView(webView: model.webView)
        } else if model.isLoading {
          ProgressView("Loading email")
        } else {
          ContentUnavailableView(
            "Original body unavailable",
            systemImage: "envelope.badge.xmark",
            description: Text("This email has no retained raw HTML on this device."))
        }

        if model.isLoading && model.hasBody {
          ProgressView().padding(12).background(.regularMaterial, in: Capsule())
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color(uiColor: .systemBackground))
    .toolbar {
      // One decision while reading: Archive. Trash and the sender/treatment tools live under the
      // menu so the common gesture is a single tap. Both dispositions advance to the next piece in
      // the same category and close the reader once the category is cleared.
      if seriesTrashStateLoaded && !isSeriesTrashDeclared {
        ToolbarItem(placement: .primaryAction) {
          Button("Archive", systemImage: "archivebox") {
            Task { await disposeAndAdvance { await todayModel.archive($0) } }
          }
          .disabled(currentRow == nil)
        }
      }
      ToolbarItem(placement: .primaryAction) { readerMenu }
      ToolbarItem(placement: .cancellationAction) {
        // Environment dismiss drives the sheet away; the framework nils the binding and the
        // sheet's onDismiss (presentationDismissed) does the load teardown. Don't also write
        // `presentation` here — that reintroduces the clobber race.
        Button("Done", systemImage: "xmark") { dismiss() }
      }
    }
    .task(id: presentation.id) {
      seriesTrashStateLoaded = false
      guard let row = currentRow else {
        seriesTrashStateLoaded = true
        return
      }
      isSeriesTrashDeclared = await todayModel.seriesTrashState(for: row)
      seriesTrashStateLoaded = true
    }
  }

  var currentRow: TodayRequest.Row? {
    todayModel.content.rows.first { $0.id == presentation.id }
  }

  /// Applies a disposition to the piece on screen, then advances to the next piece in the same
  /// treatment. When that treatment is exhausted the reader closes — "close out when done with the
  /// category". The category is captured before the write because the write reloads the projection.
  func disposeAndAdvance(_ dispose: (TodayRequest.Row) async -> Void) async {
    let currentID = presentation.id
    let treatment = model.treatment
    guard let row = currentRow else { dismiss(); return }
    await dispose(row)
    // Advancing swaps the reader identity without dismissing the sheet, so this is a real leave
    // point even though the presentation remains on screen.
    await todayModel.applySeriesTrashOnLeave(currentID)
    guard let treatment,
      let next = todayModel.content.rows.first(where: { $0.treatment == treatment && $0.id != currentID })
    else {
      dismiss()
      return
    }
    // Reassigning the presentation identity re-presents the sheet on the next piece; the guarded
    // onDismiss teardown treats this as the "quick swap" case and leaves the incoming load alone.
    model.begin(contentPieceID: next.id)
  }

  @ViewBuilder
  private var header: some View {
    if model.title.isEmpty && model.isLoading {
      ProgressView().frame(maxWidth: .infinity, alignment: .leading).padding()
    } else {
      VStack(alignment: .leading, spacing: 3) {
        Text(model.title.isEmpty ? "Email" : model.title)
          .font(.headline).lineLimit(2)
        if !model.publisher.isEmpty {
          Text(model.publisher).font(.subheadline).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal).padding(.vertical, 10)
    }
  }
}
