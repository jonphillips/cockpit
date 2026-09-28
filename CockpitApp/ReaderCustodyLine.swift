import SwiftUI

struct ReaderCustodyLine: View {
  var body: some View {
    Label(
      "When you leave, the source email may trash automatically — this issue stays in its stream, custody intact.",
      systemImage: "shield.lefthalf.filled"
    )
    .font(Theme.byline)
    .foregroundStyle(Theme.inkSecondary)
    .tint(Theme.accent)
    .padding(.vertical, 6)
    .overlay(alignment: .top) {
      Rectangle().fill(Theme.rule).frame(height: 1)
    }
  }
}
