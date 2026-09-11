import Foundation
import SQLiteData

/// The nullable Library-owned sync projection. Removal clears its fields, not local text.
/// SQLiteData transports BLOBs as CKAssets, outside CKRecord's 1 MB field limit.
@Table
public struct LibraryNormalizedText: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var libraryMembershipID: LibraryMembership.ID?
  public var utf8: Data?
  public var id: ContentPiece.ID { contentPieceID }
}
