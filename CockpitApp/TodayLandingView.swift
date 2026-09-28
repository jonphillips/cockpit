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
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        masthead
        sectionIndex
          .padding(.top, 8)

        let content = displaySections
        let columns = TodayColumnLayout.columns(
          for: content.map(\.layout), count: horizontalSizeClass == .regular ? 3 : 1)
        let sectionsByID = Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0) })
        TodayColumnsLayout(columnCount: columns.count) {
          ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, column in
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
              ForEach(column) { layoutSection in
                if let section = sectionsByID[layoutSection.id] {
                  sectionView(section)
                }
              }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, columnIndex == 0 ? 0 : 18)
            .padding(.trailing, columnIndex == columns.count - 1 ? 0 : 18)
            .overlay(alignment: .leading) {
              if columnIndex > 0 {
                Rectangle().fill(Theme.rule).frame(width: 1)
              }
            }
          }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
      }
      .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
    }
    .swipeActionsContainer()
    .background(Theme.paper)
    .foregroundStyle(Theme.ink)
  }
}

private extension TodayLandingView {
  var masthead: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      masthead(date: context.date)
    }
  }

  func masthead(date: Date) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: 14) {
      Text(date.formatted(.dateTime.weekday(.wide)))
        .font(Theme.masthead)
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text("\(date.formatted(.dateTime.month(.wide).day())) · \(queueModel.rows.count) to process")
        .font(Theme.byline)
        .foregroundStyle(Theme.inkSecondary)
        .lineLimit(1)

      Spacer(minLength: 8)

      if horizontalSizeClass == .regular && !dailyLinkModel.links.isEmpty {
        DailyLinksMasthead(model: dailyLinkModel)
      }
    }
    .padding(.top, 8)
    .padding(.bottom, 10)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Theme.ink).frame(height: 2)
    }
  }

  var sectionIndex: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 16) {
        ForEach(model.sections) { section in
          indexLabel(section.title, count: section.rows.count)
        }
        if !model.offerDoors.isEmpty {
          indexLabel("Offers", count: model.offers.rows.count)
        }
      }
      .padding(.vertical, 7)
    }
    .overlay(alignment: .bottom) {
      Rectangle().fill(Theme.rule).frame(height: 1)
    }
  }

  func indexLabel(_ title: String, count: Int) -> some View {
    HStack(spacing: 4) {
      Text(title).foregroundStyle(Theme.inkSecondary)
      Text(count, format: .number).fontWeight(.semibold).foregroundStyle(Theme.ink)
    }
    .font(Theme.meta)
    .fixedSize()
  }

  var displaySections: [TodayDisplaySection] {
    var result = model.sections.map { section in
      TodayDisplaySection(
        layout: .init(id: "role-\(section.role.rawValue)", sortOrder: section.role.sortOrder,
                      rowCount: section.rows.count),
        content: .role(section))
    }

    if !model.offerDoors.isEmpty {
      result.append(TodayDisplaySection(
        layout: .init(id: "offers", sortOrder: ContentRole.offers.sortOrder,
                      rowCount: model.offerDoors.count),
        content: .offers(model.offerDoors)))
    }

    let tailStart = ContentRole.allCases.count + 1
    let essentials = tailRows(in: .essentials)
    if !essentials.isEmpty {
      result.append(TodayDisplaySection(
        layout: .init(id: "tail-essentials", sortOrder: tailStart, rowCount: essentials.count),
        content: .tail(title: "Essentials", rows: essentials, showsComposition: false)))
    }
    if !tailBodyRows.isEmpty || tailModel.isComposing {
      result.append(TodayDisplaySection(
        layout: .init(id: "tail-body", sortOrder: tailStart + 1,
                      rowCount: max(1, tailBodyRows.count)),
        content: .tail(title: "From the Tail", rows: tailBodyRows, showsComposition: true)))
    }
    let backlog = tailRows(in: .essentialBacklog)
    if !backlog.isEmpty {
      result.append(TodayDisplaySection(
        layout: .init(id: "tail-backlog", sortOrder: tailStart + 2, rowCount: backlog.count),
        content: .tail(title: "Essential Backlog", rows: backlog, showsComposition: false)))
    }
    return result
  }

  @ViewBuilder
  func sectionView(_ section: TodayDisplaySection) -> some View {
    switch section.content {
    case let .role(roleSection):
      TodayRoleSectionView(
        section: roleSection, model: model, queueModel: queueModel,
        readerNamespace: readerNamespace, didChangeQueue: didChangeQueue,
        openQuickLook: openQuickLook)
    case let .offers(doors):
      TodayOfferSectionView(doors: doors, totalCount: model.offers.rows.count,
                            openOfferReview: openOfferReview)
    case let .tail(title, rows, showsComposition):
      TodayTailSectionView(
        title: title, rows: rows, isComposing: showsComposition && tailModel.isComposing,
        composingTitle: composingPhase?.title, model: tailModel, queueModel: queueModel,
        readerNamespace: readerNamespace,
        didChangeQueue: didChangeQueue, openQuickLook: openQuickLook)
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

  var composingPhase: EditionCompositionPhase? {
    guard case let .composing(phase) = tailModel.compositionState else { return nil }
    return phase
  }
}

private struct TodayDisplaySection: Identifiable {
  enum Content {
    case role(TodayModel.RoleSection)
    case offers([TodayModel.OfferDoor])
    case tail(title: String, rows: [CurrentEditionRequest.Row], showsComposition: Bool)
  }

  let layout: TodayColumnLayout.Section
  let content: Content
  var id: String { layout.id }
}

private struct TodayColumnsLayout: Layout {
  let columnCount: Int

  private var ratios: [CGFloat] {
    guard columnCount > 1 else { return Array(repeating: 1, count: columnCount) }
    return [1.3] + Array(repeating: 1, count: columnCount - 1)
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard !subviews.isEmpty else { return .zero }
    let totalRatio = ratios.prefix(subviews.count).reduce(0, +)
    let width = proposal.width ?? 0
    var maxHeight: CGFloat = 0
    for (index, subview) in subviews.enumerated() {
      let ratio = index < ratios.count ? ratios[index] : 1
      let columnWidth = totalRatio > 0 ? width * ratio / totalRatio : width / CGFloat(subviews.count)
      maxHeight = max(maxHeight, subview.sizeThatFits(.init(width: columnWidth, height: nil)).height)
    }
    return CGSize(width: width, height: maxHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let totalRatio = ratios.prefix(subviews.count).reduce(0, +)
    var x = bounds.minX
    for (index, subview) in subviews.enumerated() {
      let ratio = index < ratios.count ? ratios[index] : 1
      let width = totalRatio > 0 ? bounds.width * ratio / totalRatio : bounds.width / CGFloat(subviews.count)
      subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: .init(width: width, height: bounds.height))
      x += width
    }
  }
}
