import Dependencies
import Foundation
import LLMClientKit
import Observation
import SQLiteData

/// Owns the Reader's ContentPiece-intrinsic state and idempotent membership writes. Edition-only
/// state remains in `EditionModel` so a Library/Later read can never manufacture an Edition action.
@MainActor
@Observable
public final class ContentPieceReaderModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Dependency(\.apiKeyStore) private var apiKeyStore
  @ObservationIgnored @Dependency(\.frontierPreferenceStore) private var preferenceStore
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Fetch public var content = ContentPieceReaderRequest.Value()
  @ObservationIgnored @Fetch public var readerTeaching = ReaderTeachingClaimRequest.Value()
  @ObservationIgnored @Fetch public var matchedPersonalKnowledge = MatchedPersonalKnowledgeClaimRequest.Value()
  public var errorMessage: String?
  public var teachingReason = ""
  public var teachingStage: ReaderTeachingStage?
  public var isReviewingTeaching = false
  public var teachingProviderDescription: String?

  public init(
    contentPieceID: ContentPiece.ID,
    matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID? = nil
  ) {
    _content = Fetch(wrappedValue: .init(), ContentPieceReaderRequest(contentPieceID: contentPieceID))
    _readerTeaching = Fetch(
      wrappedValue: .init(), ReaderTeachingClaimRequest(contentPieceID: contentPieceID)
    )
    _matchedPersonalKnowledge = Fetch(
      wrappedValue: .init(),
      MatchedPersonalKnowledgeClaimRequest(claimID: matchedPersonalKnowledgeClaimID)
    )
  }

  public var row: ContentPieceReaderRequest.Row? { content.row }
  public var readerTaughtClaim: PersonalKnowledgeRequest.Row? { readerTeaching.claim }
  public var matchedClaim: PersonalKnowledgeRequest.Row? { matchedPersonalKnowledge.claim }

  public func saveForLater() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.saveForLater(id, at: date, in: $0) }
  }

  public func addToLibrary() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.addToLibrary(id, at: date, in: $0) }
  }

  public func correctIsSubstantivePrimary(to value: Bool) async {
    guard let id = row?.id else { return }
    await run {
      try ContentPiece.find(id).update { $0.isSubstantivePrimary = #bind(value) }.execute($0)
    }
  }

  /// Opening this flow is an explicit teaching act. Nothing about opening or reading the piece is
  /// captured as Personal Knowledge; a claim can only follow an explicit reason and confirmation.
  public func beginTeaching() {
    teachingStage = .reason
    errorMessage = nil
  }

  public func cancelTeaching() {
    teachingStage = nil
    teachingReason = ""
  }

  public func reviewTeachingButtonTapped() async {
    guard let row else { return }
    let reason = teachingReason.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !reason.isEmpty else {
      errorMessage = PersonalKnowledgeOperations.Failure.emptyClaim.localizedDescription
      return
    }

    isReviewingTeaching = true
    defer { isReviewingTeaching = false }
    do {
      let provider = PersonalKnowledgeModel.resolveImportProvider(
        preferred: preferenceStore.preferred(),
        isConfigured: { apiKeyStore.key($0) != nil }
      )
      teachingProviderDescription = provider?.displayName ?? "the on-device model"
      let claims = try await database.read { db in try PersonalKnowledgeClaim.all.fetchAll(db) }
      let proposal = try await PersonalKnowledgeReconciler(modelClient: modelClient).teachFromReader(
        reason: reason, contentTitle: row.title, publisher: row.publisher, summary: row.summary,
        existingClaims: claims, provider: provider
      )
      guard let proposal else {
        errorMessage = "Cockpit couldn't identify a new durable understanding from that teaching."
        return
      }
      teachingStage = .proposal(proposal)
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func saveTeachingButtonTapped() async {
    guard case let .proposal(proposal) = teachingStage, let row else { return }
    let reason = teachingReason
    let teachingID = uuid()
    let claimID = uuid()
    let date = now
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.applyReaderTeaching(
          proposal, reason: reason, contentPieceID: row.id, teachingID: teachingID, claimID: claimID,
          at: date, in: db
        )
      }
      try await $readerTeaching.load()
      cancelTeaching()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func run(_ operation: @escaping @Sendable (Database) throws -> Void) async {
    do {
      try await database.write { db in try operation(db) }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

public enum ReaderTeachingStage: Identifiable, Equatable, Sendable {
  case reason
  case proposal(PersonalKnowledgeProposal)

  public var id: String {
    switch self {
    case .reason: "reader-teaching-reason"
    case let .proposal(proposal): "reader-teaching-proposal-\(proposal.id.uuidString)"
    }
  }
}
