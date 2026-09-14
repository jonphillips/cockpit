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
  @State private var followingModel = FollowingModel()
  @State private var editionModel = EditionModel()

  var body: some View {
    ContentPieceListView(followingModel: followingModel, editionModel: editionModel)
      .task { await followingModel.acquireOnLaunchOrRefresh() }
  }
}
