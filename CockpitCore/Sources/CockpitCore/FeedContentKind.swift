import Foundation

enum FeedContentKind {
  static func infer(from url: URL?) -> ContentKind {
    guard let host = url?.host?.lowercased() else { return .article }
    if host.contains("youtube.com") || host == "youtu.be" { return .video }
    return .article
  }
}
