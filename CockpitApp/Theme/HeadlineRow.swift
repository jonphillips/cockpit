import SwiftUI

struct HeadlineRow: View {
  let title: String
  let byline: String
  let time: String
  var isUnread = false

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: Theme.rowBylineSpacing) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          if isUnread {
            Circle()
              .fill(Theme.accent)
              .frame(width: 6, height: 6)
              .accessibilityLabel("Unread")
          }
          Text(title)
            .font(Theme.headline)
            .foregroundStyle(Theme.ink)
            .lineLimit(2)
        }
        Text(byline)
          .font(Theme.byline)
          .foregroundStyle(Theme.inkSecondary)
      }

      Spacer(minLength: 0)

      Text(time)
        .font(Theme.meta)
        .foregroundStyle(Theme.inkTertiary)
        .padding(.top, 2)
    }
    .padding(.top, Theme.rowTopPadding)
    .padding(.bottom, Theme.rowBottomPadding)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Headline row · light") {
  HeadlineRow(
    title: "A small change that reshaped the whole neighborhood",
    byline: "The Daily Ledger · Mara Example",
    time: "8:42 AM",
    isUnread: true
  )
  .padding()
  .background(Theme.paper)
  .preferredColorScheme(.light)
}

#Preview("Headline row · dark") {
  HeadlineRow(
    title: "A small change that reshaped the whole neighborhood",
    byline: "The Daily Ledger · Mara Example",
    time: "8:42 AM",
    isUnread: true
  )
  .padding()
  .background(Theme.paper)
  .preferredColorScheme(.dark)
}
