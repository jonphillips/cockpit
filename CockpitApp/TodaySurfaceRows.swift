import CockpitCore
import SwiftUI

// This file keeps the small Today row family together; the orientation section view intentionally
// owns the complete roll-up interaction for Offers and Grab-bag.
// swiftlint:disable file_length type_body_length

struct TailCompositionControl: View {
  let tailModel: EditionModel
  @Binding var isConfirmingRecompose: Bool
  let didChangeEdition: () -> Void

  var body: some View {
    Button {
      if tailModel.edition == nil {
        Task {
          await tailModel.composeIfNeeded()
          didChangeEdition()
        }
      } else {
        isConfirmingRecompose = true
      }
    } label: {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.accentColor)
          if tailModel.isComposing {
            ProgressView().tint(.white)
          } else {
            Image(systemName: tailModel.edition == nil ? "sparkles" : "arrow.clockwise")
              .font(.title3)
              .foregroundStyle(.white)
          }
        }
        .frame(width: 40, height: 40)

        VStack(alignment: .leading, spacing: 2) {
          Text(tailModel.isComposing ? composingPhase?.title ?? "Composing today’s Edition…" :
            tailModel.edition == nil ? "Compose today’s Edition" : "Recompose today’s Edition")
            .font(.headline)
          Text(tailModel.isComposing ? composingPhase?.detail ?? "Working on the editorial tail." :
            tailModel.edition == nil
              ? "A finite package from the streams you follow"
              : "\(tailModel.entries.count) pieces gathered for today")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(16)
      .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .disabled(tailModel.isComposing)
  }

  private var composingPhase: EditionCompositionPhase? {
    guard case let .composing(phase) = tailModel.compositionState else { return nil }
    return phase
  }
}

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
    .accessibilityHint("Open in Reader.")
  }
}

struct TodayRowView: View {
  let row: TodayRequest.Row
  var emphasis = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).font(emphasis ? .title3.weight(.semibold) : .headline)
      Text(row.publisher).font(.subheadline).foregroundStyle(.secondary)
      if let treatmentSummary = row.treatmentSummary {
        Text(treatmentSummary).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
      }
      if let summary = row.summary, !summary.isEmpty {
        Text(summary)
          .font(.subheadline).foregroundStyle(.secondary)
          .lineLimit(row.treatment == .personal ? 3 : 2)
      }
      if !row.grabBagItems.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(row.grabBagItems) { item in
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.subheadline.weight(.semibold))
              Text(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
          }
        }
        .padding(.top, 4)
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
    .accessibilityHint("Open in Reader.")
  }
}

struct TodayRoleSectionListView: View {
  @Bindable var model: TodayModel
  let readerNamespace: Namespace.ID
  let openReader: (ContentPiece.ID) -> Void

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
          .fill(sectionColor(section.role))
          .frame(width: 9, height: 9)
        Text(section.title).font(.title3.weight(.semibold))
        Text("\(section.rows.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      }
      .padding(.top, 18)

      switch section.role {
      case .offers:
        ForEach(model.offerGroups) { group in
          publisherRollup(group, role: section.role)
        }
      case .grabBag:
        ForEach(model.grabBagGroups) { group in
          grabBagRollup(group)
        }
      case .forYou, .transactional, .dailyNews, .opinion, .food, .wine:
        ForEach(section.rows) { row in
          emailRow(row)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func sectionColor(_ role: ContentRole) -> Color {
    switch role {
    case .forYou: .accentColor
    case .transactional: .indigo
    case .dailyNews: .blue
    case .opinion: .orange
    case .grabBag: .teal
    case .food: .green
    case .wine: .red
    case .offers: .brown
    }
  }

  private func publisherRollup(_ group: TodayModel.PublisherRollup, role: ContentRole) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button { openReader(group.representative.id) } label: {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text(group.count > 1 ? "\(group.count) \(group.label) messages" : group.label)
              .font(.headline)
            Text(group.representative.title)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
            Text(role.displayName)
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .matchedTransitionSource(id: group.representative.id, in: readerNamespace)
      }
      .buttonStyle(.plain)

      rollupMenu(group)
    }
  }

  private func grabBagRollup(_ group: TodayModel.PublisherRollup) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 8) {
        Button { openReader(group.representative.id) } label: {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(group.label).font(.headline)
              Text(group.itemCount > 0
                ? "\(group.itemCount) items in this issue"
                : group.representative.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
          }
          .padding(12)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
          .matchedTransitionSource(id: group.representative.id, in: readerNamespace)
        }
        .buttonStyle(.plain)

        rollupMenu(group)
      }

      ForEach(group.rows) { row in
        ForEach(row.grabBagItems) { item in
          Button { openReader(row.id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Circle().fill(.teal).frame(width: 5, height: 5)
              Text(item.title).font(.subheadline)
              Spacer()
              Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func rollupMenu(_ group: TodayModel.PublisherRollup) -> some View {
    Menu {
      MoveToSectionMenu(currentRole: group.representative.role, isTransactional: false) { role in
        Task { await model.moveToSection(group.representative.id, to: role) }
      }
      Divider()
      Button(
        group.count > 1 ? "Archive all \(group.count)" : "Archive",
        systemImage: "archivebox"
      ) { Task { await model.archiveAll(group.rows) } }
      Button(
        group.count > 1 ? "Trash all \(group.count)" : "Trash",
        systemImage: "trash", role: .destructive
      ) { Task { await model.trashAll(group.rows) } }
      Divider()
      Button("Undo disposition", systemImage: "arrow.uturn.backward") {
        Task { for row in group.rows { await model.undoDisposition(row) } }
      }
    } label: {
      Image(systemName: "ellipsis.circle").foregroundStyle(.secondary).padding(.top, 8)
    }
    .accessibilityLabel("\(group.label) actions")
  }

  private func emailRow(_ row: TodayRequest.Row) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button { openReader(row.id) } label: {
        TodayRowView(row: row)
          .frame(maxWidth: .infinity, alignment: .leading)
          .matchedTransitionSource(id: row.id, in: readerNamespace)
      }
      .buttonStyle(.plain)

      Menu {
        MoveToSectionMenu(
          currentRole: row.role, isTransactional: row.treatment == .transactional
        ) { role in
          Task { await model.moveToSection(row.id, to: role) }
        }
        Divider()
        GmailDispositionButtons(
          archive: { Task { await model.archive(row) } },
          trash: { Task { await model.trash(row) } },
          undo: { Task { await model.undoDisposition(row) } }
        )
        Divider()
        Button("Clear", systemImage: "checkmark.circle", role: .destructive) {
          Task { await model.clear(row) }
        }
      } label: {
        Image(systemName: "ellipsis.circle").foregroundStyle(.secondary).padding(.top, 8)
      }
    }
    .padding(.vertical, 2)
  }
}

// swiftlint:enable file_length type_body_length
