import CockpitCore
import SwiftUI

struct ProcessNextCardView: View {
  let selectedRow: TodayReadingQueueRequest.Row
  let next: ProcessNextCard?
  let actionTitle: String?
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let next {
        Text("Next in \(next.row.role.displayName) · \(next.roleIndex) of \(next.roleCount)")
          .font(Theme.sectionLabel)
          .tracking(Theme.sectionLabelTracking)
          .foregroundStyle(Theme.inkTertiary)
        Text(next.row.title)
          .font(Theme.nextHeadline)
          .foregroundStyle(Theme.ink)
        Text(next.row.sourceLabel)
          .font(Theme.byline)
          .foregroundStyle(Theme.inkSecondary)
        if let actionTitle {
          Button(actionTitle, systemImage: selectedRow.editionEntryID == nil ? "archivebox" : "xmark.circle", action: action)
            .buttonStyle(.borderedProminent)
        }
      } else {
        Text("End of the queue")
          .font(Theme.queueTitle)
          .foregroundStyle(Theme.ink)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Theme.paperSecondary)
  }
}
