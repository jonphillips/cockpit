import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var queueModel: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  @Bindable var inboxIngest: GmailInboxIngestModel
  @Bindable var dailyLinkModel: DailyLinkModel
  @Bindable var shellModel: ShellModel
  @Binding var selectedFeedID: CockpitCore.Stream.ID?
  let didChangeQueue: @MainActor () async -> Void

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var quickLookWebViewStore = TodayOriginalWebViewStore()
  @Namespace private var readerTransition
  @State private var isConfirmingTailRecompose = false
  @State private var isShowingRecentTrashes = false
  @State private var quickLookRow: TodayReadingQueueRequest.Row?
  @State private var dismissedQuickLookID: ContentPiece.ID?
  @State private var offerReviewRole: ContentRole?

  var body: some View {
    NavigationStack {
      TodayLandingView(
        model: model,
        queueModel: queueModel,
        tailModel: tailModel,
        dailyLinkModel: dailyLinkModel,
        readerNamespace: readerTransition,
        openFeeds: {
          selectedFeedID = nil
          shellModel.select(.feeds)
        },
        readableContentPieceIDs: readingQueueContentPieceIDs,
        didChangeQueue: didChangeQueue,
        openQuickLook: openQuickLook,
        openOfferReview: { offerReviewRole = $0 }
      )
      .overlay {
        if model.sections.isEmpty && model.offerDoors.isEmpty && model.feedsDoor == nil
          && tailRows.isEmpty && !tailModel.isComposing
        {
          ContentUnavailableView(
            "Nothing to Review", systemImage: "sun.max",
            description: Text("Loose Gmail messages and screened tail stories will appear here."))
        }
      }
      .toolbar { todayToolbar }
    }
    .sheet(isPresented: $isShowingRecentTrashes) {
      RecentTrashSheet(model: model)
    }
    .offerReviewCover(role: $offerReviewRole, model: model) {
      Task { await didChangeQueue() }
    }
    .sheet(item: $quickLookRow, onDismiss: quickLookDismissed) { row in
      TodayQuickLookSheet(
        row: row,
        model: queueModel,
        tailModel: tailModel,
        originalWebViewStore: quickLookWebViewStore,
        processFromHere: {
          dismissedQuickLookID = nil
          shellModel.process(from: row.id)
        }
      )
      .presentationSizing(.page)
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
      .navigationTransition(.zoom(sourceID: row.id, in: readerTransition))
    }
    .task {
      try? await dailyLinkModel.$content.load()
      // S-d0b keeps Edition composition behind the standing entry card; opening Today does not
      // spend the editorial budget or silently start a multi-minute judgment pass.
      try? await model.$content.load()
      try? await model.$offers.load()
      await queueModel.reload()
    }
    .onChange(of: inboxIngest.status) { _, status in
      guard case .ingested = status else { return }
      Task { await didChangeQueue() }
    }
    .confirmationDialog(
      "Recompose the tail?", isPresented: $isConfirmingTailRecompose, titleVisibility: .visible
    ) {
      Button("Recompose Tail", role: .destructive) {
        Task {
          await tailModel.recompose()
          await didChangeQueue()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This discards today's screened tail and judges its candidates again from scratch.")
    }
    .safeAreaInset(edge: .bottom) { bottomBanner }
  }
}

private extension TodayView {
  @ViewBuilder
  var bottomBanner: some View {
    if !model.lastOfferBatch.isEmpty || model.offerUndoMessage != nil
      || model.errorMessage != nil || queueModel.errorMessage != nil || tailModel.errorMessage != nil
    {
      VStack(spacing: 8) {
        if !model.lastOfferBatch.isEmpty {
          HStack {
            Text(model.offerUndoMessage ?? "Trashed \(model.lastOfferBatch.count) offers")
            Spacer()
            Button("Undo") {
              Task {
                await model.undoLastOfferBatch()
                await didChangeQueue()
              }
            }
            .fontWeight(.semibold)
            Button("Dismiss") { model.dismissOfferUndo() }.accessibilityLabel("Dismiss Undo")
          }
        } else if let offerUndoMessage = model.offerUndoMessage {
          HStack {
            Text(offerUndoMessage)
            Spacer()
            Button("Dismiss") { model.dismissOfferUndo() }
          }
        }
        if let error = model.errorMessage ?? queueModel.errorMessage ?? tailModel.errorMessage {
          HStack {
            Text(error)
            Spacer()
            Button("Dismiss") {
              model.errorMessage = nil
              queueModel.errorMessage = nil
              tailModel.errorMessage = nil
            }
          }
        }
      }
      .padding()
      .background(.regularMaterial)
    }
  }

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

    if let disposition = queueModel.lastDisposition {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Undo", systemImage: "arrow.uturn.backward") {
          Task {
            await queueModel.undoLastDisposition()
            await didChangeQueue()
          }
        }
        .accessibilityLabel(
          "Undo \(disposition.disposition == .archive ? "archive" : "trash") of \(disposition.title)"
        )
      }
    }

    ToolbarItem(placement: .topBarTrailing) {
      Button {
        if queueModel.selectedContentPieceID == nil {
          queueModel.selectedContentPieceID = queueModel.rows.first?.id
        }
        shellModel.process(from: nil)
      } label: {
        Label("Process \(queueModel.rows.count)", systemImage: "list.bullet.rectangle")
      }
      .buttonStyle(.borderedProminent)
    }

    ToolbarItem(placement: .topBarTrailing) {
      Menu {
        Button("Recent Trashes", systemImage: "trash.slash") {
          isShowingRecentTrashes = true
        }
        Divider()
        Button(
          tailModel.edition == nil ? "Compose Tail" : "Recompose Tail",
          systemImage: tailModel.edition == nil ? "sparkles" : "arrow.clockwise"
        ) {
          if tailModel.edition == nil {
            Task {
              await tailModel.composeIfNeeded()
              await didChangeQueue()
            }
          } else {
            isConfirmingTailRecompose = true
          }
        }
        .disabled(tailModel.isComposing)
      } label: {
        Image(systemName: "ellipsis")
      }
      .accessibilityLabel("More Today actions")
    }

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
    Set(queueModel.rows.map(\.id))
  }

  private func refreshToday() async {
    await inboxIngest.ingestCurrentInbox()
    if case let .failed(message) = inboxIngest.status {
      model.errorMessage = message
    }
    await didChangeQueue()
  }

  private func openQuickLook(_ contentPieceID: ContentPiece.ID) {
    guard let row = queueModel.rows.first(where: { $0.id == contentPieceID }) else { return }
    dismissedQuickLookID = contentPieceID
    quickLookRow = row
  }

  private func quickLookDismissed() {
    guard let contentPieceID = dismissedQuickLookID else { return }
    dismissedQuickLookID = nil
    Task {
      await queueModel.applySeriesTrashOnQuickLookLeave(contentPieceID)
      await didChangeQueue()
    }
  }
}
