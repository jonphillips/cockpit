import Foundation
import SQLiteData

@Table
public struct LaterMembership: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var addedAt: Date
  public var id: ContentPiece.ID { contentPieceID }
}
