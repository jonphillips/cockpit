import Foundation
import SQLiteData

/// The explicit reason Jon supplied while reading a ContentPiece. This is intentionally a small,
/// append-only provenance record—not a general evidence graph. Its identity and source linkage
/// let a resulting claim answer both "what did Jon say?" and "what was he reading?".
@Table("personalKnowledgeTeachings")
public struct PersonalKnowledgeTeaching: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let contentPieceID: ContentPiece.ID
  public var reason: String
  public let createdAt: Date

  public init(id: UUID, contentPieceID: ContentPiece.ID, reason: String, createdAt: Date) {
    self.id = id
    self.contentPieceID = contentPieceID
    self.reason = reason
    self.createdAt = createdAt
  }
}
