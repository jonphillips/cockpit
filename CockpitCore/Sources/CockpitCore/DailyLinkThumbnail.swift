import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Normalizes a photo into the small square JPEG a Daily link stores. The column is small
/// enough to sit inline on the row (and on its CloudKit record once DailyLinks sync).
public enum DailyLinkThumbnail {
  /// Pixel edge of the stored square: 64pt at 3x, the largest the thumbnail is drawn.
  public static let pixelSize = 192
  public static let maximumBytes = 100_000

  public enum Failure: Error, Equatable, LocalizedError, Sendable {
    case unreadableImage

    public var errorDescription: String? {
      switch self {
      case .unreadableImage: "That photo couldn't be used as a thumbnail."
      }
    }
  }

  /// Decodes any ImageIO format (HEIC, JPEG, PNG, …), applies EXIF orientation, center-crops to
  /// a square, and re-encodes at `pixelSize` as JPEG.
  public static func make(from imageData: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0
    else { throw Failure.unreadableImage }

    // Size the decode so the short side still covers `pixelSize` after the crop.
    let aspect = Double(max(width, height)) / Double(min(width, height))
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Int((Double(pixelSize) * aspect).rounded(.up)),
    ]
    guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw Failure.unreadableImage }

    let side = min(decoded.width, decoded.height)
    let crop = CGRect(
      x: (decoded.width - side) / 2, y: (decoded.height - side) / 2, width: side, height: side)
    guard let square = decoded.cropping(to: crop) else { throw Failure.unreadableImage }

    let edge = min(side, pixelSize)
    guard
      let context = CGContext(
        data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw Failure.unreadableImage }
    context.interpolationQuality = .high
    context.draw(square, in: CGRect(x: 0, y: 0, width: edge, height: edge))
    guard let scaled = context.makeImage() else { throw Failure.unreadableImage }

    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw Failure.unreadableImage }
    CGImageDestinationAddImage(
      destination, scaled, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw Failure.unreadableImage }
    return output as Data
  }
}
