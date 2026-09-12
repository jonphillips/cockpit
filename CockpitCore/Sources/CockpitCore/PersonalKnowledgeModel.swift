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
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Fetch(PersonalKnowledgeRequest()) public var knowledge = .init()

  public var directTeaching = PersonalKnowledgeDraft()
  public var importText = ""
  public var proposals: [PersonalKnowledgeProposal] = []
  public var selectedProposalIDs: Set<PersonalKnowledgeProposal.ID> = []
  public var errorMessage: String?

  public init() {}

  public var claims: [PersonalKnowledgeRequest.Row] { knowledge.rows }

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
    do {
      let reconciler = PersonalKnowledgeReconciler(modelClient: modelClient)
      let proposals = try await reconciler.reconcile(importText: text, existingClaims: claims.map(\.asClaim))
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
