import Foundation
import SQLiteData

public enum ReferralResolution: Equatable, Sendable {
  case applied(findID: PendingFind.ID, state: PendingFindState)
  case alreadyResolved
  case missingLog
  case missingFind
}

public struct PendingFindReferralOutcomeRecord: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey { case delivery, outcomes }

  public enum Delivery: String, Codable, Sendable {
    case openFailed
    case returnedToConfirmed
  }

  public var delivery: Delivery?
  public var outcomes: [FindReferralOutcome]?

  public init(delivery: Delivery? = nil, outcomes: [FindReferralOutcome]? = nil) {
    self.delivery = delivery
    self.outcomes = outcomes
  }

  public static func delivery(_ delivery: Delivery) -> Self { Self(delivery: delivery) }
  public static func verdict(_ outcomes: [FindReferralOutcome]) -> Self { Self(outcomes: outcomes) }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(delivery, forKey: .delivery)
    try container.encodeIfPresent(outcomes, forKey: .outcomes)
  }
}

public enum FindReferralOperations {
  public static func resolve(
    _ verdict: FindVerdictMessage, at date: Date, in db: Database
  ) throws -> ReferralResolution {
    guard let referral = try PendingFindReferral.find(verdict.referralID).fetchOne(db) else {
      return .missingLog
    }
    guard referral.resolvedAt == nil else { return .alreadyResolved }
    guard let find = try PendingFind.find(referral.pendingFindID).fetchOne(db) else {
      try updateReferral(verdict.referralID, record: .verdict(verdict.outcomes), at: date, in: db)
      return .missingFind
    }

    let state = resolutionState(for: verdict.outcomes)
    try PendingFind.find(find.id).update { $0.state = #bind(state) }.execute(db)
    try updateReferral(verdict.referralID, record: .verdict(verdict.outcomes), at: date, in: db)
    return .applied(findID: find.id, state: state)
  }

  public static func returnToConfirmed(
    referralID: UUID, at date: Date, in db: Database
  ) throws -> PendingFind.ID {
    guard let referral = try PendingFindReferral.find(referralID).fetchOne(db),
      referral.resolvedAt == nil
    else { throw FindReferralHandoffError.referralNoLongerPending }
    try PendingFind.find(referral.pendingFindID).update {
      $0.state = #bind(PendingFindState.confirmed)
    }.execute(db)
    try updateReferral(
      referralID, record: .delivery(.returnedToConfirmed), at: date, in: db
    )
    return referral.pendingFindID
  }

  public static func unresolved(in db: Database) throws -> [PendingFindReferral] {
    try PendingFindReferral.fetchAll(db).filter { $0.resolvedAt == nil }
  }

  static func encodeOutcomeRecord(_ value: PendingFindReferralOutcomeRecord) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  private static func resolutionState(for outcomes: [FindReferralOutcome]) -> PendingFindState {
    if outcomes.contains(where: { outcome in
      if case .admitted = outcome { true } else { false }
    }) {
      return .handedOff
    }
    if outcomes.contains(where: { outcome in
      if case let .declined(reason, _) = outcome {
        reason == .noRecipeFound || reason == .duplicate
      } else {
        false
      }
    }) {
      return .declined
    }
    return .confirmed
  }

  private static func updateReferral(
    _ id: UUID,
    record: PendingFindReferralOutcomeRecord,
    at date: Date,
    in db: Database
  ) throws {
    let rawOutcomeSet = try encodeOutcomeRecord(record)
    try PendingFindReferral.find(id).update {
      $0.resolvedAt = #bind(date)
      $0.rawOutcomeSet = #bind(rawOutcomeSet)
    }.execute(db)
  }
}
