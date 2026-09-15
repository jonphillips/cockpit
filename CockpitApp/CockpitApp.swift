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
  @State private var shellModel = ShellModel()
  @State private var followingModel = FollowingModel()
  @State private var editionModel = EditionModel()

  var body: some View {
    @Bindable var shellModel = shellModel
    TabView(selection: $shellModel.selection) {
      Tab("Today", systemImage: "sun.max", value: .today) {
        TodayView(model: editionModel)
      }
      Tab("Edition", systemImage: "newspaper", value: .edition) {
        EditionView(model: editionModel)
      }
      Tab("Later", systemImage: "clock", value: .later) {
        ContentPieceListView(destination: .later)
      }
      Tab("Library", systemImage: "books.vertical", value: .library) {
        ContentPieceListView(destination: .library)
      }
      Tab("Settings", systemImage: "gearshape", value: .settings) {
        SettingsView(model: shellModel, followingModel: followingModel)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .task { await followingModel.acquireOnLaunchOrRefresh() }
  }
}

private struct TodayView: View {
  let model: EditionModel

  private var essentialBacklog: [CurrentEditionRequest.Row] {
    model.entries.filter { $0.section == .essentialBacklog && $0.entryState != .dismissed }
  }

  var body: some View {
    NavigationStack {
      List {
        if let edition = model.edition {
          Section("Today") {
            LabeledContent("Edition", value: edition.state.rawValue.capitalized)
            LabeledContent("Stories", value: model.entries.count.formatted())
          }
        } else {
          ContentUnavailableView(
            "No Edition Yet", systemImage: "sun.max",
            description: Text("Compose today's Edition to orient your day."))
        }

        if !essentialBacklog.isEmpty {
          Section("Essential Backlog") {
            ForEach(essentialBacklog) { row in
              Text(row.title)
            }
          }
        }
      }
      .navigationTitle("Today")
    }
  }
}
