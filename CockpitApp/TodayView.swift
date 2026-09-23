import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @Bindable var inboxIngest: GmailInboxIngestModel
  @State private var readingQueueModel = TodayReadingQueueModel()
  @Namespace private var readerTransition
  @State private var isConfirmingTailRecompose = false
  @State private var isShowingRecentTrashes = false
  @State private var isReading = false

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
            isConfirmingRecompose: $isConfirmingTailRecompose,
            readerNamespace: readerTransition,
            readableContentPieceIDs: readingQueueContentPieceIDs,
            didChangeEdition: { Task { await readingQueueModel.reload() } },
            openReader: beginReader(for:))
            .overlay {
              if model.sections.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
                ContentUnavailableView(
                  "Nothing to Review", systemImage: "sun.max",
                  description: Text("Loose Gmail messages and screened tail stories will appear here."))
              }
            }
            .navigationTitle("Today")
            .toolbar {
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
            }
        }
      }
    }
    .sheet(isPresented: $isShowingRecentTrashes) {
      RecentTrashSheet(model: model)
    }
    .task {
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
}
