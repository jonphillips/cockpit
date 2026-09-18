import CockpitCore
import SwiftUI

struct TodayView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @State private var isConfirmingTailRecompose = false

  var body: some View {
    NavigationStack {
      TodayLandingView(
        model: model, tailModel: tailModel, isConfirmingRecompose: $isConfirmingTailRecompose)
        .overlay {
          if model.tiers.isEmpty && tailRows.isEmpty && !tailModel.isComposing {
            ContentUnavailableView(
              "Nothing to Review", systemImage: "sun.max",
              description: Text("Gmail messages and screened tail stories will appear here."))
          }
        }
        .navigationTitle("Today")
        .sheet(item: selectedReaderSheetItem) { item in
          SpikeReaderSheet(contentPieceID: item.id)
            .presentationDetents([.medium, .large])
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

  private var selectedReaderSheetItem: Binding<TodayReaderSheetItem?> {
    Binding(
      get: { model.selectedContentPieceID.map(TodayReaderSheetItem.init) },
      set: { model.selectedContentPieceID = $0?.id }
    )
  }
}

private struct TodayReaderSheetItem: Identifiable {
  let id: ContentPiece.ID
}
