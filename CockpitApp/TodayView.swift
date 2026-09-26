import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @Bindable var inboxIngest: GmailInboxIngestModel
  @Bindable var dailyLinkModel: DailyLinkModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var readingQueueModel = TodayReadingQueueModel()
  @State private var highlightWebViewStore = TodayOriginalWebViewStore()
  @Namespace private var readerTransition
  @State private var isConfirmingTailRecompose = false
  @State private var isShowingRecentTrashes = false
  @State private var isReading = false
  @State private var highlightRow: TodayRequest.Row?
  @State private var dismissedHighlightID: ContentPiece.ID?

  var body: some View {
    Group {
      if isReading {
        TodayReadingView(
          model: readingQueueModel,
          tailModel: tailModel,
          done: { isReading = false })
      } else {
        NavigationStack {
          TodayLandingView(
            model: model,
            tailModel: tailModel,
            dailyLinkModel: dailyLinkModel,
            isConfirmingRecompose: $isConfirmingTailRecompose,
            readerNamespace: readerTransition,
            readableContentPieceIDs: readingQueueContentPieceIDs,
            didChangeEdition: { Task { await readingQueueModel.reload() } },
            openReader: beginReader(for:),
            openHighlight: {
              dismissedHighlightID = $0.id
              highlightRow = $0
            })
            .overlay {
              if model.sections.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
                ContentUnavailableView(
                  "Nothing to Review", systemImage: "sun.max",
                  description: Text("Loose Gmail messages and screened tail stories will appear here."))
              }
            }
            .navigationTitle("Today")
            .toolbar { todayToolbar }
        }
      }
    }
    .sheet(isPresented: $isShowingRecentTrashes) {
      RecentTrashSheet(model: model)
    }
    .sheet(item: $highlightRow, onDismiss: highlightReaderDismissed) { row in
      if let queueRow = readingQueueModel.rows.first(where: { $0.id == row.id }) {
        TodayHighlightReaderSheet(
          row: row,
          queueRow: queueRow,
          model: model,
          tailModel: tailModel,
          originalWebViewStore: highlightWebViewStore
        )
        .presentationSizing(.page)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .navigationTransition(.zoom(sourceID: row.id, in: readerTransition))
      } else {
        ContentUnavailableView("Story Unavailable", systemImage: "doc.text")
          .presentationSizing(.page)
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
      }
    }
    .task {
      try? await dailyLinkModel.$content.load()
      // S-d0b keeps Edition composition behind the standing entry card; opening Today does not
      // spend the editorial budget or silently start a multi-minute judgment pass.
      try? await model.$content.load()
      await readingQueueModel.reload()
    }
    .onChange(of: inboxIngest.status) { _, status in
      guard case .ingested = status else { return }
      Task {
        try? await model.$content.load()
        await readingQueueModel.reload()
      }
    }
    .confirmationDialog(
      "Recompose the tail?", isPresented: $isConfirmingTailRecompose, titleVisibility: .visible
    ) {
      Button("Recompose Tail", role: .destructive) {
        Task {
          await tailModel.recompose()
          await readingQueueModel.reload()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This discards today's screened tail and judges its candidates again from scratch.")
    }
    .safeAreaInset(edge: .bottom) {
      if model.errorMessage != nil || tailModel.errorMessage != nil {
        HStack {
          Text(model.errorMessage ?? tailModel.errorMessage ?? "")
          Spacer()
          Button("Dismiss") {
            model.errorMessage = nil
            tailModel.errorMessage = nil
          }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private extension TodayView {
  @ToolbarContentBuilder
  var todayToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      if inboxIngest.status == .ingesting {
        ProgressView()
          .accessibilityLabel("Refreshing Today")
      } else {
        Button("Refresh", systemImage: "arrow.clockwise") {
          Task { await refreshToday() }
        }
      }
    }
    RecentTrashToolbar(model: model, isShowing: $isShowingRecentTrashes)
    if horizontalSizeClass == .compact && !dailyLinkModel.links.isEmpty {
      ToolbarItem(placement: .topBarTrailing) {
        DailyLinksMenu(model: dailyLinkModel)
      }
    }
  }

  private var tailRows: [CurrentEditionRequest.Row] {
    tailModel.entries.filter {
      ($0.entryState == .admitted || $0.entryState == .seen)
        && readingQueueContentPieceIDs.contains($0.contentPieceID)
    }
  }

  private var readingQueueContentPieceIDs: Set<ContentPiece.ID> {
    Set(readingQueueModel.rows.map(\.id))
  }

  /// Pulls new Gmail mail (delta sync) and reconciles anything archived/trashed in Gmail out of Today,
  /// then reloads the projection — so the surface reflects the provider without a trip to Settings.
  private func refreshToday() async {
    await inboxIngest.ingestCurrentInbox()
    if case let .failed(message) = inboxIngest.status {
      model.errorMessage = message
    }
    try? await model.$content.load()
    await readingQueueModel.reload()
  }

  private func beginReader(for contentPieceID: ContentPiece.ID) {
    readingQueueModel.selectedContentPieceID = contentPieceID
    isReading = true
  }

  private func highlightReaderDismissed() {
    guard let contentPieceID = dismissedHighlightID else { return }
    dismissedHighlightID = nil
    Task {
      await readingQueueModel.applySeriesTrashOnLeave(contentPieceID)
      try? await model.$content.load()
      await readingQueueModel.reload()
    }
  }

}

private struct TodayHighlightReaderSheet: View {
  @Environment(\.dismiss) private var dismiss
  let row: TodayRequest.Row
  let queueRow: TodayReadingQueueRequest.Row
  let model: TodayModel
  let tailModel: EditionModel
  let originalWebViewStore: TodayOriginalWebViewStore

  var body: some View {
    NavigationStack {
      ReaderView(
        contentPieceID: row.id,
        editionContext: makeEditionReaderContext(
          row: queueRow, tailModel: tailModel, clearSelection: { dismiss() }),
        queueContext: ReaderQueueContext(
          archive: {
            await model.archive(row)
            dismiss()
          },
          trash: {
            await model.trash(row)
            dismiss()
          }
        ),
        isReachableStreamPiece: queueRow.isFollowedStreamPiece,
        originalWebViewStore: originalWebViewStore
      )
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done", systemImage: "checkmark") { dismiss() }
        }
      }
    }
  }
}

func makeEditionReaderContext(
  row: TodayReadingQueueRequest.Row,
  tailModel: EditionModel,
  clearSelection: @escaping @MainActor () -> Void
) -> EditionReaderContext? {
  guard let entryID = row.editionEntryID else { return nil }
  return EditionReaderContext(
    model: tailModel,
    entryID: entryID,
    rationale: row.editionRationale,
    matchedPersonalKnowledgeClaimID: row.matchedPersonalKnowledgeClaimID,
    clearSelection: clearSelection
  )
}
