import CockpitCore
import SwiftUI

struct TodayQuickLookSheet: View {
  @Environment(\.dismiss) private var dismiss
  let row: TodayReadingQueueRequest.Row
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let originalWebViewStore: TodayOriginalWebViewStore
  let processFromHere: @MainActor () -> Void

  var body: some View {
    NavigationStack {
      ReaderView(
        contentPieceID: row.id,
        editionContext: makeEditionReaderContext(
          row: row,
          tailModel: tailModel,
          clearSelection: { dismiss() },
          didDismiss: { await model.recordDismissed(row) }
        ),
        queueContext: ReaderQueueContext(
          model: model,
          row: row,
          archive: {
            await model.archive(row)
            dismiss()
          },
          trash: {
            await model.trash(row)
            dismiss()
          },
          showsNextCard: false
        ),
        isReachableStreamPiece: row.isFollowedStreamPiece,
        originalWebViewStore: originalWebViewStore
      )
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done") { dismiss() }
        }

        if model.rows.contains(where: { $0.id == row.id }) {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Process from here", systemImage: "list.bullet.rectangle") {
              processFromHere()
              dismiss()
            }
          }
        }
      }
    }
  }
}

func makeEditionReaderContext(
  row: TodayReadingQueueRequest.Row,
  tailModel: EditionModel,
  clearSelection: @escaping @MainActor () -> Void,
  didDismiss: (@MainActor () async -> Void)? = nil
) -> EditionReaderContext? {
  guard let entryID = row.editionEntryID else { return nil }
  return EditionReaderContext(
    model: tailModel,
    entryID: entryID,
    rationale: row.editionRationale,
    matchedPersonalKnowledgeClaimID: row.matchedPersonalKnowledgeClaimID,
    clearSelection: clearSelection,
    didDismiss: didDismiss
  )
}
