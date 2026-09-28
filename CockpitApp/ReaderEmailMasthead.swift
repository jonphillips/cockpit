import CockpitCore
import SwiftUI

struct ReaderEmailMasthead: View {
  let row: ContentPieceReaderRequest.Row
  let kind: EmailPresentation.Kind
  let roleName: String
  let zoom: Double
  let adjustText: (Int) -> Void
  let fitText: () -> Void

  var body: some View {
    switch kind {
    case .letter:
      letterHeader
    case .designed:
      newsletterStrip
    }
  }

  private var letterHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(roleName)
        .font(Theme.sectionLabel)
        .tracking(1.6)
        .foregroundStyle(Theme.accent)
      Text(row.title).font(Theme.articleTitle).foregroundStyle(Theme.ink)
      HStack(alignment: .firstTextBaseline) {
        (Text(row.sender).fontWeight(.semibold) + Text(" · \(row.publisher)"))
          .font(Theme.byline).foregroundStyle(Theme.inkSecondary)
        Spacer()
        Text(row.receivedAt, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
          .font(Theme.byline).foregroundStyle(Theme.inkSecondary)
      }
      Rectangle().fill(Theme.ink).frame(height: 1)
    }
  }

  private var newsletterStrip: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(roleName).font(Theme.sectionLabel).tracking(1.4).foregroundStyle(Theme.accent)
      Text(row.publisher.uppercased())
        .font(.system(size: 12, weight: .semibold, design: .serif))
        .tracking(1.2).foregroundStyle(Theme.ink)
      Text(row.receivedAt, format: .dateTime.month(.wide).day())
        .font(Theme.byline).foregroundStyle(Theme.inkSecondary)
      Spacer(minLength: 4)
      Menu {
        Button("Smaller", systemImage: "textformat.size.smaller") { adjustText(-1) }
        Button("Larger", systemImage: "textformat.size.larger") { adjustText(1) }
        Divider()
        Button("Fit", systemImage: "arrow.left.and.right", action: fitText)
      } label: {
        Label("\(Int((zoom * 100).rounded()))% for this sender", systemImage: "textformat.size")
          .font(.caption)
      }
      .menuStyle(.borderlessButton)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Theme.ground)
  }
}
