import CockpitCore
import SwiftUI

/// The one ordered morning queue. Today is the overview; Process owns sustained reading.
struct ProcessView: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let isActive: Bool
  let didChangeQueue: @MainActor () async -> Void

  var body: some View {
    NavigationSplitView {
      ProcessQueueSidebar(model: model, didChangeQueue: didChangeQueue)
    } detail: {
      ProcessQueueDetail(
        model: model,
        tailModel: tailModel,
        isActive: isActive,
        didChangeQueue: didChangeQueue
      )
    }
    .navigationSplitViewStyle(.balanced)
    .task {
      await model.reload()
      if model.selectedContentPieceID == nil {
        model.selectedContentPieceID = model.rows.first?.id
      }
    }
    .onChange(of: model.selectedContentPieceID) { oldID, newID in
      guard let oldID, oldID != newID else { return }
      Task {
        await model.applySeriesTrashOnLeave(oldID)
        await didChangeQueue()
      }
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

private struct ProcessQueueSidebar: View {
  @Bindable var model: TodayReadingQueueModel
  let didChangeQueue: @MainActor () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      queueProgress
        .padding(.horizontal)
        .padding(.vertical, 8)

      List(selection: $model.selectedContentPieceID) {
        ForEach(model.sections) { section in
          Section(section.role.displayName) {
            ForEach(section.rows) { row in
              TodayReadingQueueRow(
                row: row,
                archive: { dispose { await model.archive(row) } },
                trash: { dispose { await model.trash(row) } }
              )
              .tag(row.id)
              .id(row.id)
            }
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
    }
    .navigationTitle("Process")
    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
    .toolbar {
      ToolbarItemGroup(placement: .topBarLeading) {
        Button("Previous", systemImage: "chevron.up") {
          model.selectPrevious()
        }
        .disabled(!canSelectPrevious)

        Button("Next", systemImage: "chevron.down") {
          model.selectNext()
        }
        .disabled(!canSelectNext)
      }

      if let disposition = model.lastDisposition {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Undo", systemImage: "arrow.uturn.backward") {
            Task {
              await model.undoLastDisposition()
              await didChangeQueue()
            }
          }
          .accessibilityLabel(
            "Undo \(disposition.disposition == .archive ? "archive" : "trash") of \(disposition.title)"
          )
        }
      }
    }
  }

  @ViewBuilder
  private var queueProgress: some View {
    if let position = model.position {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(position.index) of \(position.total)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)

        if model.doneCount > 0 {
          let roles = model.doneRoles.map(\.displayName).joined(separator: ", ")
          Label {
            Text(
              roles.isEmpty
                ? "\(model.doneCount) done"
                : "\(model.doneCount) done · \(roles)"
            )
          } icon: {
            Image(systemName: "checkmark")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    } else if model.doneCount > 0 {
      Text("\(model.doneCount) done")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var selectedIndex: Int? {
    guard let selectedContentPieceID = model.selectedContentPieceID else { return nil }
    return model.rows.firstIndex { $0.id == selectedContentPieceID }
  }

  private var canSelectPrevious: Bool {
    guard let selectedIndex else { return !model.rows.isEmpty }
    return selectedIndex > model.rows.startIndex
  }

  private var canSelectNext: Bool {
    guard let selectedIndex else { return !model.rows.isEmpty }
    return model.rows.indices.contains(selectedIndex + 1)
  }

  private func dispose(_ operation: @escaping @MainActor () async -> Void) {
    Task {
      await operation()
      await didChangeQueue()
    }
  }
}

private struct ProcessQueueDetail: View {
  @Bindable var model: TodayReadingQueueModel
  @Bindable var tailModel: EditionModel
  let isActive: Bool
  let didChangeQueue: @MainActor () async -> Void
  @State private var originalWebViewStore = TodayOriginalWebViewStore()

  var body: some View {
    Group {
      if let selectedContentPieceID = model.selectedContentPieceID,
        let row = model.rows.first(where: { $0.id == selectedContentPieceID })
      {
        ReaderView(
          contentPieceID: row.id,
          editionContext: makeEditionReaderContext(
            row: row,
            tailModel: tailModel,
            clearSelection: { advancePast(row) },
            didDismiss: {
              await model.recordDismissed(row)
              await didChangeQueue()
            }
          ),
          queueContext: ReaderQueueContext(
            archive: {
              await model.archive(row)
              await didChangeQueue()
            },
            trash: {
              await model.trash(row)
              await didChangeQueue()
            }
          ),
          isReachableStreamPiece: row.isFollowedStreamPiece,
          originalWebViewStore: originalWebViewStore
        )
        .id(row.id)
        .task(id: row.id) {
          if isActive { model.markPresented(row.id) }
        }
        .onChange(of: isActive) { _, active in
          if active { model.markPresented(row.id) }
        }
      } else {
        ContentUnavailableView(
          "Select a Piece", systemImage: "doc.text",
          description: Text("The queue runs in section order."))
      }
    }
  }

  @MainActor
  private func advancePast(_ row: TodayReadingQueueRequest.Row) {
    model.selectedContentPieceID = ReadingQueueSelection.neighbour(of: row.id, in: model.rows)
    Task { await didChangeQueue() }
  }
}
