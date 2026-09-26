import CockpitCore
import SwiftUI

extension View {
  func offerReviewCover(
    role: Binding<ContentRole?>,
    model: TodayModel,
    onDismiss: @escaping () -> Void
  ) -> some View {
    let isPresented = Binding(
      get: { role.wrappedValue != nil },
      set: { if !$0 { role.wrappedValue = nil } }
    )
    return fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
      if let selectedRole = role.wrappedValue {
        OfferReviewView(role: selectedRole, todayModel: model) {
          isPresented.wrappedValue = false
        }
      }
    }
  }
}
