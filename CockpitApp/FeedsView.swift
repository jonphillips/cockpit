import CockpitCore
import SwiftUI

struct FeedsView: View {
  @Bindable var model: ListedFeedsModel
  @Bindable var followingModel: FollowingModel
  @Binding var selection: FeedsSelection?
  @State private var undoMessage: String?
  @State private var errorMessage: String?
  @Environment(\.openURL) private var openURL

  private var selectedItemCount: Int {
    guard case let .stream(streamID)? = selection else { return model.items.count }
    return model.items.filter { $0.streamIDs.contains(streamID) }.count
  }

  var body: some View {
    NavigationSplitView {
      FeedsSidebar(model: model, selection: $selection)
    } detail: {
      FeedsListPane(
        model: model, selection: selection,
        onOpen: open, onLater: saveForLater, onLibrary: addToLibrary, onDismiss: dismiss)
        .navigationTitle("Feeds")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Dismiss all", systemImage: "checkmark.circle") {
              Task { await dismissAll() }
            }
            .disabled(selectedItemCount == 0)
          }
        }
    }
    .tint(Theme.accent)
    .safeAreaInset(edge: .bottom) {
      if let message = undoMessage ?? errorMessage ?? followingModel.errorMessage {
        HStack {
          Text(message)
          Spacer()
          if undoMessage != nil {
            Button("Undo") { Task { await undo() } }.fontWeight(.semibold)
          }
          Button("Dismiss") {
            undoMessage = nil
            errorMessage = nil
            followingModel.errorMessage = nil
          }
        }
        .padding()
        .background(.regularMaterial)
      }
    }
    .task { try? await model.reload() }
  }

  private func refresh() async {
    await followingModel.acquireOnLaunchOrRefresh()
    do {
      try await model.reload()
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  private func open(_ item: ListedFeedsRequest.Item) {
    guard let locator = item.canonicalURL, let url = URL(string: locator) else { return }
    openURL(url)
    Task {
      do { try await model.recordOpened(id: item.id) }
      catch { errorMessage = error.localizedDescription }
    }
  }

  private func dismiss(_ item: ListedFeedsRequest.Item) {
    Task {
      do {
        try await model.dismiss(id: item.id)
        undoMessage = "Dismissed story"
        errorMessage = nil
      } catch { errorMessage = error.localizedDescription }
    }
  }

  private func dismissAll() async {
    do {
      let streamID: CockpitCore.Stream.ID?
      if case let .stream(id)? = selection { streamID = id } else { streamID = nil }
      try await model.dismissAll(streamID: streamID)
      undoMessage = "Dismissed stories"
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  private func undo() async {
    do {
      try await model.undo()
      undoMessage = nil
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  private func saveForLater(_ item: ListedFeedsRequest.Item) {
    Task {
      do { try await model.saveForLater(id: item.id); errorMessage = nil }
      catch { errorMessage = error.localizedDescription }
    }
  }

  private func addToLibrary(_ item: ListedFeedsRequest.Item) {
    Task {
      do { try await model.addToLibrary(id: item.id); errorMessage = nil }
      catch { errorMessage = error.localizedDescription }
    }
  }
}
