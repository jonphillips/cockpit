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
  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Dependency(\.apiKeyStore) private var apiKeyStore
  @ObservationIgnored @Dependency(\.frontierPreferenceStore) private var preferenceStore
  @ObservationIgnored @Dependency(\.emailZoomPreferenceStore) var emailZoomPreferenceStore
  @ObservationIgnored @Dependency(\.gmailDispositionClient) var dispositionClient
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Fetch public var content = ContentPieceReaderRequest.Value()
  @ObservationIgnored @Fetch public var pendingFindContent = PendingFindForContentPieceRequest.Value()
  @ObservationIgnored @Fetch public var readerTeaching = ReaderTeachingClaimRequest.Value()
  @ObservationIgnored @Fetch public var matchedPersonalKnowledge = MatchedPersonalKnowledgeClaimRequest.Value()
  public let contentPieceID: ContentPiece.ID
  public private(set) var routingResolution: CurationRoutingResolution?
  public var errorMessage: String?
  public var teachingReason = ""
  public var teachingStage: ReaderTeachingStage?
  public var isReviewingTeaching = false
  public var teachingProviderDescription: String?
  public internal(set) var emailSeriesKey: String?
  public internal(set) var emailZoomAdjustmentStep = 0
  public internal(set) var isEmailZoomPreferenceLoaded = false

  public init(
    contentPieceID: ContentPiece.ID,
    matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID? = nil
  ) {
    self.contentPieceID = contentPieceID
    _content = Fetch(wrappedValue: .init(), ContentPieceReaderRequest(contentPieceID: contentPieceID))
    _pendingFindContent = Fetch(
      wrappedValue: .init(), PendingFindForContentPieceRequest(contentPieceID: contentPieceID))
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

  public var bodyPresentation: ReaderBodyPresentation { readerBodyPresentation(for: row) }

  /// In V1 an email ContentPiece is a Gmail message, so the Reader offers a source disposition only
  /// for these. Other transports have no provider disposition yet.
  public var isGmailSource: Bool { row?.kind == .email }

  /// The Reader collects teaching inline. Submitting asks the model for a narrow proposal, but the
  /// proposal remains non-canonical until `saveTeachingButtonTapped` receives explicit confirmation.
  public func submitTeachingReason() async {
    guard let row else { return }
    let reason = teachingReason.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !reason.isEmpty else { return }

    teachingReason = reason
    teachingStage = nil
    errorMessage = nil
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

  public func cancelTeaching() {
    teachingStage = nil
    teachingReason = ""
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

  func run(_ operation: @escaping @Sendable (Database) throws -> Void) async {
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

extension ContentPieceReaderModel {
  public var currentSender: String? { row?.sender }
  public var currentTreatment: EmailTreatment? { row?.emailTreatment }
  public var isReplyAvailable: Bool {
    isGmailSource && (resolvedContentRole == .forYou || resolvedContentRole == .transactional)
  }
  public var resolvedRoutingLocator: String? { routingResolution?.locator }
  public var currentRoutingRule: ContentRoleRoutingRule? { routingResolution?.rule }
  public var resolvedContentRole: ContentRole? { routingResolution?.role }

  /// Loads the Reader's current content-role locator and rule through CurationRouting's canonical
  /// per-piece resolution path. This keeps route edits aligned with the surface snapshot.
  public func loadRoutingResolution() async {
    guard let id = row?.id else {
      routingResolution = nil
      return
    }
    do {
      routingResolution = try await database.read { db in
        try CurationRouting.resolution(for: id, in: db)
      }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Persists an explicit sub-feed route using the same operation as Settings.
  public func saveRoutingRule(_ rule: ContentRoleRoutingRule) async {
    do {
      try await database.write { db in
        try StreamOperations.saveRoutingRule(rule, in: db)
      }
      await loadRoutingResolution()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Moves the current email by its canonical locator. Eligible missing treatment details are
  /// extracted in a detached task after the route and Reader projection have been saved.
  public func moveToSection(to role: ContentRole) async {
    guard role != .transactional, let id = row?.id else { return }
    do {
      let locator = try await database.write { db -> String? in
        let resolution = try CurationRouting.resolution(for: id, in: db)
        guard resolution.role != .transactional, let locator = resolution.locator else { return nil }
        try StreamOperations.saveRoutingRule(
          ContentRoleRoutingRule(locator: locator, role: role, isFollowed: true, isMuted: false),
          in: db)
        return locator
      }
      guard let locator else {
        errorMessage = "This message has no routable locator."
        return
      }
      await loadRoutingResolution()
      try await $content.load()
      errorMessage = nil
      guard role == .offers else { return }
      let processor = EmailTreatmentProcessor(modelClient: modelClient)
      let database = database
      Task { [weak self] in
        _ = try? await Task.detached(priority: .utility) {
          try await processor.processUnextractedPieces(for: locator, in: database)
        }.value
        try? await self?.$content.load()
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

extension ContentPieceReaderModel {
  /// Archives the Gmail source of the piece being read, behind the disposition barrier.
  public func archiveSource() async { await applyDisposition(.archive) }

  /// Trashes the Gmail source of the piece being read; reversible via `undoDisposition`.
  public func trashSource() async { await applyDisposition(.trash) }

  /// Reverses the current disposition of the piece being read, if any.
  public func undoDisposition() async {
    guard let id = row?.id else { return }
    do {
      guard let entry = try await database.read({ db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: id, in: db)
      }) else { return }
      try await dispositionService.undo(entry, in: database)
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition) async {
    guard let id = row?.id else { return }
    do {
      _ = try await dispositionService.apply(disposition, toContentPieceID: id, in: database)
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var dispositionService: GmailDispositionService {
    let date = now
    return GmailDispositionService(client: dispositionClient, now: { date })
  }
}

public enum ReaderTeachingStage: Identifiable, Equatable, Sendable {
  case proposal(PersonalKnowledgeProposal)

  public var id: String {
    switch self {
    case let .proposal(proposal): "reader-teaching-proposal-\(proposal.id.uuidString)"
    }
  }
}
