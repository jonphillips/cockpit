import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @State private var originalReaderModel = TodayOriginalReaderModel()
  @State private var inboxIngest = GmailInboxIngestModel()
  @Namespace private var readerTransition
  @State private var isConfirmingTailRecompose = false
  @State private var isShowingRecentTrashes = false

    var body: some View {
    @Bindable var originalReaderModel = originalReaderModel

    NavigationStack {
      TodayLandingView(
        model: model,
        tailModel: tailModel,
        isConfirmingRecompose: $isConfirmingTailRecompose,
        readerNamespace: readerTransition,
        openReader: beginReader(for:))
        .overlay {
          if model.sections.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
            ContentUnavailableView(
              "Nothing to Review", systemImage: "sun.max",
              description: Text("Loose Gmail messages and screened tail stories will appear here."))
          }
        }
        .navigationTitle("Today")
        // A sheet, sized to fill: on iPad `.presentationSizing(.page)` abandons the narrow
        // form-card width (the "small" complaint) for the large page footprint, and `.large`
        // gives full height on compact widths. Unlike a fullScreenCover, a sheet keeps
        // swipe-down-to-dismiss (the manual-Done frustration). The zoom transition is on the
        // presented ROOT so the tapped row expands in rather than sliding up.
        .sheet(
          item: $originalReaderModel.presentation,
          onDismiss: {
            if let dismissedID = originalReaderModel.presentationDismissed() {
              Task { await model.applySeriesTrashOnLeave(dismissedID) }
            }
          }
        ) { presentation in
          NavigationStack {
            TodayOriginalReaderPane(
              model: originalReaderModel, presentation: presentation, todayModel: model)
              .navigationTitle("Reader")
              .navigationBarTitleDisplayMode(.inline)
          }
          .presentationSizing(.page)
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
          .navigationTransition(.zoom(sourceID: presentation.id, in: readerTransition))
        }
        .sheet(isPresented: $isShowingRecentTrashes) {
          RecentTrashSheet(model: model)
        }
    }
    .task {
      try? await model.$content.load()
    }
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
      ToolbarItem(placement: .topBarTrailing) {
        if tailModel.isComposing {
          ProgressView()
            .accessibilityLabel("Tail composition in progress")
        } else if tailModel.edition == nil {
          Button(tailModel.compositionState.controlTitle(hasEdition: false), systemImage: "sparkles") {
            Task { await tailModel.composeIfNeeded() }
          }
        } else {
          Button("Recompose Tail", systemImage: "arrow.clockwise") {
            isConfirmingTailRecompose = true
          }
        }
      }
      RecentTrashToolbar(model: model, isShowing: $isShowingRecentTrashes)
    }
    .confirmationDialog(
      "Recompose the tail?", isPresented: $isConfirmingTailRecompose, titleVisibility: .visible
    ) {
      Button("Recompose Tail", role: .destructive) { Task { await tailModel.recompose() } }
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
    tailModel.entries.filter { $0.entryState == .admitted || $0.entryState == .seen }
  }

  /// Pulls new Gmail mail (delta sync) and reconciles anything archived/trashed in Gmail out of Today,
  /// then reloads the projection — so the surface reflects the provider without a trip to Settings.
  private func refreshToday() async {
    await inboxIngest.ingestCurrentInbox()
    if case let .failed(message) = inboxIngest.status {
      model.errorMessage = message
    }
    try? await model.$content.load()
  }

  private func beginReader(for contentPieceID: ContentPiece.ID) {
    if let tailRow = tailRows.first(where: { $0.contentPieceID == contentPieceID }) {
      Task { await tailModel.markSeen(tailRow.id) }
    }
    originalReaderModel.begin(contentPieceID: contentPieceID)
  }
}
