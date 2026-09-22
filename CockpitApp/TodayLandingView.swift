import CockpitCore
import SwiftUI

struct TodayLandingView: View {
  @Bindable var model: TodayModel
  @Bindable var tailModel: EditionModel
  @Binding var isConfirmingRecompose: Bool
  let readerNamespace: Namespace.ID
  let readableContentPieceIDs: Set<ContentPiece.ID>
  let didChangeEdition: () -> Void
  let openReader: (ContentPiece.ID) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        orientationHeader
        highlights
        TodayRoleSectionListView(
          model: model, readerNamespace: readerNamespace, openReader: openReader)
        TailCompositionControl(
          tailModel: tailModel,
          isConfirmingRecompose: $isConfirmingRecompose,
          didChangeEdition: didChangeEdition)
        tailSection("Essentials", rows: tailRows(in: .essentials))
        tailSection("From the Tail", rows: tailBodyRows)
        tailSection("Essential Backlog", rows: tailRows(in: .essentialBacklog))
      }
      .padding(.horizontal)
      .padding(.bottom)
    }
  }

  private var tailRows: [CurrentEditionRequest.Row] {
    tailModel.entries.filter {
      ($0.entryState == .admitted || $0.entryState == .seen)
        && readableContentPieceIDs.contains($0.contentPieceID)
    }
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
          HStack(alignment: .top, spacing: 8) {
            Button { openReader(row.contentPieceID) } label: {
              TailRowView(row: row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .matchedTransitionSource(id: row.contentPieceID, in: readerNamespace)
            }
            .buttonStyle(.plain)
            tailRowMenu(row)
          }
        }
      }
    }
  }

  /// Tail stories are RSS/screened content, not Gmail, so their resolution is `Dismiss` (the Edition
  /// action) rather than an Archive/Trash provider mutation. Save for Later and Add to Library are the
  /// two durable homes offered alongside it.
  private func tailRowMenu(_ row: CurrentEditionRequest.Row) -> some View {
    Menu {
      Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
        Task { await tailModel.dismiss(row.id) }
      }
      Divider()
      Button("Save for Later", systemImage: "clock") {
        Task { await tailModel.saveForLater(row.id) }
      }
      Button("Add to Library", systemImage: "books.vertical") {
        Task { await tailModel.addToLibrary(row.id) }
      }
    } label: {
      Image(systemName: "ellipsis.circle").foregroundStyle(.secondary).padding(.top, 4)
    }
    .accessibilityLabel("Tail story actions")
  }

  private var orientationHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("This morning").font(.largeTitle.weight(.semibold))
      Text(model.orientationSummary).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var highlights: some View {
    if !model.highlightRows.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("Highlights").font(.headline)
          Text("A quick way in").font(.caption).foregroundStyle(.tertiary)
        }
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: 10) {
            ForEach(model.highlightRows) { row in
              Button { openReader(row.id) } label: {
                VStack(alignment: .leading, spacing: 5) {
                  Text(row.role.displayName.uppercased())
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
