import CockpitCore
import SwiftUI

struct TailCompositionControl: View {
  let tailModel: EditionModel
  @Binding var isConfirmingRecompose: Bool

  var body: some View {
    Section {
      Button {
        if tailModel.edition == nil {
          Task { await tailModel.composeIfNeeded() }
        } else {
          isConfirmingRecompose = true
        }
      } label: {
        if tailModel.isComposing {
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text(composingPhase?.title ?? "Composing Tail…")
              Text(composingPhase?.detail ?? "Working on the uncurated tail.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } icon: {
            ProgressView()
          }
        } else {
          Label(
            tailModel.compositionState.controlTitle(hasEdition: tailModel.edition != nil),
            systemImage: tailModel.edition == nil ? "sparkles" : "arrow.clockwise")
        }
      }
      .disabled(tailModel.isComposing)
    }
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

struct TodayTierListView: View {
  @Bindable var model: TodayModel
  let readerNamespace: Namespace.ID
  let openReader: (ContentPiece.ID) -> Void
  @State private var expandedTreatment: EmailTreatment?
  @State private var expandedOfferGroupID: String?

  var body: some View {
    ForEach(model.tiers) { tier in
      tierView(tier)
    }
  }

  @ViewBuilder
  private func tierView(_ tier: TodayModel.Tier) -> some View {
    let isExpanded = expandedTreatment == tier.treatment
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(tier.title).font(.title3.weight(.semibold))
        Text("\(tier.rows.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        Spacer()
        Button(isExpanded ? "Show less" : "See all \(tier.rows.count)") {
          expandedTreatment = isExpanded ? nil : tier.treatment
        }
        .font(.caption.weight(.semibold))
      }
      .padding(.top, 18)

      if tier.treatment == .offer {
        offerTier(isExpanded: isExpanded)
      } else {
        let rows = isExpanded ? tier.rows : Array(tier.rows.prefix(3))
        ForEach(rows) { row in
          emailRow(row, emphasis: row.id == model.personalHighlight?.id && tier.treatment == .personal)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func offerTier(isExpanded: Bool) -> some View {
    ForEach(model.offerGroups) { group in
      VStack(alignment: .leading, spacing: 6) {
        Button {
          if group.count == 1 { openReader(group.representative.id) }
          else { expandedOfferGroupID = expandedOfferGroupID == group.id ? nil : group.id }
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(group.count > 1 ? "\(group.count) \(group.label) offers" : group.label)
                .font(.headline)
              if let summary = group.representative.treatmentSummary, !summary.isEmpty {
                Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
              } else {
                Text(group.representative.title)
                  .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
              }
            }
            Spacer()
            Image(systemName: group.count > 1 ? "chevron.down" : "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding(12)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
          .matchedTransitionSource(id: group.representative.id, in: readerNamespace)
        }
        .buttonStyle(.plain)

        if isExpanded || expandedOfferGroupID == group.id {
          ForEach(group.rows) { row in emailRow(row, emphasis: false) }
        }
      }
    }
  }

  private func emailRow(_ row: TodayRequest.Row, emphasis: Bool) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Button { openReader(row.id) } label: {
          TodayRowView(row: row, emphasis: emphasis)
            .frame(maxWidth: .infinity, alignment: .leading)
            .matchedTransitionSource(id: row.id, in: readerNamespace)
      }
      .buttonStyle(.plain)
      Menu {
        SenderTreatmentSubmenu(currentTreatment: row.treatment) { treatment in
          Task { await model.setSenderOverride(treatment, for: row) }
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
