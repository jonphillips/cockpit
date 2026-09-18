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
        .navigationDestination(item: $model.selectedContentPieceID) { contentPieceID in
          if let tailRow = tailRows.first(where: { $0.contentPieceID == contentPieceID }) {
            ReaderView(
              contentPieceID: contentPieceID,
              editionContext: EditionReaderContext(
                model: tailModel, entryID: tailRow.id, rationale: tailRow.rationale,
                matchedPersonalKnowledgeClaimID: tailRow.matchedPersonalKnowledgeClaimID,
                clearSelection: { model.selectedContentPieceID = nil }
              )
            )
          } else {
            // Curated email has no Edition context, so it receives no Edition-only affordances.
            ReaderView(contentPieceID: contentPieceID)
          }
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
}
