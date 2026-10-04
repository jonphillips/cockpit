import CockpitCore
import SwiftUI

enum FeedsSelection: Hashable {
  case all
  case stream(CockpitCore.Stream.ID)
}

struct FeedsSidebar: View {
  @Bindable var model: ListedFeedsModel
  @Binding var selection: FeedsSelection?

  var body: some View {
    List(selection: $selection) {
      Text("All feeds").tag(FeedsSelection.all as FeedsSelection?).badge(model.totalNewCount)
      ForEach(ListedFeedGrouping.publisherGroups(model.sources)) { group in
        Section(group.publisher) {
          ForEach(group.sources) { source in
            Text(source.name).tag(FeedsSelection.stream(source.id) as FeedsSelection?).badge(source.newCount)
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
  let selection: FeedsSelection?
  let onOpen: (ListedFeedsRequest.Item) -> Void
  let onLater: (ListedFeedsRequest.Item) -> Void
  let onLibrary: (ListedFeedsRequest.Item) -> Void
  let onDismiss: (ListedFeedsRequest.Item) -> Void

  private var selectedItems: [ListedFeedsRequest.Item] {
    guard case let .stream(streamID)? = selection else { return model.items }
    return model.items.filter { $0.streamIDs.contains(streamID) }
  }

  private var selectedTitle: String {
    guard case let .stream(selectedStreamID)? = selection else { return "All feeds" }
    return model.sources.first(where: { $0.id == selectedStreamID })?.name ?? "All feeds"
  }

  private var selectedNewCount: Int {
    guard case let .stream(selectedStreamID)? = selection else { return model.totalNewCount }
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
              item: item, showsKicker: selection == .all,
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
