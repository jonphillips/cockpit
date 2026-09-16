import Foundation
import SQLiteData

/// The ContentPiece-shaped projection used by the single Reader outside an Edition. Edition adds
/// rationale and resolution state as an optional context layer; the substance lives here.
public struct ContentPieceReaderRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let summary: String?
    public let canonicalURL: String?
    public let isSubstantivePrimary: Bool?
    public let bodyCompleteness: BodyCompleteness?
    /// Device-local readable substance. Completeness syncs with the ContentPiece, but this text
    /// deliberately does not, so the Reader must never infer its presence from completeness.
    public let localNormalizedText: String?
    public let laterAddedAt: Date?
    public let libraryAddedAt: Date?
  }

  public struct Value: Equatable, Sendable {
    public var row: Row?
    public init() {}
  }

  public let contentPieceID: ContentPiece.ID

  public init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
  }

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.row = try ContentPiece
      .where { $0.id.eq(contentPieceID) }
      .leftJoin(LaterMembership.all) { $0.id.eq($1.contentPieceID) }
      .leftJoin(LibraryMembership.all) { $0.id.eq($2.contentPieceID) }
      .leftJoin(LocalNormalizedText.all) { $0.id.eq($3.contentPieceID) }
      .select {
        Row.Columns(
          id: $0.id, title: $0.title, publisher: $0.publisher, summary: $0.summary,
          canonicalURL: $0.canonicalURL, isSubstantivePrimary: $0.isSubstantivePrimary,
          bodyCompleteness: $0.bodyCompleteness, localNormalizedText: $3.normalizedText,
          laterAddedAt: $1.addedAt,
          libraryAddedAt: $2.addedAt)
      }
      .fetchOne(db)
    return value
  }
}

public enum ReaderBodyPresentation: Equatable, Sendable {
  case inline(text: String, isTruncated: Bool)
  case compactPreview
  case preview
  case unavailable
}

/// Produces the Reader's custody-honest body state. `bodyCompleteness` says what the source
/// supplied; only `localNormalizedText` says whether this device may render it. A digest remains
/// a compact preview even when it happens to carry text.
public func readerBodyPresentation(
  for row: ContentPieceReaderRequest.Row?
) -> ReaderBodyPresentation {
  guard let row else { return .unavailable }
  guard row.isSubstantivePrimary != false else { return .compactPreview }

  guard let text = row.localNormalizedText,
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  else {
    return switch row.bodyCompleteness {
    case .full, .truncated: .unavailable
    case .teaser, .none: .preview
    }
  }

  return switch row.bodyCompleteness {
  case .full: .inline(text: text, isTruncated: false)
  case .truncated: .inline(text: text, isTruncated: true)
  case .teaser, .none: .preview
  }
}
