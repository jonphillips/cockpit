import CockpitCore
import Dependencies
import GoogleSignIn
import GoogleSignInSwift
import Observation
import SQLiteData
import SwiftUI
import UIKit

@main
struct CockpitApp: App {
  init() {
    prepareDependencies {
      try! $0.bootstrapDatabase()
      $0.gmailDispositionClient = GmailDispositionWiring.liveClient
      $0.gmailReadStateClient = GmailDispositionWiring.liveReadStateClient
      $0.gmailReplyClient = GmailReplyWiring.liveClient
      $0.findReferralHandoffClient = FindReferralHandoffWiring.liveClient
    }
    Task { await CockpitCloudSync.startIfEnabled() }
  }

  var body: some Scene {
    WindowGroup {
      CockpitRootView()
        .onOpenURL { url in
          _ = GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}

@MainActor
private struct CockpitRootView: View {
  @State private var shellModel = ShellModel()
  @State private var followingModel = FollowingModel()
  @State private var editionModel = EditionModel()
  @State private var listedFeedsModel: ListedFeedsModel
  @State private var todayModel: TodayModel
  @State private var readingQueueModel = TodayReadingQueueModel()
  @State private var dailyLinkModel = DailyLinkModel()
  @State private var pendingFindModel = PendingFindListModel()
  @State private var inboxIngest = GmailInboxIngestModel()
  @State private var selectedFeedID: CockpitCore.Stream.ID?
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let listedFeedsModel = ListedFeedsModel()
    _listedFeedsModel = State(initialValue: listedFeedsModel)
    _todayModel = State(initialValue: TodayModel(listedFeedsModel: listedFeedsModel))
  }

  var body: some View {
    @Bindable var shellModel = shellModel
    TabView(selection: $shellModel.selection) {
      Tab("Today", systemImage: "sun.max", value: .today) {
        TodayView(
          model: todayModel,
          queueModel: readingQueueModel,
          tailModel: editionModel,
          inboxIngest: inboxIngest,
          dailyLinkModel: dailyLinkModel,
          shellModel: shellModel,
          selectedFeedID: $selectedFeedID,
          didChangeQueue: reloadTodayAndQueue
        )
      }
      Tab("Process", systemImage: "list.bullet.rectangle", value: .process) {
        ProcessView(
          model: readingQueueModel,
          tailModel: editionModel,
          isActive: shellModel.selection == .process,
          didChangeQueue: reloadTodayAndQueue
        )
      }
      Tab("Feeds", systemImage: "dot.radiowaves.up.forward", value: .feeds) {
        FeedsView(
          model: listedFeedsModel, followingModel: followingModel,
          selectedStreamID: $selectedFeedID)
      }
      Tab("Later", systemImage: "clock", value: .later) {
        ContentPieceListView(destination: .later)
      }
      Tab("Library", systemImage: "books.vertical", value: .library) {
        ContentPieceListView(destination: .library)
      }
      Tab("Settings", systemImage: "gearshape", value: .settings) {
        SettingsView(
          model: shellModel, followingModel: followingModel, pendingFindModel: pendingFindModel,
          dailyLinkModel: dailyLinkModel)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .task {
      shellModel.connectProcessSelection { contentPieceID in
        if let contentPieceID {
          readingQueueModel.selectedContentPieceID = contentPieceID
        }
      }
      await readingQueueModel.reload()
    }
    .task {
      await followingModel.acquireOnLaunchOrRefresh()
      try? await listedFeedsModel.reload()
    }
    .task { _ = await inboxIngest.autoSyncIfNeeded() }
    .task { await pendingFindModel.refreshHandoffState() }
    .onChange(of: shellModel.selection) { oldSelection, newSelection in
      guard oldSelection == .process, newSelection != .process else { return }
      Task {
        await readingQueueModel.leaveProcess()
        await reloadTodayAndQueue()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task {
        await pendingFindModel.refreshHandoffState()
        _ = await inboxIngest.autoSyncIfNeeded()
        await readingQueueModel.reload()
        try? await listedFeedsModel.reload()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      Task { try? await listedFeedsModel.reload() }
    }
  }

  @MainActor
  private func reloadTodayAndQueue() async {
    try? await todayModel.$content.load()
    try? await todayModel.$offers.load()
    await readingQueueModel.reload()
  }
}
