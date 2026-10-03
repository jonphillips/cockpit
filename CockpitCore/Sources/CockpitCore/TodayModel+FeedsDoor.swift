import Foundation

extension TodayModel {
  public struct FeedsDoor: Equatable, Sendable {
    public struct SourceCount: Equatable, Identifiable, Sendable {
      public let id: Stream.ID
      public let name: String
      public let count: Int
    }

    public let totalCount: Int
    public let sources: [SourceCount]
    public let newestTitle: String
    public let newestStreamName: String
    public let newestDate: Date

    public static func make(from feeds: ListedFeedsRequest.Value) -> FeedsDoor? {
      guard feeds.totalNewCount > 0,
        let newest = feeds.items.filter({ !$0.isOpened }).max(by: { $0.listedDate < $1.listedDate })
      else { return nil }
      return FeedsDoor(
        totalCount: feeds.totalNewCount,
        sources: feeds.sources.compactMap { source in
          source.newCount > 0
            ? SourceCount(id: source.id, name: source.name, count: source.newCount) : nil
        },
        newestTitle: newest.title,
        newestStreamName: newest.streamName,
        newestDate: newest.listedDate)
    }
  }
}
