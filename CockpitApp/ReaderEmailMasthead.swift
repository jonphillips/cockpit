import CockpitCore
import SwiftUI

struct ReaderEmailMasthead: View {
  let row: ContentPieceReaderRequest.Row
  let kind: EmailPresentation.Kind
  let roleName: String
  let offlinePresentation: OfflineAvailabilityPresentation
  let zoom: Double
  let adjustText: (Int) -> Void
  let fitText: () -> Void
  let canIncrease: Bool
  let canDecrease: Bool
  let canFit: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch kind {
      case .letter:
        letterHeader
      case .designed:
        newsletterStrip
      }
      OfflineAvailabilityStatus(presentation: offlinePresentation)
    }
  }

  private var letterHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(roleName)
        .font(Theme.sectionLabel)
        .tracking(Theme.sectionLabelTracking)
        .foregroundStyle(Theme.accent)
      Text(row.title).font(Theme.articleTitle).foregroundStyle(Theme.ink)
      HStack(alignment: .firstTextBaseline) {
        HStack(spacing: 0) {
          Text(row.sender).fontWeight(.semibold)
          if row.sender.localizedCaseInsensitiveCompare(row.publisher) != .orderedSame {
            Text(" · \(row.publisher)")
          }
        }
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
      Text(roleName)
        .font(Theme.sectionLabel)
        .tracking(Theme.sectionLabelTracking)
        .foregroundStyle(Theme.accent)
      Text(row.publisher)
        .font(Theme.publisher)
        .textCase(.uppercase)
        .foregroundStyle(Theme.ink)
      Text(row.receivedAt, format: .dateTime.month(.wide).day())
        .font(Theme.byline).foregroundStyle(Theme.inkSecondary)
      Spacer(minLength: 4)
      EmailTextSizeMenu(
        label: "\(Int((zoom * 100).rounded()))% for this sender",
        canIncrease: canIncrease,
        canDecrease: canDecrease,
        canFit: canFit,
        smaller: { adjustText(-1) },
        larger: { adjustText(1) },
        fit: fitText
      )
      .font(.caption)
      .menuStyle(.borderlessButton)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Theme.ground)
  }
}
