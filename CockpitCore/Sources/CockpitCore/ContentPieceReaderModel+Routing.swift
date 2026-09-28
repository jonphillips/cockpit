import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  public var currentSender: String? { row?.senderHeader }
  public var currentSenderKey: String? { row?.senderKey }
  public var currentTreatment: EmailTreatment? { row?.emailTreatment }
  public var isReplyAvailable: Bool {
    isGmailSource && (resolvedContentRole == .forYou || resolvedContentRole == .transactional)
  }
  public var resolvedRoutingLocator: String? { routingResolution?.locator }
  public var currentRoutingRule: ContentRoleRoutingRule? { routingResolution?.rule }
  public var resolvedContentRole: ContentRole? { routingResolution?.role }

  /// Loads the Reader's current route and the correction status for its exact sender.
  public func loadRoutingResolution() async {
    guard let id = row?.id else {
      routingResolution = nil
      isTransactionalCorrection = false
      return
    }
    do {
      routingResolution = try await database.read { db in
        try CurationRouting.resolution(for: id, in: db)
      }
      let sender = row?.senderHeader
      isTransactionalCorrection = try await database.read { db in
        guard let senderKey = GmailHeaderParser.senderKey(from: sender) else { return false }
        return try EmailSenderTreatmentOverride.find(senderKey).fetchOne(db)?.treatment == .transactional
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

  /// Moves the current email by its canonical locator, or explicitly corrects its sender.
  public func moveToSection(to role: ContentRole) async {
    guard let id = row?.id else { return }
    guard role != .transactional else { return }
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

  public func correctSenderAsTransactional() async {
    guard let sender = row?.senderHeader else {
      errorMessage = "This message has no sender address to correct."
      return
    }
    do {
      try await database.write { db in
        _ = try EmailTreatmentOperations.setSenderOverride(.transactional, for: sender, in: db)
      }
      try await $content.load()
      await loadRoutingResolution()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func removeTransactionalCorrection() async {
    guard let sender = row?.senderHeader else { return }
    do {
      try await database.write { db in
        _ = try EmailTreatmentOperations.removeSenderOverride(for: sender, in: db)
      }
      try await $content.load()
      await loadRoutingResolution()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
