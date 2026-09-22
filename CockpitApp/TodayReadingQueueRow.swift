import CockpitCore
import SwiftUI

struct TodayReadingQueueRow: View {
  let row: TodayReadingQueueRequest.Row
  let archive: () -> Void
  let trash: () -> Void
  let undo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(row.title)
          .font(.headline)
          .lineLimit(2)
        Spacer(minLength: 0)
        if row.isFollowedStreamPiece {
          Image(systemName: "arrow.triangle.branch")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Followed Stream")
        }
      }
      Text(row.sourceLabel)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let summary = row.summary, !summary.isEmpty {
        Text(summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Open in Reader.")
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if row.isGmailSource {
        Button("Trash", systemImage: "trash", role: .destructive, action: trash)
        Button("Archive", systemImage: "archivebox", action: archive)
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if row.isGmailSource {
        Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
      }
    }
  }
}
