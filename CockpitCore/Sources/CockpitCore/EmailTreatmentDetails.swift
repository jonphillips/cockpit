import Foundation
import SQLiteData

/// Device-local offer detail. Legacy grab-bag extracts remain readable from existing rows, but
/// new issues are kept whole. Details are not synced: another device may not hold the source body.
@Table("emailTreatmentDetails")
public struct EmailTreatmentDetails: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var offerSummary: String?
  /// Legacy JSON-encoded `GrabBagItem`s, retained so old rows need no destructive migration.
  public var grabBagItems: String?

  public var id: ContentPiece.ID { contentPieceID }

  public init(
    contentPieceID: ContentPiece.ID, offerSummary: String? = nil, grabBagItems: String? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.offerSummary = offerSummary
    self.grabBagItems = grabBagItems
  }

  public var decodedGrabBagItems: [GrabBagItem] {
    guard let grabBagItems,
      let data = grabBagItems.data(using: .utf8),
      let items = try? JSONDecoder().decode([GrabBagItem].self, from: data)
    else { return [] }
    return items
  }
}

/// A described worthwhile item within one manually marked digest. Its identity is derived from
/// that issue plus its source reference or title, so re-extraction remains stable without making
/// a universal ContentPiece or Find hierarchy.
public struct GrabBagItem: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let title: String
  public let summary: String
  public let sourceURL: String?

  public init(id: UUID, title: String, summary: String, sourceURL: String? = nil) {
    self.id = id
    self.title = title
    self.summary = summary
    self.sourceURL = sourceURL
  }
}
