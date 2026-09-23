import Foundation

/// Only direct user taps on ordinary web or mail links may leave the email web view.
public enum EmailLinkPolicy {
  public static func externalURL(for url: URL?, isUserActivated: Bool) -> URL? {
    guard isUserActivated, let url,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let scheme = components.scheme?.lowercased()
    else { return nil }

    switch scheme {
    case "http", "https":
      guard let host = components.host, !host.isEmpty else { return nil }
      return url
    case "mailto":
      guard !components.path.isEmpty else { return nil }
      return url
    default:
      return nil
    }
  }
}
