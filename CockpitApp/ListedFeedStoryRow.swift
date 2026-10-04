import CockpitCore
import SwiftUI

struct ListedFeedStoryRow: View {
  let item: ListedFeedsRequest.Item
  let showsKicker: Bool
  let showsPublisherLabel: Bool
  let publisher: String?
  let showsTopRule: Bool
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: Theme.rowBylineSpacing) {
          if showsKicker {
            HStack(spacing: 4) {
              Text(item.streamName.uppercased()).foregroundStyle(Theme.accentInk)
              if showsPublisherLabel, let publisher {
                Text("· \(publisher)").foregroundStyle(Theme.inkTertiary)
              }
            }
            .font(Theme.sectionLabel)
            .tracking(1.1)
          }
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            HeadlineText(title: item.title, isUnread: !item.isOpened)
              .font(Theme.headline).foregroundStyle(Theme.ink).lineLimit(2)
            if item.isOpened {
              Text("Opened").font(Theme.meta).foregroundStyle(Theme.inkTertiary)
            }
          }
          Text([item.creator, item.description].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · "))
            .font(Theme.byline).foregroundStyle(Theme.inkSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Text(item.listedDate.formatted(.dateTime.hour().minute()))
          .font(Theme.meta).foregroundStyle(Theme.inkTertiary).padding(.top, 2)
      }
      .padding(.top, Theme.rowTopPadding)
      .padding(.bottom, Theme.rowBottomPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .top) {
        if showsTopRule { Rectangle().fill(Theme.rule).frame(height: 1) }
      }
      .opacity(item.isOpened ? 0.52 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
  }
}
