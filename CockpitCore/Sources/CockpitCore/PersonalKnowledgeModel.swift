import Dependencies
import Foundation
import LLMClientKit
import Observation
import SQLiteData

public struct PersonalKnowledgeDraft: Equatable, Sendable {
  public var kind: PersonalKnowledgeKind
  public var claim: String
  public var scope: String

  public init(kind: PersonalKnowledgeKind = .fact, claim: String = "", scope: String = "") {
    self.kind = kind
    self.claim = claim
    self.scope = scope
  }
}

public enum PersonalKnowledgeProposalReview: Equatable, Sendable {
  case importText
  case accumulatedClaims

  public var title: String {
    switch self {
    case .importText: "Import Review"
    case .accumulatedClaims: "Consolidation Review"
    }
  }
}

@MainActor
@Observable
public final class PersonalKnowledgeModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Dependency(\.apiKeyStore) private var apiKeyStore
  @ObservationIgnored @Dependency(\.frontierPreferenceStore) private var preferenceStore
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Fetch(PersonalKnowledgeRequest()) public var knowledge = .init()
  @ObservationIgnored @Fetch(PersonalKnowledgeHypothesisRequest()) public var hypothesisCandidates = .init()

  public var directTeaching = PersonalKnowledgeDraft()
  public var correctionDraft = PersonalKnowledgeDraft()
  public var correctingClaimID: PersonalKnowledgeClaim.ID?
  public var importText = ""
  public var proposals: [PersonalKnowledgeProposal] = []
  public var selectedProposalIDs: Set<PersonalKnowledgeProposal.ID> = []
  public var proposalReview: PersonalKnowledgeProposalReview?
  public var errorMessage: String?
  public var isReviewingImport = false
  public var isReviewingConsolidation = false
  public var isConfirmingHypothesis = false
  /// One transient inline question, deliberately not a notice queue. It is populated from the
  /// explicit-action projection only when the You surface asks for it.
  public var hypothesis: PersonalKnowledgeHypothesisRequest.Candidate?
  /// A human-readable name of the model the current/last import review actually routed to,
  /// so the UI never misstates on-device vs. a frontier provider.
  public var importProviderDescription: String?

  public init() {}

  public var claims: [PersonalKnowledgeRequest.Row] { knowledge.rows }

  /// The claims to show as present understanding: superseded rows are retained for history
  /// (and reconciliation) but are not current, so they never render as "Current Understanding."
  public var currentClaims: [PersonalKnowledgeRequest.Row] {
    knowledge.rows.filter { $0.status == .current }
  }

  public var historicalClaims: [PersonalKnowledgeRequest.Row] {
    knowledge.rows.filter { $0.status != .current }
  }

  public var isCorrecting: Bool {
    get { correctingClaimID != nil }
    set {
      if !newValue { cancelCorrectionButtonTapped() }
    }
  }

  public var canReviewConsolidation: Bool { currentClaims.count > 1 }

  /// The frontier provider a Jon Brain import should use: the user's chosen provider when
  /// they have a key for it, otherwise the first configured provider (Anthropic-first),
  /// otherwise nil — which lets the reconciler fall back to `.frontierPreferred` and, with
  /// no key at all, degrade to the on-device model.
  nonisolated static func resolveImportProvider(
    preferred: FrontierProvider?,
    isConfigured: (FrontierProvider) -> Bool
  ) -> FrontierProvider? {
    if let preferred, isConfigured(preferred) { return preferred }
    return FrontierProvider.allCases.first(where: isConfigured)
  }

  public func teachButtonTapped() async {
    let draft = directTeaching
    let id = uuid()
    let date = now
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.teach(
          id: id, kind: draft.kind, claim: draft.claim, scope: draft.scope, at: date, in: db
        )
      }
      directTeaching = PersonalKnowledgeDraft()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func reviewImportButtonTapped() async {
    let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      errorMessage = PersonalKnowledgeOperations.Failure.emptyClaim.localizedDescription
      return
    }
    isReviewingImport = true
    defer { isReviewingImport = false }
    do {
      let provider = Self.resolveImportProvider(
        preferred: preferenceStore.preferred(),
        isConfigured: { apiKeyStore.key($0) != nil }
      )
      importProviderDescription = provider?.displayName ?? "the on-device model"
      let reconciler = PersonalKnowledgeReconciler(modelClient: modelClient)
      let proposals = try await reconciler.reconcile(
        importText: text, existingClaims: claims.map(\.asClaim), provider: provider
      )
      self.proposals = proposals
      selectedProposalIDs = Set(proposals.filter { !$0.requiresConfirmation }.map(\.id))
      proposalReview = .importText
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func importSelectedButtonTapped() async {
    let selected = proposals.filter { selectedProposalIDs.contains($0.id) }
    guard !selected.isEmpty else { return }
    let ids = selected.map { _ in uuid() }
    let date = now
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.apply(selected, at: date, ids: ids, in: db)
      }
      if proposalReview == .importText { importText = "" }
      proposals = []
      selectedProposalIDs = []
      proposalReview = nil
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

extension PersonalKnowledgeModel {
  public func correctButtonTapped(_ claim: PersonalKnowledgeRequest.Row) {
    guard claim.status == .current else { return }
    correctingClaimID = claim.id
    correctionDraft = PersonalKnowledgeDraft(
      kind: claim.kind, claim: claim.claim, scope: claim.scope ?? ""
    )
  }

  public func cancelCorrectionButtonTapped() {
    correctingClaimID = nil
    correctionDraft = PersonalKnowledgeDraft()
  }

  public func saveCorrectionButtonTapped() async {
    guard let correctingClaimID else { return }
    let draft = correctionDraft
    let id = uuid()
    let date = now
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.correct(
          correctingClaimID, with: draft, id: id, at: date, in: db
        )
      }
      cancelCorrectionButtonTapped()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func retireButtonTapped(_ claim: PersonalKnowledgeRequest.Row) async {
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.retire(claim.id, in: db)
      }
      if correctingClaimID == claim.id { cancelCorrectionButtonTapped() }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func reviewConsolidationButtonTapped() async {
    guard canReviewConsolidation else { return }
    isReviewingConsolidation = true
    defer { isReviewingConsolidation = false }
    do {
      let provider = Self.resolveImportProvider(
        preferred: preferenceStore.preferred(),
        isConfigured: { apiKeyStore.key($0) != nil }
      )
      importProviderDescription = provider?.displayName ?? "the on-device model"
      let reconciler = PersonalKnowledgeReconciler(modelClient: modelClient)
      let proposals = try await reconciler.consolidate(
        existingClaims: currentClaims.map(\.asClaim), provider: provider
      )
      self.proposals = proposals
      selectedProposalIDs = Set(proposals.filter { !$0.requiresConfirmation }.map(\.id))
      proposalReview = .accumulatedClaims
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

extension PersonalKnowledgeModel {
  public func loadHypothesis() async {
    do {
      try await $hypothesisCandidates.load()
      hypothesis = hypothesisCandidates.candidates.first
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// A dismissal only removes the currently rendered question. It writes neither a claim nor an
  /// observation, which keeps ignored recurrence out of durable Personal Knowledge.
  public func dismissHypothesisButtonTapped() {
    hypothesis = nil
  }

  public func confirmHypothesisButtonTapped() async {
    guard let hypothesis, !isConfirmingHypothesis else { return }
    isConfirmingHypothesis = true
    defer { isConfirmingHypothesis = false }
    let id = uuid()
    let date = now
    do {
      try await database.write { db in
        try PersonalKnowledgeOperations.confirmHypothesis(
          subject: hypothesis.subject, id: id, at: date, in: db
        )
      }
      self.hypothesis = nil
      try await $knowledge.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
