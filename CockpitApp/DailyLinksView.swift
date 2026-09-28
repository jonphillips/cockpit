import CockpitCore
import SwiftUI

struct DailyLinksMasthead: View {
  @Bindable var model: DailyLinkModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      HStack(spacing: 7) {
        Text("DAILY")
          .font(Theme.sectionLabel)
          .tracking(Theme.sectionLabelTracking)
          .foregroundStyle(Theme.inkTertiary)
        ViewThatFits(in: .horizontal) {
          ForEach((0...model.links.count).reversed(), id: \.self) { visibleCount in
            chipLine(visibleCount: visibleCount, date: context.date)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func chipLine(visibleCount: Int, date: Date) -> some View {
    HStack(spacing: 6) {
      ForEach(Array(model.links.prefix(visibleCount))) { link in
        chip(link, date: date)
      }
      if visibleCount < model.links.count {
        overflowMenu(from: visibleCount, date: date)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private func chip(_ link: DailyLink, date: Date) -> some View {
    let visited = link.isVisited(on: date)
    return Button { open(link) } label: {
      HStack(spacing: 6) {
        DailyLinkGlyph(link: link, size: 20)
        Text(link.title)
          .font(Theme.byline)
          .lineLimit(1)
        if visited {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.accent)
        }
      }
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(Theme.paperSecondary, in: RoundedRectangle(cornerRadius: 7))
      .overlay {
        RoundedRectangle(cornerRadius: 7).stroke(Theme.rule, lineWidth: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(visited ? 0.76 : 1)
    .accessibilityLabel(visited ? "\(link.title), visited today" : link.title)
  }

  private func overflowMenu(from index: Int, date: Date) -> some View {
    Menu {
      ForEach(Array(model.links.dropFirst(index))) { link in
        openButton(link, date: date)
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.inkSecondary)
        .frame(width: 30, height: 28)
        .background(Theme.paperSecondary, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(Theme.rule, lineWidth: 1) }
    }
    .accessibilityLabel("More daily links")
  }

  @ViewBuilder
  private func openButton(_ link: DailyLink, date: Date) -> some View {
    if link.isVisited(on: date) {
      Button { open(link) } label: {
        Label(link.title, systemImage: "checkmark")
      }
    } else {
      Button(link.title, systemImage: link.symbolName) { open(link) }
    }
  }

  private func open(_ link: DailyLink) {
    guard let url = URL(string: link.url) else { return }
    openURL(url) { accepted in
      guard accepted else { return }
      Task { await model.recordVisit(link.id) }
    }
  }
}

struct DailyLinksMenu: View {
  @Bindable var model: DailyLinkModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      Menu {
        ForEach(model.links) { link in
          Button {
            guard let url = URL(string: link.url) else { return }
            openURL(url) { accepted in
              guard accepted else { return }
              Task { await model.recordVisit(link.id) }
            }
          } label: {
            if link.isVisited(on: context.date) {
              Label(link.title, systemImage: "checkmark")
            } else if let thumbnail = link.menuThumbnail {
              Label {
                Text(link.title)
              } icon: {
                Image(uiImage: thumbnail)
              }
            } else {
              Label(link.title, systemImage: link.symbolName)
            }
          }
        }
      } label: {
        Image(systemName: "link")
      }
      .accessibilityLabel("Daily links")
    }
  }
}

struct DailyLinksView: View {
  @Bindable var model: DailyLinkModel
  @State private var editor: Editor?

  var body: some View {
    List {
      Section {
        ForEach(model.links) { link in
          Button {
            editor = Editor(draft: DailyLinkDraft(editing: link))
          } label: {
            Label {
              Text(link.title)
            } icon: {
              DailyLinkGlyph(link: link, size: 28)
            }
            .foregroundStyle(.primary)
          }
          .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
              Task { await model.delete(link.id) }
            }
          }
        }
        .reorderable()
      } footer: {
        Text(
          "Touch and hold a link, then drag to reorder. "
            + "In News, open a channel, tap Share → Copy Link, and paste it here.")
      }

      if let errorMessage = model.errorMessage {
        Section {
          Text(errorMessage).foregroundStyle(.red)
        }
      }
    }
    .reorderContainer(for: DailyLink.self) { difference in
      let anchor: DailyLink.ID? = switch difference.destination.position {
      case .before(let id): id
      case .end: nil
      }
      Task { await model.reorder(moving: difference.sources, before: anchor) }
    }
    .navigationTitle("Daily links")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add", systemImage: "plus") { editor = Editor(draft: DailyLinkDraft()) }
      }
    }
    .task { try? await model.$content.load() }
    .sheet(item: $editor) { item in
      DailyLinkEditorSheet(model: model, draft: item.draft)
    }
  }
}

private struct Editor: Identifiable {
  let id = UUID()
  var draft: DailyLinkDraft
}
