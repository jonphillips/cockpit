import Foundation
import SQLiteData

/// The ContentPiece-shaped projection used by the single Reader outside an Edition. Edition adds
/// rationale and resolution state as an optional context layer; the substance lives here.
public struct ContentPieceReaderRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let creator: String?
    public let publisher: String
    public let summary: String?
    public let canonicalURL: String?
    public let isSubstantivePrimary: Bool?
    public let bodyCompleteness: BodyCompleteness?
    /// Device-local readable substance. Completeness syncs with the ContentPiece, but this text
    /// deliberately does not, so the Reader must never infer its presence from completeness.
    public let localNormalizedText: String?
    public let localAvailabilityMode: LocalAvailabilityMode?
    public let offlineExpiresAt: Date?
    public let laterAddedAt: Date?
    public let libraryAddedAt: Date?

    public var sender: String { creator ?? publisher }
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
      .leftJoin(LocalAvailability.all) { $0.id.eq($4.contentPieceID) }
      .select {
        Row.Columns(
          id: $0.id, title: $0.title, creator: $0.creator, publisher: $0.publisher,
          summary: $0.summary,
          canonicalURL: $0.canonicalURL, isSubstantivePrimary: $0.isSubstantivePrimary,
          bodyCompleteness: $0.bodyCompleteness, localNormalizedText: $3.normalizedText,
          localAvailabilityMode: $4.mode, offlineExpiresAt: $4.expiresAt,
          laterAddedAt: $1.addedAt,
          libraryAddedAt: $2.addedAt)
      }
      .fetchOne(db)
    return value
  }
}

public enum OfflineAvailabilityPresentation: Equatable, Sendable {
  case ordinaryCache
  case offlineUntil(Date)
  case keptOffline
  case expired(Date)

  public var isActivePromise: Bool {
    switch self {
    case .offlineUntil, .keptOffline: true
    case .ordinaryCache, .expired: false
    }
  }
}

/// A status derived from local state only. An expired row is deliberately treated as ordinary
/// cache even before the eviction pass gets a chance to clear its redundant payload reference.
public func offlineAvailabilityPresentation(
  for row: ContentPieceReaderRequest.Row?, at date: Date
) -> OfflineAvailabilityPresentation {
  guard let row else { return .ordinaryCache }
  switch row.localAvailabilityMode {
  case .pinned:
    return .keptOffline
  case .until:
    guard let expiresAt = row.offlineExpiresAt else { return .ordinaryCache }
    return expiresAt > date ? .offlineUntil(expiresAt) : .expired(expiresAt)
  case .cache, .none:
    return .ordinaryCache
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
