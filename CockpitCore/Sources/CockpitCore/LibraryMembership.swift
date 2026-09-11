import Foundation
import SQLiteData

@Table
public struct LibraryMembership: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var addedAt: Date
  public var admittedBy: String
  public var id: ContentPiece.ID { contentPieceID }
}
