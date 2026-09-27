import CockpitCore
import SwiftUI

struct TodayLandingView: View {
  @Bindable var model: TodayModel
  @Bindable var queueModel: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  @Bindable var dailyLinkModel: DailyLinkModel
  let readerNamespace: Namespace.ID
  let readableContentPieceIDs: Set<ContentPiece.ID>
  let didChangeQueue: @MainActor () async -> Void
  let openQuickLook: (ContentPiece.ID) -> Void
  let openOfferReview: (ContentRole) -> Void
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          orientationHeader
          TodayRoleSectionListView(
            model: model,
            queueModel: queueModel,
            readerNamespace: readerNamespace,
            didChangeQueue: didChangeQueue,
            openQuickLook: openQuickLook
          )
          offerReviewDoors
          tailCompositionStatus
          tailSection("Essentials", rows: tailRows(in: .essentials))
          tailSection("From the Tail", rows: tailBodyRows)
          tailSection("Essential Backlog", rows: tailRows(in: .essentialBacklog))
        }
        .padding(.horizontal)
        .padding(.bottom)
      }
      if horizontalSizeClass == .regular && !dailyLinkModel.links.isEmpty {
        DailyLinksColumn(model: dailyLinkModel)
      }
    }
  }
}

private extension TodayLandingView {
  @ViewBuilder
  var offerReviewDoors: some View {
    if !model.offerDoors.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Offers to review").font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
          ForEach(model.offerDoors) { door in
            Button { openOfferReview(door.role) } label: {
              VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                  Image(systemName: "tag")
                    .font(.headline)
                    .foregroundStyle(door.role.color)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(door.title).font(.headline)
                    Text("\(door.count) \(door.count == 1 ? "email" : "emails")")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  if door.keptCount > 0 {
                    Label("\(door.keptCount) kept", systemImage: "checkmark.circle.fill")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                if !door.heroURLs.isEmpty {
                  HStack(spacing: 6) {
                    ForEach(Array(door.heroURLs.enumerated()), id: \.offset) { _, url in
                      OfferRemoteHero(url: url, color: door.role.color)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                  }
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(14)
              .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Review \(door.count) \(door.title) offers")
          }
        }
      }
      .padding(.top, 22)
    }
  }

  var tailRows: [CurrentEditionRequest.Row] {
    tailModel.entries.filter {
      ($0.entryState == .admitted || $0.entryState == .seen)
        && readableContentPieceIDs.contains($0.contentPieceID)
    }
  }

  func tailRows(in section: JudgmentSection) -> [CurrentEditionRequest.Row] {
    tailRows.filter { $0.section == section }
  }

  var tailBodyRows: [CurrentEditionRequest.Row] {
    tailRows.filter { $0.section == .forYou || $0.section == .interestArea }
  }

  @ViewBuilder
  func tailSection(_ title: String, rows: [CurrentEditionRequest.Row]) -> some View {
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.title3.weight(.semibold)).padding(.top, 24)
        ForEach(rows) { row in
          HStack(alignment: .top, spacing: 8) {
            Button { openQuickLook(row.contentPieceID) } label: {
              TailRowView(row: row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .matchedTransitionSource(id: row.contentPieceID, in: readerNamespace)
            }
            .buttonStyle(.plain)
            tailRowMenu(row)
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
              dismissTail(row)
            }
          }
          .contextMenu { tailActions(row) }
        }
      }
    }
  }

  func tailRowMenu(_ row: CurrentEditionRequest.Row) -> some View {
    Menu {
      tailActions(row)
    } label: {
      Image(systemName: "ellipsis.circle").foregroundStyle(.secondary).padding(.top, 4)
    }
    .accessibilityLabel("Tail story actions")
  }

  @ViewBuilder
  func tailActions(_ row: CurrentEditionRequest.Row) -> some View {
    Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
      dismissTail(row)
    }
    Divider()
    Button("Save for Later", systemImage: "clock") {
      Task {
        await tailModel.saveForLater(row.id)
        if tailModel.errorMessage == nil { await didChangeQueue() }
      }
    }
    Button("Add to Library", systemImage: "books.vertical") {
      Task { await tailModel.addToLibrary(row.id) }
    }
  }

  func dismissTail(_ row: CurrentEditionRequest.Row) {
    Task {
      let queueRow = queueModel.rows.first(where: { $0.id == row.contentPieceID })
      await tailModel.dismiss(row.id)
      guard tailModel.errorMessage == nil else { return }
      if let queueRow { await queueModel.recordDismissed(queueRow) }
      await didChangeQueue()
    }
  }

  @ViewBuilder
  var tailCompositionStatus: some View {
    if tailModel.isComposing {
      HStack(spacing: 8) {
        ProgressView()
        Text(composingPhase?.title ?? "Composing today’s Edition…")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 18)
    }
  }

  var composingPhase: EditionCompositionPhase? {
    guard case let .composing(phase) = tailModel.compositionState else { return nil }
    return phase
  }

  var orientationHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("This morning").font(.largeTitle.weight(.semibold))
      Text(model.orientationSummary).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }
}
