import CockpitCore
import SwiftUI
import UIKit

/// A link's thumbnail when it has one, otherwise its SF Symbol, in a `size`-point square.
struct DailyLinkGlyph: View {
  let symbolName: String
  let thumbnail: Data?
  let size: CGFloat

  init(link: DailyLink, size: CGFloat) {
    self.init(symbolName: link.symbolName, thumbnail: link.thumbnail, size: size)
  }

  init(symbolName: String, thumbnail: Data?, size: CGFloat) {
    self.symbolName = symbolName
    self.thumbnail = thumbnail
    self.size = size
  }

  var body: some View {
    if let thumbnail, let image = UIImage(data: thumbnail) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
    } else {
      Image(systemName: symbolName)
        .font(.system(size: size * 0.6))
        .frame(width: size, height: size)
    }
  }
}

extension DailyLink {
  /// Menus draw a `UIImage` at its point size, so the stored pixels are redrawn at icon size.
  var menuThumbnail: UIImage? {
    guard let thumbnail, let image = UIImage(data: thumbnail) else { return nil }
    let bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
    return UIGraphicsImageRenderer(size: bounds.size).image { _ in
      UIBezierPath(roundedRect: bounds, cornerRadius: 5).addClip()
      image.draw(in: bounds)
    }
  }
}
