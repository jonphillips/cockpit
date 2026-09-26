import CockpitCore
import SwiftUI

struct DailyLinksColumn: View {
  @Bindable var model: DailyLinkModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      VStack(spacing: 14) {
        ForEach(model.links) { link in
          let visited = link.isVisited(on: context.date)
          Button {
            open(link)
          } label: {
            VStack(spacing: 2) {
              DailyLinkGlyph(link: link, size: 36)
                .saturation(visited ? 0 : 1)
              if visited {
                Image(systemName: "checkmark")
                  .font(.system(size: 9, weight: .bold))
              } else {
                Color.clear.frame(height: 9)
              }
            }
            .foregroundStyle(visited ? .secondary : .primary)
            .frame(width: 56)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .opacity(visited ? 0.55 : 1)
          .accessibilityLabel(link.title)
          .help(link.title)
          .contextMenu {
            Button("Open \(link.title)", systemImage: link.symbolName) { open(link) }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.top, 62)
      .frame(width: 56)
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
