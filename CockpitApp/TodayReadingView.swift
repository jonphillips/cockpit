import CockpitCore
import SwiftUI

/// The reading state for Today: one queue across every role section, with the selected piece in a
/// real split detail. The orientation surface remains the landing state.
struct TodayReadingView: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let done: () -> Void

  @AppStorage("cockpit.today.reading-list-width") private var storedListWidth = Double(ReadingPaneWidth.defaultValue)
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  private var listWidth: CGFloat {
    ReadingPaneWidth.clamped(CGFloat(storedListWidth))
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      TodayReadingQueueSidebar(
        model: model,
        listWidth: listWidth,
        backToToday: finishReading,
        onCommitWidth: commitWidth
      )
    } detail: {
      TodayReadingQueueDetail(
        model: model,
        tailModel: tailModel,
        showsBackButton: columnVisibility == .detailOnly,
        backToToday: finishReading
      )
    }
    .navigationSplitViewStyle(.balanced)
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

  private func commitWidth(_ translation: CGFloat) {
    guard let width = ReadingPaneWidth.committedWidth(
      current: listWidth, translation: translation
    ) else { return }
    storedListWidth = Double(width)
  }

  private func finishReading() {
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
  let backToToday: () -> Void
  let onCommitWidth: (CGFloat) -> Void

  var body: some View {
    ScrollViewReader { proxy in
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
              .id(row.id)
            }
          }
        }
      }
      .navigationSplitViewColumnWidth(
        min: ReadingPaneWidth.minimum, ideal: listWidth, max: ReadingPaneWidth.maximum)
      .safeAreaInset(edge: .trailing, spacing: 0) {
        if model.sections.count > 1 {
          sectionRail { contentPieceID in
            withAnimation { proxy.scrollTo(contentPieceID, anchor: .top) }
          }
        }
      }
      .overlay {
        if model.rows.isEmpty {
          ContentUnavailableView(
            "Nothing in the Queue", systemImage: "checkmark.circle",
            description: Text("The morning reading queue is clear."))
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back to Today", systemImage: "chevron.backward", action: backToToday)
        }
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
      .overlay(alignment: .trailing) {
        ReadingDividerHandle(currentWidth: listWidth, onCommit: onCommitWidth)
      }
    }
  }

  private func sectionRail(scrollTo: @escaping (ContentPiece.ID) -> Void) -> some View {
    ScrollView(.vertical) {
      VStack(spacing: 6) {
        ForEach(model.sections) { section in
          Button {
            scrollTo(section.rows[0].id)
          } label: {
            VStack(spacing: 1) {
              Image(systemName: section.role.symbolName)
                .font(.body)
                .foregroundStyle(section.role.color)
              Text("\(section.rows.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 48)
            .background {
              if model.selectedRole == section.role {
                Capsule().fill(section.role.color.opacity(0.16))
              }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(section.role.displayName), \(section.rows.count) messages")
        }
      }
      .padding(.vertical, 4)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .frame(width: 48)
    .accessibilityElement(children: .contain)
    .background(.regularMaterial)
  }
}

private struct TodayReadingQueueDetail: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let showsBackButton: Bool
  let backToToday: () -> Void
  @State private var originalWebViewStore = TodayOriginalWebViewStore()

  var body: some View {
    Group {
      if let selectedContentPieceID = model.selectedContentPieceID,
        let row = model.rows.first(where: { $0.id == selectedContentPieceID })
      {
        ReaderView(
          contentPieceID: row.id,
          editionContext: makeEditionReaderContext(
            row: row, tailModel: tailModel,
            clearSelection: { model.selectedContentPieceID = nil }),
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
    .toolbar {
      if showsBackButton {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back to Today", systemImage: "chevron.backward", action: backToToday)
        }
      }
    }
  }
}

private struct ReadingDividerHandle: View {
  let currentWidth: CGFloat
  let onCommit: (CGFloat) -> Void
  @State private var dragStartWidth: CGFloat?
  @State private var translation: CGFloat = 0

  private var previewOffset: CGFloat {
    guard let dragStartWidth else { return 0 }
    return ReadingPaneWidth.clamped(dragStartWidth + translation) - dragStartWidth
  }

  var body: some View {
    Rectangle()
      .fill(.clear)
      .frame(width: 24)
      .contentShape(Rectangle())
      .overlay {
        Capsule()
          .fill(dragStartWidth == nil ? .quaternary : .secondary)
          .frame(width: 4, height: 36)
          .offset(x: previewOffset)
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            if dragStartWidth == nil { dragStartWidth = currentWidth }
            translation = value.translation.width
          }
          .onEnded { value in
            if dragStartWidth == nil { dragStartWidth = currentWidth }
            onCommit(value.translation.width)
            dragStartWidth = nil
            translation = 0
          }
      )
      .accessibilityElement()
      .accessibilityLabel("Reading list divider")
      .accessibilityHint("Drag to resize the reading list")
  }
}
