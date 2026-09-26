import CockpitCore
import SwiftUI
import UIKit

struct OfferReviewCard: View {
  let row: OfferReviewRequest.Row
  let role: ContentRole
  let openEmail: () -> Void
  let keep: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button(action: openEmail) {
        ZStack(alignment: .bottomLeading) {
          OfferRemoteHero(url: row.heroURL, color: role.color)
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 10, contentMode: .fit)
          Text(row.sender)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)

      Text(row.subject).font(.headline).fixedSize(horizontal: false, vertical: true)
      if let find = row.pendingFind {
        VStack(alignment: .leading, spacing: 3) {
          Text(find.kind.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(role.color)
          Text(find.name).font(.subheadline.weight(.semibold))
          Text(find.descriptor).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
      }
      if let summary = row.summary, !summary.isEmpty {
        Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
      }
      HStack {
        Button("Open email", systemImage: "envelope.open", action: openEmail)
          .buttonStyle(.bordered)
        Spacer()
        if let find = row.pendingFind {
          Button(find.state == .confirmed ? "Kept" : "Keep", systemImage: "checkmark", action: keep)
            .buttonStyle(.borderedProminent)
            .tint(find.state == .confirmed ? .green : role.color)
            .disabled(find.state == .referred || find.state == .handedOff)
        }
      }
      HStack {
        Text(row.arrivedAt, format: .dateTime.month().day())
        Spacer()
        if row.isUnread { Label("Unread", systemImage: "circle.fill") }
      }
      .font(.caption2)
      .foregroundStyle(.tertiary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
  }
}

struct OfferRemoteHero: View {
  let url: URL?
  let color: Color
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        Rectangle().fill(color.opacity(0.18))
          .overlay(Image(systemName: "tag").font(.largeTitle).foregroundStyle(color))
      }
    }
    .clipped()
    .task(id: url) { await loadImage() }
  }

  private func loadImage() async {
    guard let url else { image = nil; return }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    do {
      let (data, _) = try await session.data(from: url)
      image = UIImage(data: data)
    } catch {
      image = nil
    }
  }
}
