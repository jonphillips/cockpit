import Foundation
import SQLiteData

/// The persisted, type-organized projection for Today. Its query reaches only Gmail-backed email
/// that has not been explicitly cleared in Cockpit; there is no Gmail client on this path.
public struct TodayRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let creator: String?
    public let publisher: String
    public let summary: String?
    public let treatmentSummary: String?
    public let grabBagItemsJSON: String?
    public let treatment: EmailTreatment
    public let publishedAt: Date?
    public let acquiredAt: Date

    public var arrivedAt: Date { publishedAt ?? acquiredAt }
    public var sender: String { creator ?? publisher }

    public var grabBagItems: [GrabBagItem] {
      guard let grabBagItemsJSON,
        let data = grabBagItemsJSON.data(using: .utf8),
        let items = try? JSONDecoder().decode([GrabBagItem].self, from: data)
      else { return [] }
      return items
    }
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    let gmailArtifacts = try Artifact.where {
      $0.transport.eq(StreamTransport.gmail)
    }.fetchAll(db)
    let clearedContentPieceIDs = Set(try TodayAttention.all.fetchAll(db).map(\.contentPieceID))
    let detailsByContentPieceID = Dictionary(
      uniqueKeysWithValues: try EmailTreatmentDetails.all.fetchAll(db).map { ($0.contentPieceID, $0) })
    var acquiredAtByContentPieceID: [ContentPiece.ID: Date] = [:]
    for artifact in gmailArtifacts {
      guard let contentPieceID = artifact.contentPieceID else { continue }
      if let existing = acquiredAtByContentPieceID[contentPieceID] {
        acquiredAtByContentPieceID[contentPieceID] = max(existing, artifact.acquiredAt)
      } else {
        acquiredAtByContentPieceID[contentPieceID] = artifact.acquiredAt
      }
    }

    var value = Value()
    // Keep the email predicate in SQL. Today reloads repeatedly and must not scan Library's entire
    // ContentPiece corpus merely to discard non-email rows in Swift.
    value.rows = try ContentPiece.where { $0.kind.eq(ContentKind.email) }.fetchAll(db).compactMap { piece in
      guard let treatment = piece.emailTreatment,
        !clearedContentPieceIDs.contains(piece.id),
        let acquiredAt = acquiredAtByContentPieceID[piece.id]
      else { return nil }
      return Row(
        id: piece.id, title: piece.title, creator: piece.creator, publisher: piece.publisher,
        summary: piece.summary,
        treatmentSummary: detailsByContentPieceID[piece.id]?.offerSummary,
        grabBagItemsJSON: detailsByContentPieceID[piece.id]?.grabBagItems,
        treatment: treatment, publishedAt: piece.publishedAt, acquiredAt: acquiredAt)
    }
    value.rows.sort {
      if $0.arrivedAt != $1.arrivedAt { return $0.arrivedAt > $1.arrivedAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    return value
  }
}
