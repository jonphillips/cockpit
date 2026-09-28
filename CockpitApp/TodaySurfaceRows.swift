import CockpitCore
import SwiftUI

struct TodayRoleSectionView: View {
  let section: TodayModel.RoleSection
  @Bindable var model: TodayModel
  @Bindable var queueModel: TodayReadingQueueModel
  let readerNamespace: Namespace.ID
  let didChangeQueue: @MainActor () async -> Void
  let openQuickLook: (ContentPiece.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: section.title, count: section.rows.count)
        .padding(.bottom, 2)
      ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
        if section.role == .forYou && index == 0 {
          leadRow(row)
        } else {
          let hasLead = section.role == .forYou
          emailRow(row, showsTopRule: hasLead ? index > 1 : index > 0)
        }
      }
    }
  }

  private func leadRow(_ row: TodayRequest.Row) -> some View {
    Button { openQuickLook(row.id) } label: {
      VStack(alignment: .leading, spacing: 4) {
        HeadlineText(title: row.title, isUnread: row.isUnread)
          .font(Theme.leadHeadline)
          .foregroundStyle(Theme.ink)
          .lineLimit(2)
        Text("\(row.sender) · \(TodayArrivalLabel.text(row.arrivedAt))")
          .font(Theme.byline)
          .foregroundStyle(Theme.inkSecondary)
        if let summary = row.summary, !summary.isEmpty {
          Text(summary)
            .font(Theme.lede)
            .foregroundStyle(Theme.ink)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
      .padding(.bottom, 9)
      .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
      .matchedTransitionSource(id: row.id, in: readerNamespace)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button("Later", systemImage: "clock") { saveForLater(row) }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Trash", systemImage: "trash", role: .destructive) { trash(row) }
      Button("Archive", systemImage: "archivebox") { archive(row) }
    }
    .contextMenu { emailActions(row) }
  }

  private func emailRow(_ row: TodayRequest.Row, showsTopRule: Bool) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button { openQuickLook(row.id) } label: {
        HeadlineRow(
          title: row.title, byline: row.sender,
          time: TodayArrivalLabel.text(row.arrivedAt), isUnread: row.isUnread,
          showsTopRule: showsTopRule)
          .frame(maxWidth: .infinity, alignment: .leading)
          .matchedTransitionSource(id: row.id, in: readerNamespace)
      }
      .buttonStyle(.plain)

      Menu { emailActions(row) } label: {
        Image(systemName: "ellipsis.circle")
          .foregroundStyle(Theme.inkTertiary)
          .padding(.top, 7)
      }
      .accessibilityLabel("Message actions")
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button("Later", systemImage: "clock") { saveForLater(row) }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Trash", systemImage: "trash", role: .destructive) { trash(row) }
      Button("Archive", systemImage: "archivebox") { archive(row) }
    }
    .contextMenu { emailActions(row) }
  }

}

private extension TodayRoleSectionView {
  @ViewBuilder
  func emailActions(_ row: TodayRequest.Row) -> some View {
    MoveToSectionMenu(
      currentRole: row.role,
      isTransactional: row.treatment == .transactional,
      isTransactionalCorrection: row.isTransactionalCorrection,
      sender: row.senderHeader
    ) { role in
      Task {
        await model.moveToSection(row.id, to: role)
        await didChangeQueue()
      }
    } removeTransactionalCorrection: {
      Task {
        await model.removeTransactionalCorrection(for: row.senderHeader)
        await didChangeQueue()
      }
    }
    Divider()
    Button("Archive", systemImage: "archivebox") { archive(row) }
    Button("Save for Later", systemImage: "clock") { saveForLater(row) }
    Button("Trash", systemImage: "trash", role: .destructive) { trash(row) }
    Divider()
    Button("Clear", systemImage: "checkmark.circle", role: .destructive) { clear(row) }
  }

  func archive(_ row: TodayRequest.Row) {
    Task {
      if let queueRow = queueModel.rows.first(where: { $0.id == row.id }) {
        await queueModel.archive(queueRow)
      } else {
        await model.archive(row)
      }
      await didChangeQueue()
    }
  }

  func trash(_ row: TodayRequest.Row) {
    Task {
      if let queueRow = queueModel.rows.first(where: { $0.id == row.id }) {
        await queueModel.trash(queueRow)
      } else {
        await model.trash(row)
      }
      await didChangeQueue()
    }
  }

  func clear(_ row: TodayRequest.Row) {
    Task {
      if let queueRow = queueModel.rows.first(where: { $0.id == row.id }) {
        await queueModel.clear(queueRow)
      } else {
        await model.clear(row)
      }
      await didChangeQueue()
    }
  }

  func saveForLater(_ row: TodayRequest.Row) {
    Task { await model.saveForLater(row) }
  }
}
