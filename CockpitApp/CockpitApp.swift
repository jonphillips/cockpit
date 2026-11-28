import CockpitCore
import Dependencies
import GoogleSignIn
import GoogleSignInSwift
import Observation
import SQLiteData
import SwiftUI
import UIKit
import UserNotifications

@main
struct CockpitApp: App {
  @UIApplicationDelegateAdaptor(CockpitAppDelegate.self) private var appDelegate
  init() {
    prepareDependencies {
      try! $0.bootstrapDatabase()
      $0.gmailDispositionClient = GmailDispositionWiring.liveClient
      $0.gmailReadStateClient = GmailDispositionWiring.liveReadStateClient
      $0.gmailReplyClient = GmailReplyWiring.liveClient
      $0.findReferralHandoffClient = FindReferralHandoffWiring.liveClient
    }
    _ = MorningPrepWiring.shared
    Task { await CockpitCloudSync.startIfEnabled() }
  }

  var body: some Scene {
    WindowGroup {
      CockpitRootView()
        .onOpenURL { url in
          _ = GIDSignIn.sharedInstance.handle(url)
        }
    }
    .backgroundTask(.appRefresh(MorningPrepWiring.backgroundTaskIdentifier)) {
      await MorningPrepWiring.handleBackgroundRefresh()
    }
  }
}

@MainActor
final class CockpitAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NotificationCenter.default.post(name: .offerWatchDeviceToken, object: token)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    NotificationCenter.default.post(name: .offerWatchRegistrationFailed, object: error.localizedDescription)
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.content.userInfo["kind"] as? String == "mail",
      let messageID = response.notification.request.content.userInfo["source"] as? String {
      NotificationCenter.default.post(name: .offerWatchMessageTapped, object: messageID)
    }
    completionHandler()
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
  }
}

private extension Notification.Name {
  static let offerWatchDeviceToken = Notification.Name("offerWatchDeviceToken")
  static let offerWatchRegistrationFailed = Notification.Name("offerWatchRegistrationFailed")
  static let offerWatchMessageTapped = Notification.Name("offerWatchMessageTapped")
}

@MainActor
private struct CockpitRootView: View {
  @State private var shellModel = ShellModel()
  @State private var followingModel = FollowingModel()
  @State private var editionModel = EditionModel()
  @State private var listedFeedsModel: ListedFeedsModel
  @State private var todayModel: TodayModel
  @State private var dispositionQueue: GmailDispositionQueue
  @State private var readingQueueModel: TodayReadingQueueModel
  @State private var dailyLinkModel = DailyLinkModel()
  @State private var pendingFindModel = PendingFindListModel()
  @State private var morningPrep: MorningPrep
  @State private var offerAlerts = OfferAlertsModel(environment: Bundle.main.object(forInfoDictionaryKey: "OfferWatchAPNSEnvironment") as? String ?? "sandbox")
  @State private var feedSelection: FeedsSelection? = .all
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let morningPrep = MorningPrepWiring.shared
    let listedFeedsModel = ListedFeedsModel()
    let dispositionQueue = GmailDispositionQueue.shared
    _listedFeedsModel = State(initialValue: listedFeedsModel)
    _dispositionQueue = State(initialValue: dispositionQueue)
    _todayModel = State(initialValue: TodayModel(
      listedFeedsModel: listedFeedsModel, dispositionQueue: dispositionQueue))
    _readingQueueModel = State(initialValue: TodayReadingQueueModel(dispositionQueue: dispositionQueue))
    _morningPrep = State(initialValue: morningPrep)
    _followingModel = State(initialValue: FollowingModel(morningPrep: morningPrep))
  }

  var body: some View {
    @Bindable var shellModel = shellModel
    TabView(selection: $shellModel.selection) {
      Tab("Today", systemImage: "sun.max", value: .today) {
        TodayView(
          model: todayModel,
          queueModel: readingQueueModel,
          tailModel: editionModel,
          morningPrep: morningPrep,
          dailyLinkModel: dailyLinkModel,
          shellModel: shellModel,
          feedSelection: $feedSelection,
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
          selection: $feedSelection)
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
          dailyLinkModel: dailyLinkModel, morningPrep: morningPrep, offerAlerts: offerAlerts)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .tint(Theme.accent)
    .task {
      shellModel.connectProcessSelection { contentPieceID in
        if let contentPieceID {
          readingQueueModel.selectedContentPieceID = contentPieceID
        }
      }
      await readingQueueModel.reload()
    }
    .task {
      morningPrep.recordOpen()
      _ = await morningPrep.run(.init(trigger: .open))
      await reloadTodayAndQueue()
      try? await listedFeedsModel.reload()
    }
    .task { await pendingFindModel.refreshHandoffState() }
    .onChange(of: shellModel.selection) { oldSelection, newSelection in
      guard oldSelection == .process, newSelection != .process else { return }
      Task {
        await readingQueueModel.leaveProcess()
        await reloadTodayAndQueue()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        Task { await morningPrep.scheduleNextRefresh() }
      }
      guard phase == .active else { return }
      Task {
        await pendingFindModel.refreshHandoffState()
        morningPrep.recordOpen()
        _ = await morningPrep.run(.init(trigger: .open))
        await readingQueueModel.reload()
        try? await todayModel.$content.load()
        try? await todayModel.$offers.load()
        try? await listedFeedsModel.reload()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      Task { try? await listedFeedsModel.reload() }
    }
    .offerWatchNotifications(model: offerAlerts, shellModel: shellModel)
  }

  @MainActor
  private func reloadTodayAndQueue() async {
    try? await todayModel.$content.load()
    try? await todayModel.$offers.load()
    await readingQueueModel.reload()
  }
}

private extension View {
  func offerWatchNotifications(model: OfferAlertsModel, shellModel: ShellModel) -> some View {
    onReceive(NotificationCenter.default.publisher(for: .offerWatchDeviceToken)) { note in
      if let token = note.object as? String { model.didRegister(deviceToken: token) }
    }
    .onReceive(NotificationCenter.default.publisher(for: .offerWatchRegistrationFailed)) { note in
      if let message = note.object as? String { model.didFailRegistration(message) }
    }
    .onReceive(NotificationCenter.default.publisher(for: .offerWatchMessageTapped)) { note in
      guard let messageID = note.object as? String else { return }
      shellModel.pushSettings(.offerAlert(messageID: messageID))
    }
  }
}
