import Dependencies
import Foundation

public struct FeedClient: Sendable {
  public var load: @Sendable (URL) async throws -> Data

  public init(load: @escaping @Sendable (URL) async throws -> Data) {
    self.load = load
  }

  public static let live = Self { url in
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let response = response as? HTTPURLResponse else {
      throw FeedDiscoveryError.invalidResponse(url)
    }
    guard (200..<300).contains(response.statusCode) else {
      throw FeedDiscoveryError.unsuccessfulResponse(url, response.statusCode)
    }
    return data
  }
}

extension FeedClient: DependencyKey {
  public static let liveValue = FeedClient.live
  public static let testValue = FeedClient { url in
    throw FeedDiscoveryError.noAlternateFeed(url)
  }
}

extension DependencyValues {
  public var feedClient: FeedClient {
    get { self[FeedClient.self] }
    set { self[FeedClient.self] = newValue }
  }
}
