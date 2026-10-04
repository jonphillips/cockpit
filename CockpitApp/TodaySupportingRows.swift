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

struct TodayFeedsDoorView: View {
  let door: TodayModel.FeedsDoor
  let openFeeds: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      SectionLabel(title: "Feeds", count: door.totalCount)
        .padding(.bottom, 2)
      TimelineView(.periodic(from: .now, by: 60)) { context in
        Button(action: openFeeds) {
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text("\(door.totalCount) new from \(door.sources.count) \(door.sources.count == 1 ? "feed" : "feeds")")
                .font(Theme.byline.weight(.semibold))
                .foregroundStyle(Theme.ink)
              Spacer(minLength: 4)
              Text("Go to Feeds")
                .font(Theme.byline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            Text(door.sources.map { "\($0.name) \($0.count)" }.joined(separator: " · "))
              .font(Theme.meta)
              .foregroundStyle(Theme.inkSecondary)
            Rectangle().fill(Theme.rule).frame(height: 1).padding(.vertical, 1)
            VStack(alignment: .leading, spacing: 2) {
              Text(door.newestTitle)
                .font(Theme.queueHeadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
              let age = RelativeDateTimeFormatter().localizedString(
                for: door.newestDate, relativeTo: context.date)
              Text("Newest · \(door.newestStreamName) · \(age)")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
            }
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 9)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Theme.paperSecondary, in: RoundedRectangle(cornerRadius: 8))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(door.totalCount) new stories from \(door.sources.count) feeds. Open Feeds.")
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
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        HStack(alignment: .top, spacing: 8) {
          Button { openQuickLook(row.contentPieceID) } label: {
            HeadlineRow(
              title: row.title, byline: row.publisher, time: "", detail: row.rationale,
              showsTopRule: index > 0)
              .frame(maxWidth: .infinity, alignment: .leading)
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
        let dot = Text(Image(systemName: "circle.fill"))
          .font(.system(size: 6, weight: .semibold))
          .foregroundStyle(Theme.accent)
          .baselineOffset(4)
        Text("\(dot) \(title)")
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
