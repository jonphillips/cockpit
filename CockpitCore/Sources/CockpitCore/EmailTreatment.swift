import Foundation
import SQLiteData

/// A user-authored correction to the deterministic Gmail treatment default. This narrow table is
/// intentionally not a sender reputation store: nothing writes it except an explicit correction.
@Table("emailSenderTreatmentOverrides")
public struct EmailSenderTreatmentOverride: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let senderKey: String
  public var treatment: EmailTreatment
  public var id: String { senderKey }

  public init(senderKey: String, treatment: EmailTreatment) {
    self.senderKey = senderKey
    self.treatment = treatment
  }
}

/// Deterministic classifier for S5's treatment hierarchy. It only routes mail: it does not score,
/// suppress, archive, or otherwise mutate the Gmail provider.
public enum EmailTreatmentOperations {
  public enum Failure: Error, Equatable, Sendable {
    case emptySender
  }

  /// Reclassifies the supplied Gmail ContentPieces from their retained S4 Artifact provenance.
  /// The returned values include the persisted tag, making it safe for an ingest report to expose
  /// the just-classified pieces without a second transaction.
  @discardableResult
  public static func classify(
    emailContentPieceIDs: some Sequence<ContentPiece.ID>, in db: Database
  ) throws -> [ContentPiece] {
    let uniqueIDs = Array(Set(emailContentPieceIDs)).sorted { $0.uuidString < $1.uuidString }
    return try uniqueIDs.compactMap { id in
      guard let piece = try ContentPiece.find(id).fetchOne(db), piece.kind == .email,
        let artifact = try (Artifact
          .where { $0.contentPieceID.eq(id) && $0.transport.eq(StreamTransport.gmail) }
          .order { $0.acquiredAt.desc() }
          .fetchOne(db))
      else { return nil }

      let provenance = artifact.providerProvenance.flatMap {
        try? JSONDecoder().decode(GmailArtifactProvenance.self, from: Data($0.utf8))
      }
      let senderKey = GmailHeaderParser.senderKey(from: piece.creator ?? piece.publisher)
      let override = try senderKey.flatMap { key in
        try EmailSenderTreatmentOverride.find(key).fetchOne(db)
      }
      let stream = try artifact.streamID.flatMap { id in try Stream.find(id).fetchOne(db) }
      let classification = EmailTreatmentClassifier.classify(
        piece: piece, provenance: provenance, stream: stream, override: override)

      if piece.emailTreatment != classification.treatment
        || piece.emailTransactionalKind != classification.transactionalKind
      {
        try ContentPiece.find(id).update {
          $0.emailTreatment = #bind(classification.treatment)
          $0.emailTransactionalKind = #bind(classification.transactionalKind)
        }.execute(db)
      }
      return try ContentPiece.find(id).fetchOne(db)
    }
  }

  /// Re-runs classification after a new explicit correction or an intentional reconsideration.
  /// It never creates sender overrides, so a default cannot silently become learned state.
  @discardableResult
  public static func reclassifyAll(in db: Database) throws -> [ContentPiece] {
    let ids = try Artifact.where { $0.transport.eq(StreamTransport.gmail) }
      .select { $0.contentPieceID }
      .fetchAll(db)
      .compactMap { $0 }
    return try classify(emailContentPieceIDs: ids, in: db)
  }

  /// Stores a correction that wins over deterministic routing, then updates already-ingested mail
  /// from the same sender. Calling this method is the required explicit user action.
  @discardableResult
  public static func setSenderOverride(
    _ treatment: EmailTreatment, for sender: String, in db: Database
  ) throws -> [ContentPiece] {
    guard let senderKey = GmailHeaderParser.senderKey(from: sender) else { throw Failure.emptySender }
    try EmailSenderTreatmentOverride.upsert {
      EmailSenderTreatmentOverride.Draft(senderKey: senderKey, treatment: treatment)
    }.execute(db)
    return try reclassifyAll(in: db)
  }

  @discardableResult
  public static func removeSenderOverride(for sender: String, in db: Database) throws -> [ContentPiece] {
    guard let senderKey = GmailHeaderParser.senderKey(from: sender) else { throw Failure.emptySender }
    try EmailSenderTreatmentOverride.find(senderKey).delete().execute(db)
    return try reclassifyAll(in: db)
  }
}
