import CockpitCore
import SwiftUI

struct TailRowView: View {
  let row: CurrentEditionRequest.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(.headline)
      Text(row.publisher).font(.subheadline).foregroundStyle(.secondary)
      if let rationale = row.rationale, !rationale.isEmpty {
        Text(rationale).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
      if row.entryState == .seen {
        Text("Seen").font(.caption2).foregroundStyle(.tertiary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Open quick look.")
  }
}

struct TodayRowView: View {
  let row: TodayRequest.Row
  var emphasis = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(
        emphasis
          ? .title3.weight(row.isUnread ? .semibold : .regular)
          : .headline.weight(row.isUnread ? .semibold : .regular)
      )
      Text(row.sender).font(.subheadline).foregroundStyle(.secondary)
      if let treatmentSummary = row.treatmentSummary {
        Text(treatmentSummary).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
      }
      if let summary = row.summary, !summary.isEmpty {
        Text(summary)
          .font(.subheadline).foregroundStyle(.secondary)
          .lineLimit(row.treatment == .personal ? 3 : 2)
      }
      Text(row.arrivedAt, format: .dateTime.month().day().hour().minute())
        .font(.caption).foregroundStyle(.tertiary)
    }
    .padding(emphasis ? 10 : 0)
    .background {
      if emphasis {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Open quick look.")
  }
}

struct TodayRoleSectionListView: View {
  @Bindable var model: TodayModel
  @Bindable var queueModel: TodayReadingQueueModel
  let readerNamespace: Namespace.ID
  let didChangeQueue: @MainActor () async -> Void
  let openQuickLook: (ContentPiece.ID) -> Void

  var body: some View {
    ForEach(model.sections) { section in
      sectionView(section)
    }
  }

  @ViewBuilder
  private func sectionView(_ section: TodayModel.RoleSection) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Circle()
          .fill(section.role.color)
          .frame(width: 9, height: 9)
        Text(section.title).font(.title3.weight(.semibold))
        Text("\(section.rows.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      }
      .padding(.top, 18)

      ForEach(section.rows) { row in
        emailRow(row)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func emailRow(_ row: TodayRequest.Row) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button { openQuickLook(row.id) } label: {
        TodayRowView(row: row)
          .frame(maxWidth: .infinity, alignment: .leading)
          .matchedTransitionSource(id: row.id, in: readerNamespace)
      }
      .buttonStyle(.plain)

      Menu {
        emailActions(row)
      } label: {
        Image(systemName: "ellipsis.circle").foregroundStyle(.secondary).padding(.top, 8)
      }
      .accessibilityLabel("Message actions")
    }
    .padding(.vertical, 2)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button("Later", systemImage: "clock") { saveForLater(row) }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Trash", systemImage: "trash", role: .destructive) { trash(row) }
      Button("Archive", systemImage: "archivebox") { archive(row) }
    }
    .contextMenu { emailActions(row) }
  }

  @ViewBuilder
  private func emailActions(_ row: TodayRequest.Row) -> some View {
    MoveToSectionMenu(
      currentRole: row.role, isTransactional: row.treatment == .transactional
    ) { role in
      Task {
        await model.moveToSection(row.id, to: role)
        await didChangeQueue()
      }
    }
    Divider()
    Button("Archive", systemImage: "archivebox") { archive(row) }
    Button("Save for Later", systemImage: "clock") { saveForLater(row) }
    Button("Trash", systemImage: "trash", role: .destructive) { trash(row) }
  }

  private func archive(_ row: TodayRequest.Row) {
    Task {
      guard let queueRow = queueModel.rows.first(where: { $0.id == row.id }) else { return }
      await queueModel.archive(queueRow)
      await didChangeQueue()
    }
  }

  private func trash(_ row: TodayRequest.Row) {
    Task {
      guard let queueRow = queueModel.rows.first(where: { $0.id == row.id }) else { return }
      await queueModel.trash(queueRow)
      await didChangeQueue()
    }
  }

  private func saveForLater(_ row: TodayRequest.Row) {
    Task { await model.saveForLater(row) }
  }
}
