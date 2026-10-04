import Foundation

extension ListedFeedsRequest {
  public struct Item: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let creator: String?
    public let canonicalURL: String?
    public let listedDate: Date
    public let streamID: Stream.ID
    public let streamIDs: [Stream.ID]
    public let streamName: String
    public let isOpened: Bool
    public let description: String

    public init(
      id: ContentPiece.ID, title: String, creator: String?, canonicalURL: String?, listedDate: Date,
      streamID: Stream.ID, streamName: String, isOpened: Bool, description: String,
      streamIDs: [Stream.ID]? = nil
    ) {
      self.id = id
      self.title = title
      self.creator = creator
      self.canonicalURL = canonicalURL
      self.listedDate = listedDate
      self.streamID = streamID
      self.streamIDs = streamIDs ?? [streamID]
      self.streamName = streamName
      self.isOpened = isOpened
      self.description = description
    }
  }
}
