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

  public var directTeaching = PersonalKnowledgeDraft()
  public var importText = ""
  public var proposals: [PersonalKnowledgeProposal] = []
  public var selectedProposalIDs: Set<PersonalKnowledgeProposal.ID> = []
  public var errorMessage: String?
  public var isReviewingImport = false
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
      importText = ""
      proposals = []
      selectedProposalIDs = []
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
