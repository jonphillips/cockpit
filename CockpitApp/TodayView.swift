import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @State private var originalReaderModel = TodayOriginalReaderModel()
  @Namespace private var readerTransition
  @State private var isConfirmingTailRecompose = false

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
          if model.tiers.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
            ContentUnavailableView(
              "Nothing to Review", systemImage: "sun.max",
              description: Text("Gmail messages and screened tail stories will appear here."))
          }
        }
        .navigationTitle("Today")
        .sheet(item: $originalReaderModel.presentation, onDismiss: originalReaderModel.dismiss) {
          presentation in
          NavigationStack {
            TodayOriginalReaderPane(
              model: originalReaderModel, presentation: presentation)
              .navigationTitle("Reader")
              .navigationBarTitleDisplayMode(.inline)
              .navigationTransition(.zoom(sourceID: presentation.id, in: readerTransition))
          }
            // Tune on device: the maximum readable area minus a clear tap-out margin keeps
            // Today visibly present beneath the single large reader presentation.
            .presentationDetents([.fraction(TodayReaderPaneMetrics.heightFraction)])
            .presentationDragIndicator(.visible)
        }
    }
    .task {
      try? await model.$content.load()
      await tailModel.composeIfNeeded()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if tailModel.isComposing {
          ProgressView()
        } else if tailModel.edition == nil {
          Button("Compose Tail", systemImage: "sparkles") {
            Task { await tailModel.composeIfNeeded() }
          }
        } else {
          Button("Recompose Tail", systemImage: "arrow.clockwise") {
            isConfirmingTailRecompose = true
          }
        }
      }
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

  private func beginReader(for contentPieceID: ContentPiece.ID) {
    if let tailRow = tailRows.first(where: { $0.contentPieceID == contentPieceID }) {
      Task { await tailModel.markSeen(tailRow.id) }
    }
    originalReaderModel.begin(contentPieceID: contentPieceID)
  }
}
