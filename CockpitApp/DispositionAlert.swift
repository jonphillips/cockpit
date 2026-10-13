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
      return "\(verb) \(emailCount(batch.contentPieceIDs.count))…"
    case .undoing:
      return "Restoring…"
    case .settled:
      let verb = batch.disposition == .trash ? "Trashed" : "Archived"
      return "\(verb) \(emailCount(batch.applied.count))"
    }
  }

  static func emailCount(_ count: Int) -> String {
    "\(count) email\(count == 1 ? "" : "s")"
  }
}
