import CockpitCore
import SwiftUI

extension View {
  func dispositionAlert(queue: GmailDispositionQueue) -> some View {
    alert(
      queue.alert?.title ?? "",
      isPresented: Binding(
        get: { queue.alert != nil },
        set: { if !$0 { queue.clearAlert() } }
      )
    ) {
      Button("OK") { queue.clearAlert() }
    } message: {
      Text(queue.alert?.message ?? "")
    }
  }
}

enum DispositionBatchMessage {
  static func text(for batch: GmailDispositionQueue.Batch) -> String {
    switch batch.phase {
    case .running:
      let verb = batch.disposition == .trash ? "Trashing" : "Archiving"
      return "\(verb) \(batch.contentPieceIDs.count) emails…"
    case .undoing:
      return "Restoring…"
    case .settled:
      let verb = batch.disposition == .trash ? "Trashed" : "Archived"
      return "\(verb) \(batch.applied.count) emails"
    }
  }
}
