import CockpitCore
import SwiftUI

struct OfferReviewFinishBar: View {
  let model: OfferReviewModel
  let role: ContentRole
  let didFinish: () -> Void

  private var batch: GmailDispositionQueue.Batch? { model.batch }
  private var showsUndo: Bool { batch.map { $0.phase != .settled || !$0.applied.isEmpty } ?? false }

  var body: some View {
    if model.isClear {
      VStack(spacing: 8) {
        if showsUndo, let batch { batchControls(batch) }
        else {
          Text("\(role.displayName) is clear").font(.subheadline.weight(.semibold))
          Button("Done") { didFinish() }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      .background(.regularMaterial)
    } else {
      VStack(spacing: 8) {
        if showsUndo, let batch { batchControls(batch).font(.caption) }
        HStack(spacing: 12) {
          Text("\(model.keptCount) Finds kept. All \(model.rows.count) emails go to Gmail Trash.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button("Not now") { didFinish() }
          Button("Trash all \(model.rows.count)", role: .destructive) {
            model.trashAll()
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)
          .disabled(model.rows.isEmpty || batch?.phase == .running || batch?.phase == .undoing)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      .background(.regularMaterial)
    }
  }

  @ViewBuilder
  private func batchControls(_ batch: GmailDispositionQueue.Batch) -> some View {
    HStack {
      Text(message(for: batch))
      Spacer()
      if batch.phase == .running || batch.phase == .settled {
        Button("Undo") { Task { await model.dispositionQueue.undo(batch.id) } }
          .fontWeight(.semibold)
      }
      if batch.phase == .settled {
        Button("Dismiss") { model.dispositionQueue.dismiss(batch.id) }
      }
    }
  }

  private func message(for batch: GmailDispositionQueue.Batch) -> String {
    DispositionBatchMessage.text(for: batch)
  }
}
