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
  }

  var body: some Scene {
    WindowGroup {
      ContentPieceListView()
        .onOpenURL { url in
          _ = GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}
