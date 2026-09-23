import CockpitCore
import SwiftUI

/// The reading state for Today: one queue across every role section, with the selected piece in a
/// real split detail. The orientation surface remains the landing state; this view does not create
/// a second destination or a per-section navigation stack.
struct TodayReadingView: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let done: () -> Void

  @AppStorage("cockpit.today.reading-list-width") private var storedListWidth = Double(ReadingPaneWidth.defaultValue)
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var isDraggingDivider = false
  @State private var dragStartWidth: CGFloat?

  private var listWidth: CGFloat {
    ReadingPaneWidth.clamped(CGFloat(storedListWidth))
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      TodayReadingQueueSidebar(
        model: model,
        listWidth: listWidth,
        isDraggingDivider: isDraggingDivider,
        dividerDragChanged: dividerDragChanged,
        dividerDragEnded: dividerDragEnded
      )
    } detail: {
      TodayReadingQueueDetail(model: model, tailModel: tailModel)
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Done", systemImage: "checkmark") { finishReading() }
      }
    }
    .task { await model.reload() }
    .onChange(of: model.selectedContentPieceID) { oldID, newID in
      guard let oldID, oldID != newID else { return }
      Task { await model.applySeriesTrashOnLeave(oldID) }
    }
    .safeAreaInset(edge: .bottom) {
      if let errorMessage = model.errorMessage {
        HStack {
          Text(errorMessage)
          Spacer()
          Button("Dismiss") { model.errorMessage = nil }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
  }

}

private extension TodayReadingView {
  func dividerDragChanged(_ translation: CGFloat) {
    if dragStartWidth == nil { dragStartWidth = listWidth }
    guard let dragStartWidth else { return }
    isDraggingDivider = true
    storedListWidth = Double(ReadingPaneWidth.clamped(dragStartWidth + translation))
  }

  func dividerDragEnded() {
    isDraggingDivider = false
    dragStartWidth = nil
  }

  func finishReading() {
    let selectedID = model.selectedContentPieceID
    Task {
      if let selectedID { await model.applySeriesTrashOnLeave(selectedID) }
      done()
    }
  }
}

private struct TodayReadingQueueSidebar: View {
  @Bindable var model: TodayReadingQueueModel
  let listWidth: CGFloat
  let isDraggingDivider: Bool
  let dividerDragChanged: (CGFloat) -> Void
  let dividerDragEnded: () -> Void

  var body: some View {
    List(selection: $model.selectedContentPieceID) {
      ForEach(model.sections) { section in
        Section(section.role.displayName) {
          ForEach(section.rows) { row in
            TodayReadingQueueRow(
              row: row,
              archive: { Task { await model.archive(row) } },
              trash: { Task { await model.trash(row) } }
            )
            .tag(row.id)
          }
        }
      }
    }
    .navigationSplitViewColumnWidth(
      min: ReadingPaneWidth.minimum, ideal: listWidth, max: ReadingPaneWidth.maximum)
    .overlay(alignment: .trailing) {
      ReadingDividerHandle(
        isDragging: isDraggingDivider,
        onChanged: dividerDragChanged,
        onEnded: dividerDragEnded
      )
    }
    .overlay {
      if model.rows.isEmpty {
        ContentUnavailableView(
          "Nothing in the Queue", systemImage: "checkmark.circle",
          description: Text("The morning reading queue is clear."))
      }
    }
    .toolbar {
      if let disposition = model.lastDisposition {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Undo", systemImage: "arrow.uturn.backward") {
            Task { await model.undoLastDisposition() }
          }
          .accessibilityLabel(
            "Undo \(disposition.disposition == .archive ? "archive" : "trash") of \(disposition.title)"
          )
        }
      }
    }
  }

}

private struct TodayReadingQueueDetail: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  @State private var originalWebViewStore = TodayOriginalWebViewStore()

  var body: some View {
    if let selectedContentPieceID = model.selectedContentPieceID,
      let row = model.rows.first(where: { $0.id == selectedContentPieceID })
    {
      ReaderView(
        contentPieceID: row.id,
        editionContext: editionContext(for: row),
        queueContext: ReaderQueueContext(
          archive: { await model.archive(row) },
          trash: { await model.trash(row) }
        ),
        isReachableStreamPiece: row.isFollowedStreamPiece,
        originalWebViewStore: originalWebViewStore
      )
      .id(row.id)
    } else {
      ContentUnavailableView(
        "Select a Piece", systemImage: "doc.text",
        description: Text("The queue runs from For you through Offers."))
    }
  }

  private func editionContext(for row: TodayReadingQueueRequest.Row) -> EditionReaderContext? {
    guard let entryID = row.editionEntryID else { return nil }
    return EditionReaderContext(
      model: tailModel,
      entryID: entryID,
      rationale: row.editionRationale,
      matchedPersonalKnowledgeClaimID: row.matchedPersonalKnowledgeClaimID,
      clearSelection: { model.selectedContentPieceID = nil }
    )
  }
}

private struct ReadingDividerHandle: View {
  let isDragging: Bool
  let onChanged: (CGFloat) -> Void
  let onEnded: () -> Void

  var body: some View {
    Rectangle()
      .fill(.clear)
      .frame(width: 24)
      .contentShape(Rectangle())
      .overlay {
        Capsule()
          .fill(isDragging ? .secondary : .quaternary)
          .frame(width: 4, height: 36)
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { onChanged($0.translation.width) }
          .onEnded { _ in onEnded() }
      )
      .accessibilityElement()
      .accessibilityLabel("Reading list divider")
      .accessibilityHint("Drag to resize the reading list")
  }
}
