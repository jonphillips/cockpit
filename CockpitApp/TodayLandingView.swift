import CockpitCore
import SwiftUI

struct TodayLandingView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @Binding var isConfirmingRecompose: Bool
  let readerNamespace: Namespace.ID
  let openReader: (ContentPiece.ID) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        orientationHeader
        promotionBand
        TodayTierListView(model: model, readerNamespace: readerNamespace, openReader: openReader)
        tailSection("Essentials", rows: tailRows(in: .essentials))
        tailSection("From the Tail", rows: tailBodyRows)
        tailSection("Essential Backlog", rows: tailRows(in: .essentialBacklog))
        TailCompositionControl(
          tailModel: tailModel, isConfirmingRecompose: $isConfirmingRecompose)
      }
      .padding(.horizontal)
      .padding(.bottom)
    }
  }

  private var tailRows: [CurrentEditionRequest.Row] {
    tailModel.entries.filter { $0.entryState == .admitted || $0.entryState == .seen }
  }

  private func tailRows(in section: JudgmentSection) -> [CurrentEditionRequest.Row] {
    tailRows.filter { $0.section == section }
  }

  private var tailBodyRows: [CurrentEditionRequest.Row] {
    tailRows.filter { $0.section == .forYou || $0.section == .interestArea }
  }

  @ViewBuilder
  private func tailSection(_ title: String, rows: [CurrentEditionRequest.Row]) -> some View {
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.title3.weight(.semibold)).padding(.top, 24)
        ForEach(rows) { row in
          Button { openReader(row.contentPieceID) } label: {
            TailRowView(row: row)
              .frame(maxWidth: .infinity, alignment: .leading)
              .matchedTransitionSource(id: row.contentPieceID, in: readerNamespace)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var orientationHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("This morning").font(.largeTitle.weight(.semibold))
      Text(orientationSummary).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  private var orientationSummary: String {
    let counts = EmailTreatment.todayHierarchy.compactMap { treatment -> String? in
      let count = model.count(for: treatment)
      return count == 0 ? nil : "\(count) \(treatment.displayName.lowercased())"
    }
    return counts.isEmpty ? "Nothing curated yet." : counts.joined(separator: " · ")
  }

  @ViewBuilder
  private var promotionBand: some View {
    if !model.promotedRows.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Fresh this morning").font(.headline)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 10) {
            ForEach(model.promotedRows) { row in
              Button { openReader(row.id) } label: {
                VStack(alignment: .leading, spacing: 5) {
                  Text(row.treatment.displayName.uppercased())
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                  Text(row.title).font(.headline).multilineTextAlignment(.leading).lineLimit(3)
                  Text(row.publisher).font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 210, alignment: .leading)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .matchedTransitionSource(id: row.id, in: readerNamespace)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 2)
        }
      }
      .padding(.vertical, 12)
    }
  }
}
