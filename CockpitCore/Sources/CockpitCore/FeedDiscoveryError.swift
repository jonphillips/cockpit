import Foundation

public enum FeedDiscoveryError: Error, Equatable, Sendable {
  case invalidURL(String)
  case invalidResponse(URL)
  case unsuccessfulResponse(URL, Int)
  case noAlternateFeed(URL)
}

extension FeedDiscoveryError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidURL:
      "This Stream has an invalid URL."
    case .invalidResponse:
      "The feed returned an invalid response."
    case let .unsuccessfulResponse(_, statusCode):
      "The feed request failed (HTTP \(statusCode))."
    case .noAlternateFeed:
      "Cockpit couldn't find an RSS or Atom feed at this URL."
    }
  }
}
