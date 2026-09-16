import Foundation
import SQLiteData

/// The retention promise a person has made to this device. It is deliberately separate from
/// membership and source custody: a cache may be evicted, while an active promise may not.
public enum LocalAvailabilityMode: String, Codable, QueryBindable, Sendable {
  case cache
  case until
  case pinned
}

/// Device-local availability and payload custody. A nil `payloadRef` means the ordinary cache has
/// no payload; readable normalized text is held separately in `LocalNormalizedText`.
@Table("localAvailabilities")
public struct LocalAvailability: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var mode: LocalAvailabilityMode
  public var expiresAt: Date?
  public var verifiedAt: Date
  public var payloadRef: String?
  public var id: ContentPiece.ID { contentPieceID }

  public init(
    contentPieceID: ContentPiece.ID,
    mode: LocalAvailabilityMode,
    expiresAt: Date? = nil,
    verifiedAt: Date,
    payloadRef: String? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.mode = mode
    self.expiresAt = expiresAt
    self.verifiedAt = verifiedAt
    self.payloadRef = payloadRef
  }
}
