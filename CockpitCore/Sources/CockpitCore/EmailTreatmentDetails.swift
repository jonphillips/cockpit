import Foundation
import SQLiteData

/// Device-local material produced for the two Gmail treatments that inspect a message's held
/// substance. It is intentionally not synced: another device may not hold the originating body,
/// and can derive its own detail when it ingests that message.
@Table("emailTreatmentDetails")
public struct EmailTreatmentDetails: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var offerSummary: String?
  /// JSON-encoded `GrabBagItem`s in source order. Items are descriptions inside one issue, not
  /// independently addressable Cockpit records.
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
