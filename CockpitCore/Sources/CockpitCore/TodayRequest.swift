import Foundation
import SQLiteData

/// The persisted, type-organized projection for Today. Its query reaches only Gmail-backed email
/// that has not been explicitly cleared in Cockpit; there is no Gmail client on this path.
public struct TodayRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let summary: String?
    public let treatment: EmailTreatment
    public let publishedAt: Date?
    public let acquiredAt: Date

    public var arrivedAt: Date { publishedAt ?? acquiredAt }
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
    value.rows = try ContentPiece.all.fetchAll(db).compactMap { piece in
      guard piece.kind == .email,
        let treatment = piece.emailTreatment,
        !clearedContentPieceIDs.contains(piece.id),
        let acquiredAt = acquiredAtByContentPieceID[piece.id]
      else { return nil }
      return Row(
        id: piece.id, title: piece.title, publisher: piece.publisher, summary: piece.summary,
        treatment: treatment, publishedAt: piece.publishedAt, acquiredAt: acquiredAt)
    }
    value.rows.sort {
      if $0.arrivedAt != $1.arrivedAt { return $0.arrivedAt > $1.arrivedAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    return value
  }
}
