import CockpitCore
import SwiftUI

struct TodayHighlightReaderSheet: View {
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
