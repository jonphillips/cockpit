import CockpitCore
import SwiftUI

struct TodayOfferSectionView: View {
  let doors: [TodayModel.OfferDoor]
  let totalCount: Int
  let openOfferReview: (ContentRole) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      SectionLabel(title: "Offers", count: totalCount)
        .padding(.bottom, 2)
      ForEach(doors) { door in
        Button { openOfferReview(door.role) } label: {
          HStack(spacing: 5) {
            Text(door.title)
              .font(Theme.headline)
              .foregroundStyle(Theme.ink)
            Text("· \(door.count) \(door.count == 1 ? "offer" : "offers") ·")
              .font(Theme.byline)
              .foregroundStyle(Theme.inkSecondary)
            Text("Review")
              .font(Theme.byline.weight(.semibold))
              .foregroundStyle(Theme.accent)
            if door.keptCount > 0 {
              Text("· \(door.keptCount) kept")
                .font(Theme.byline)
                .foregroundStyle(Theme.inkTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(Theme.inkTertiary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 7)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review \(door.count) \(door.title) offers")
      }
    }
  }
}

struct TodayTailSectionView: View {
  let title: String
  let rows: [CurrentEditionRequest.Row]
  let isComposing: Bool
  let composingTitle: String?
  @Bindable var model: EditionModel
  @Bindable var queueModel: TodayReadingQueueModel
  let readerNamespace: Namespace.ID
  let didChangeQueue: @MainActor () async -> Void
  let openQuickLook: (ContentPiece.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: title, count: rows.count)
        .padding(.bottom, 2)
      if isComposing {
        Text(composingTitle ?? "Composing today’s Edition…")
          .font(Theme.byline)
          .foregroundStyle(Theme.inkSecondary)
        .padding(.vertical, 7)
      }
      ForEach(rows) { row in
        HStack(alignment: .top, spacing: 8) {
          Button { openQuickLook(row.contentPieceID) } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(row.title)
                .font(Theme.headline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
              Text(row.publisher)
                .font(Theme.byline)
                .foregroundStyle(Theme.inkSecondary)
              if let rationale = row.rationale, !rationale.isEmpty {
                Text(rationale)
                  .font(Theme.byline)
                  .foregroundStyle(Theme.inkTertiary)
                  .lineLimit(2)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .matchedTransitionSource(id: row.contentPieceID, in: readerNamespace)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Menu { tailActions(row) } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundStyle(Theme.inkTertiary)
              .padding(.top, 6)
          }
          .accessibilityLabel("Tail story actions")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
            dismiss(row)
          }
        }
        .contextMenu { tailActions(row) }
      }
    }
  }

  @ViewBuilder
  private func tailActions(_ row: CurrentEditionRequest.Row) -> some View {
    Button("Dismiss", systemImage: "xmark.circle", role: .destructive) { dismiss(row) }
    Divider()
    Button("Save for Later", systemImage: "clock") {
      Task {
        await model.saveForLater(row.id)
        if model.errorMessage == nil { await didChangeQueue() }
      }
    }
    Button("Add to Library", systemImage: "books.vertical") {
      Task { await model.addToLibrary(row.id) }
    }
  }

  private func dismiss(_ row: CurrentEditionRequest.Row) {
    Task {
      let queueRow = queueModel.rows.first(where: { $0.id == row.contentPieceID })
      await model.dismiss(row.id)
      guard model.errorMessage == nil else { return }
      if let queueRow { await queueModel.recordDismissed(queueRow) }
      await didChangeQueue()
    }
  }
}

struct HeadlineText: View {
  let title: String
  let isUnread: Bool

  var body: some View {
    Group {
      if isUnread {
        Text(Image(systemName: "circle.fill"))
          .font(.system(size: 6, weight: .semibold))
          .foregroundColor(Theme.accent)
          .baselineOffset(4) + Text(" \(title)")
      } else {
        Text(title)
      }
    }
    .accessibilityLabel(isUnread ? "Unread. \(title)" : title)
  }
}

enum TodayArrivalLabel {
  static func text(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
      return date.formatted(.dateTime.hour().minute())
    }
    return date.formatted(.dateTime.weekday(.abbreviated))
  }
}
