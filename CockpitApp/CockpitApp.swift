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

private struct CockpitRootView: View {
  @State private var shellModel = ShellModel()
  @State private var followingModel = FollowingModel()
  @State private var editionModel = EditionModel()
  @State private var todayModel = TodayModel()
  @State private var dailyLinkModel = DailyLinkModel()
  @State private var pendingFindModel = PendingFindListModel()
  @State private var inboxIngest = GmailInboxIngestModel()
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var shellModel = shellModel
    TabView(selection: $shellModel.selection) {
      Tab("Today", systemImage: "sun.max", value: .today) {
        TodayView(
          model: todayModel, tailModel: editionModel, inboxIngest: inboxIngest,
          dailyLinkModel: dailyLinkModel)
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
    .task { await followingModel.acquireOnLaunchOrRefresh() }
    .task { _ = await inboxIngest.autoSyncIfNeeded() }
    .task { await pendingFindModel.refreshHandoffState() }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task {
        await pendingFindModel.refreshHandoffState()
        _ = await inboxIngest.autoSyncIfNeeded()
      }
    }
  }
}
