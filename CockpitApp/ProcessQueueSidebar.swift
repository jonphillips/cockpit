import CockpitCore
import SwiftUI

struct ProcessQueueSidebar: View {
  @Bindable var model: TodayReadingQueueModel
  let didChangeQueue: @MainActor () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ProcessQueueHeader(model: model)
        .padding(.horizontal)
        .padding(.vertical, 8)
      List {
        ForEach(model.sections) { section in
          Section {
            ForEach(section.rows) { row in
              ProcessQueueListRow(row: row, isSelected: model.selectedContentPieceID == row.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  if row.isGmailSource {
                    Button("Trash", systemImage: "trash", role: .destructive) {
                      dispose { await model.trash(row) }
                    }
                    Button("Archive", systemImage: "archivebox") {
                      dispose { await model.archive(row) }
                    }
                  }
                }
                .id(row.id)
                .contentShape(Rectangle())
                .onTapGesture { model.selectedContentPieceID = row.id }
                .accessibilityAddTraits(.isButton)
            }
          } header: {
            HStack {
              Text(section.role.displayName.uppercased())
                .font(Theme.sectionLabel).tracking(1.2)
              Spacer()
              Text(section.rows.count, format: .number)
                .font(Theme.sectionLabel).monospacedDigit()
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Theme.paperSecondary)
      .overlay {
        if model.rows.isEmpty {
          ContentUnavailableView(
            "Nothing in the Queue", systemImage: "checkmark.circle",
            description: Text("The morning reading queue is clear."))
        }
      }
    }
    .navigationTitle("Process")
    .background(Theme.paperSecondary)
    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
    .toolbar {
      ToolbarItemGroup(placement: .topBarLeading) {
        Button("Previous", systemImage: "chevron.up") { model.selectPrevious() }
          .disabled(!canSelectPrevious)
        Button("Next", systemImage: "chevron.down") { model.selectNext() }
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

private struct ProcessQueueHeader: View {
  let model: TodayReadingQueueModel

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text("This morning").font(Theme.queueTitle).foregroundStyle(Theme.ink)
        Spacer()
        if let position = model.position {
          Text("\(position.index) of \(position.total)")
            .font(Theme.meta).foregroundStyle(Theme.inkTertiary)
        }
      }
      if model.doneCount > 0 {
        let roles = model.doneRoles.map(\.displayName).joined(separator: ", ")
        Label(
          roles.isEmpty ? "\(model.doneCount) done" : "\(model.doneCount) done · \(roles)",
          systemImage: "checkmark"
        )
        .font(Theme.byline)
        .foregroundStyle(Theme.accent)
      }
    }
  }
}

private struct ProcessQueueListRow: View {
  let row: TodayReadingQueueRequest.Row
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(row.title).font(Theme.queueHeadline).foregroundStyle(Theme.ink).lineLimit(2)
        Spacer(minLength: 4)
        Text(row.arrivedAt, format: .dateTime.hour().minute())
          .font(Theme.meta).foregroundStyle(Theme.inkTertiary)
      }
      Text(row.sourceLabel).font(Theme.byline).foregroundStyle(Theme.inkSecondary).lineLimit(1)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isSelected ? Theme.paper : Color.clear)
    .overlay(alignment: .leading) {
      if isSelected { Rectangle().fill(Theme.rule).frame(width: 1) }
    }
    .listRowInsets(EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5))
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
    .accessibilityElement(children: .combine)
  }
}
