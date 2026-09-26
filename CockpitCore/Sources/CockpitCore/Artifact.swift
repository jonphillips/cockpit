import Foundation
import SQLiteData

@Table("artifacts")
public struct Artifact: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var streamID: Stream.ID?
  public var transport: StreamTransport
  public var providerID: String?
  public var canonicalURL: String?
  public var acquiredAt: Date
  public var payloadRef: String?
  public var rawSourceText: String?
  /// Device-local, provider-specific evidence needed to explain later treatment. Gmail stores the
  /// raw classification headers and message/thread/account identifiers here; it is deliberately
  /// not a new cross-provider entity or a synced field.
  public var providerProvenance: String?
  /// Device-local mirror of Gmail's UNREAD label. This changes with provider state, so it is kept
  /// separate from immutable ingest provenance. Nil means unknown or a non-Gmail transport.
  public var providerIsUnread: Bool?
  public var contentPieceID: ContentPiece.ID?

  public init(
    id: UUID,
    streamID: Stream.ID? = nil,
    transport: StreamTransport,
    providerID: String? = nil,
    canonicalURL: String? = nil,
    acquiredAt: Date,
    payloadRef: String? = nil,
    rawSourceText: String? = nil,
    providerProvenance: String? = nil,
    providerIsUnread: Bool? = nil,
    contentPieceID: ContentPiece.ID? = nil
  ) {
    self.id = id
    self.streamID = streamID
    self.transport = transport
    self.providerID = providerID
    self.canonicalURL = canonicalURL
    self.acquiredAt = acquiredAt
    self.payloadRef = payloadRef
    self.rawSourceText = rawSourceText
    self.providerProvenance = providerProvenance
    self.providerIsUnread = providerIsUnread
    self.contentPieceID = contentPieceID
  }
}
