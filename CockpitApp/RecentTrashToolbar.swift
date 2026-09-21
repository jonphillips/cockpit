import CockpitCore
import SwiftUI

struct RecentTrashToolbar: ToolbarContent {
  @Bindable var model: TodayModel
  @Binding var isShowing: Bool

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button("Recently trashed", systemImage: "trash") {
        Task {
          await model.loadRecentTrashes()
          isShowing = true
        }
      }
    }
  }
}
