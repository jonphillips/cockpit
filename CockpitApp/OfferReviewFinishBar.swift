import CockpitCore
import SwiftUI

struct OfferReviewFinishBar: View {
  let model: OfferReviewModel
  let role: ContentRole
  let didFinish: () -> Void

  var body: some View {
    if model.isClear {
      HStack {
        if !model.lastBatch.isEmpty {
          Text("Trashed \(model.lastBatch.count) emails")
          Spacer()
          Button("Undo") { Task { await model.undoLastBatch() } }.fontWeight(.semibold)
          Button("Dismiss") { model.dismissUndo() }
        } else if let statusMessage = model.statusMessage {
          Text(statusMessage)
          Spacer()
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      .background(.regularMaterial)
    } else {
      VStack(spacing: 8) {
        if let statusMessage = model.statusMessage {
          Text(statusMessage).font(.caption).foregroundStyle(.secondary)
        }
        if !model.lastBatch.isEmpty {
          HStack {
            Text("Trashed \(model.lastBatch.count) emails")
            Spacer()
            Button("Undo") { Task { await model.undoLastBatch() } }.fontWeight(.semibold)
            Button("Dismiss") { model.dismissUndo() }
          }
          .font(.caption)
        }
        HStack(spacing: 12) {
          Text("\(model.keptCount) Finds kept. All \(model.rows.count) emails go to Gmail Trash.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button("Not now") { didFinish() }
          Button("Trash all \(model.rows.count)", role: .destructive) {
            Task { await model.trashAll() }
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)
          .disabled(model.rows.isEmpty)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      .background(.regularMaterial)
    }
  }
}
