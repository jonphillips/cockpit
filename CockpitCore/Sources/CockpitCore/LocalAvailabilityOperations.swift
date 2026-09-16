import Foundation
import SQLiteData

public enum LocalAvailabilityOperations {
  public enum Failure: Error, Equatable, LocalizedError, Sendable {
    case substanceUnavailable
    case invalidExpiry

    public var errorDescription: String? {
      switch self {
      case .substanceUnavailable:
        "Cockpit does not hold enough substance on this device to make an offline promise."
      case .invalidExpiry:
        "Choose a future date for offline availability."
      }
    }
  }

  /// Makes an explicit temporary promise. The promise is only made when the device already holds
  /// readable text or a payload; S3 does not invent a downloader it cannot verify.
  public static func keepOffline(
    _ id: ContentPiece.ID, until expiresAt: Date, verifiedAt: Date, in db: Database
  ) throws {
    guard expiresAt > verifiedAt else { throw Failure.invalidExpiry }
    let existing = try LocalAvailability.find(id).fetchOne(db)
    guard try hasLocallyHeldSubstance(id, existing: existing, in: db) else {
      throw Failure.substanceUnavailable
    }
    try store(
      id, mode: .until, expiresAt: expiresAt, verifiedAt: verifiedAt,
      payloadRef: existing?.payloadRef, in: db)
  }

  /// Makes an indefinite, user-controlled promise. It survives every cache eviction pass until
  /// the person explicitly releases it.
  public static func keepOffline(
    _ id: ContentPiece.ID, verifiedAt: Date, in db: Database
  ) throws {
    let existing = try LocalAvailability.find(id).fetchOne(db)
    guard try hasLocallyHeldSubstance(id, existing: existing, in: db) else {
      throw Failure.substanceUnavailable
    }
    try store(id, mode: .pinned, expiresAt: nil, verifiedAt: verifiedAt, payloadRef: existing?.payloadRef, in: db)
  }

  /// Returns the piece to ordinary cache semantics without touching its ContentPiece, text,
  /// memberships, or provenance.
  public static func releaseOffline(_ id: ContentPiece.ID, in db: Database) throws {
    try LocalAvailability.find(id).delete().execute(db)
  }

  /// The single cache-eviction seam. It may discard ordinary/expired payload references, never
  /// normalized text or a future/indefinite explicit promise.
  public static func evictAutomaticPayloads(at date: Date, in db: Database) throws {
    let availabilities = try LocalAvailability.all.fetchAll(db)
    for availability in availabilities where isEvictable(availability, at: date) {
      try store(
        availability.contentPieceID, mode: .cache, expiresAt: nil, verifiedAt: availability.verifiedAt,
        payloadRef: nil, in: db)
    }
  }

  private static func hasLocallyHeldSubstance(
    _ id: ContentPiece.ID, existing: LocalAvailability?, in db: Database
  ) throws -> Bool {
    if existing?.payloadRef != nil { return true }
    guard let text = try NormalizedTextOperations.text(for: id, in: db) else { return false }
    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private static func isEvictable(_ availability: LocalAvailability, at date: Date) -> Bool {
    switch availability.mode {
    case .cache: true
    case .until: availability.expiresAt.map { $0 <= date } ?? true
    case .pinned: false
    }
  }

  private static func store(
    _ id: ContentPiece.ID,
    mode: LocalAvailabilityMode,
    expiresAt: Date?,
    verifiedAt: Date,
    payloadRef: String?,
    in db: Database
  ) throws {
    try LocalAvailability.upsert {
      LocalAvailability.Draft(
        contentPieceID: id, mode: mode, expiresAt: expiresAt, verifiedAt: verifiedAt,
        payloadRef: payloadRef)
    }.execute(db)
  }
}
