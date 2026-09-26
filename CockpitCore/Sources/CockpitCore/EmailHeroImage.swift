import Foundation
import SQLiteData
import SwiftSoup

public enum EmailHeroImage {
  private static let chromeTerms = [
    "logo", "spacer", "icon", "badge", "social", "facebook", "instagram", "twitter",
    "pinterest", "app-store", "google-play",
  ]

  /// Selects the lead image from retained email HTML using fixed, local rules.
  public static func candidate(inHTML html: String) -> URL? {
    guard let document = try? SwiftSoup.parse(html) else { return nil }
    let images = (try? document.select("img").array()) ?? []
    let candidates = images.compactMap { image -> (URL, Double?)? in
      guard !EmailImageSignals.isTrackingPixel(image),
        let source = try? image.attr("src"),
        let url = URL(string: source),
        url.scheme?.lowercased() == "https",
        url.host != nil,
        !isChrome(image)
      else { return nil }
      return (url, declaredWidth(image))
    }

    guard !candidates.isEmpty else { return nil }
    if candidates.contains(where: { $0.1 != nil }) {
      return candidates.first(where: { ($0.1 ?? 0) >= 300 })?.0
    }
    return candidates.first?.0
  }

  private static func isChrome(_ image: Element) -> Bool {
    let identifyingText = ["src", "alt", "class", "id"].compactMap { attribute in
      try? image.attr(attribute)
    }.joined(separator: " ").lowercased()
    return chromeTerms.contains(where: identifyingText.contains)
  }

  private static func declaredWidth(_ image: Element) -> Double? {
    if let width = try? image.attr("width"), let pixels = pixelWidth(width) { return pixels }
    guard let style = try? image.attr("style") else { return nil }
    for declaration in style.split(separator: ";") {
      let parts = declaration.split(separator: ":", maxSplits: 1)
      guard parts.count == 2,
        parts[0].trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("width") == .orderedSame,
        let pixels = pixelWidth(String(parts[1]))
      else { continue }
      return pixels
    }
    return nil
  }

  private static func pixelWidth(_ rawValue: String) -> Double? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased().replacingOccurrences(of: "!important", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let numeric = value.hasSuffix("px") ? String(value.dropLast(2)) : value
    guard let width = Double(numeric), width >= 0 else { return nil }
    return width
  }
}

public enum OfferHeroImageOperations {
  /// Computes an offer's hero URL from the newest Gmail Artifact on demand.
  public static func url(for contentPieceID: ContentPiece.ID, in db: Database) throws -> URL? {
    guard let artifact = try (Artifact
      .where { $0.contentPieceID.eq(contentPieceID) && $0.transport.eq(StreamTransport.gmail) }
      .order { $0.acquiredAt.desc() }
      .fetchOne(db)),
      let html = artifact.rawSourceText
    else { return nil }
    return EmailHeroImage.candidate(inHTML: html)
  }
}
