import SwiftUI

struct EmailTextSizeMenu: View {
  let label: String
  let canIncrease: Bool
  let canDecrease: Bool
  let canFit: Bool
  let smaller: () -> Void
  let larger: () -> Void
  let fit: () -> Void

  var body: some View {
    Menu {
      Button("Smaller", systemImage: "textformat.size.smaller", action: smaller)
        .disabled(!canDecrease)
      Button("Larger", systemImage: "textformat.size.larger", action: larger)
        .disabled(!canIncrease)
      Divider()
      Button("Fit", systemImage: "arrow.left.and.right", action: fit)
        .disabled(!canFit)
    } label: {
      Label(label, systemImage: "textformat.size")
    }
  }
}
