import CockpitCore
import SwiftUI

/// The one ordered morning queue. Today is the overview; Process owns sustained reading.
struct ProcessView: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let isActive: Bool
  let didChangeQueue: @MainActor () async -> Void

  var body: some View {
    NavigationSplitView {
      ProcessQueueSidebar(model: model, didChangeQueue: didChangeQueue)
    } detail: {
      ProcessQueueDetail(
        model: model,
        tailModel: tailModel,
        isActive: isActive,
        didChangeQueue: didChangeQueue
      )
    }
    .navigationSplitViewStyle(.balanced)
    .task {
      await model.reload()
      if model.selectedContentPieceID == nil {
        model.selectedContentPieceID = model.rows.first?.id
      }
    }
    .onChange(of: model.selectedContentPieceID) { oldID, newID in
      guard let oldID, oldID != newID else { return }
      Task {
        await model.applySeriesTrashOnLeave(oldID)
        await didChangeQueue()
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let errorMessage = model.errorMessage {
        HStack {
          Text(errorMessage)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }
}

private struct ProcessQueueDetail: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let isActive: Bool
  let didChangeQueue: @MainActor () async -> Void
  @State private var originalWebViewStore = TodayOriginalWebViewStore()

  var body: some View {
    Group {
      if let selectedContentPieceID = model.selectedContentPieceID,
        let row = model.rows.first(where: { $0.id == selectedContentPieceID })
      {
        ReaderView(
          contentPieceID: row.id,
          editionContext: makeEditionReaderContext(
            row: row,
            tailModel: tailModel,
            clearSelection: { advancePast(row) },
            didDismiss: {
              await model.recordDismissed(row)
              await didChangeQueue()
            }
          ),
          queueContext: ReaderQueueContext(
            model: model,
            row: row,
            archive: {
              await model.archive(row)
              await didChangeQueue()
            },
            trash: {
              await model.trash(row)
              await didChangeQueue()
            },
            dismissTailAndContinue: {
              guard let entryID = row.editionEntryID else { return }
              await tailModel.dismiss(entryID)
              guard tailModel.errorMessage == nil else { return }
              await model.recordDismissed(row)
              await didChangeQueue()
            }
          ),
          isReachableStreamPiece: row.isFollowedStreamPiece,
          originalWebViewStore: originalWebViewStore
        )
        .id(row.id)
        .onAppear {
          if isActive { model.markPresented(row.id) }
        }
        .onChange(of: isActive) { _, active in
          if active { model.markPresented(row.id) }
        }
      } else {
        ContentUnavailableView(
          "Select a Piece", systemImage: "doc.text",
          description: Text("The queue runs in section order."))
      }
    }
  }

  @MainActor
  private func advancePast(_ row: TodayReadingQueueRequest.Row) {
    model.selectedContentPieceID = ReadingQueueSelection.neighbour(of: row.id, in: model.rows)
    Task { await didChangeQueue() }
  }
}
