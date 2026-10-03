import CockpitCore
import SwiftUI

struct FeedsSidebar: View {
  @Bindable var model: ListedFeedsModel
  @Binding var selectedStreamID: CockpitCore.Stream.ID?

  private var publisherGroups: [PublisherGroup] {
    var groups: [PublisherGroup] = []
    for source in model.sources {
      if let index = groups.firstIndex(where: { $0.publisher == source.publisher }) {
        groups[index].sources.append(source)
      } else {
        groups.append(PublisherGroup(publisher: source.publisher, sources: [source]))
      }
    }
    return groups
  }

  var body: some View {
    List(selection: $selectedStreamID) {
      Text("All feeds").tag(nil as CockpitCore.Stream.ID?).badge(model.totalNewCount)
      ForEach(publisherGroups, id: \.publisher) { group in
        Section(group.publisher) {
          ForEach(group.sources) { source in
            Text(source.name).tag(Optional(source.id)).badge(source.newCount)
          }
        }
      }
    }
    .navigationTitle("Feeds")
    .navigationSplitViewColumnWidth(min: 220, ideal: 270)
  }
}

struct FeedsListPane: View {
  @Bindable var model: ListedFeedsModel
  let selectedStreamID: CockpitCore.Stream.ID?
  let onOpen: (ListedFeedsRequest.Item) -> Void
  let onLater: (ListedFeedsRequest.Item) -> Void
  let onLibrary: (ListedFeedsRequest.Item) -> Void
  let onDismiss: (ListedFeedsRequest.Item) -> Void

  private var selectedItems: [ListedFeedsRequest.Item] {
    guard let selectedStreamID else { return model.items }
    return model.items.filter { $0.streamID == selectedStreamID }
  }

  private var selectedTitle: String {
    guard let selectedStreamID else { return "All feeds" }
    return model.sources.first(where: { $0.id == selectedStreamID })?.name ?? "All feeds"
  }

  private var selectedNewCount: Int {
    guard let selectedStreamID else { return model.totalNewCount }
    return model.sources.first(where: { $0.id == selectedStreamID })?.newCount ?? 0
  }

  private var dayGroups: [ListedFeedDayGroup] {
    ListedFeedGrouping.dayGroups(selectedItems, now: .now, calendar: .current)
  }

  var body: some View {
    Group {
      if selectedItems.isEmpty {
        ContentUnavailableView(
          "Nothing new in your feeds", systemImage: "dot.radiowaves.up.forward",
          description: Text(!model.hasListedStreams
            ? "Stories from feeds you list appear here for seven days. Add a feed in Settings → Following → Add Stream."
            : "Stories from feeds you list appear here for seven days."))
      } else {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(selectedTitle).font(Theme.queueTitle).foregroundStyle(Theme.ink)
            Text("\(selectedNewCount) new · the last seven days")
              .font(Theme.byline).foregroundStyle(Theme.inkSecondary)
          }
          .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
          itemList
        }
        .background(Theme.paper)
      }
    }
    .background(Theme.paper)
  }

  private var itemList: some View {
    List {
      ForEach(dayGroups) { group in
        Section {
          ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
            ListedFeedStoryRow(
              item: item, showsKicker: selectedStreamID == nil,
              showsPublisherLabel: model.showsPublisherLabel,
              publisher: model.sources.first(where: { $0.id == item.streamID })?.publisher,
              showsTopRule: index > 0, onOpen: { onOpen(item) })
              .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
              .listRowSeparator(.hidden)
              .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button("Later", systemImage: "clock") { onLater(item) }.tint(Theme.accent)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
                  onDismiss(item)
                }
              }
              .contextMenu {
                Button("Save for Later", systemImage: "clock") { onLater(item) }
                Button("Add to Library", systemImage: "books.vertical") { onLibrary(item) }
                Divider()
                Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
                  onDismiss(item)
                }
              }
          }
        } header: {
          SectionLabel(title: group.title, count: group.items.count)
            .padding(.horizontal, 24).padding(.top, 12).textCase(nil)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }
}

private struct PublisherGroup {
  let publisher: String
  var sources: [ListedFeedsRequest.Source]
}
