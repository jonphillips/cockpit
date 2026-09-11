import Foundation
import SQLiteData

/// Device-local readable substance, independent of payload and destination lifecycles.
@Table
public struct LocalNormalizedText: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var normalizedText: String
  public var id: ContentPiece.ID { contentPieceID }
}
