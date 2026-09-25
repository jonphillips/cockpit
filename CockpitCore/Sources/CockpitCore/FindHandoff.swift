import Dependencies
import Foundation
import os
import SQLiteData

enum FindHandoffLog {
  private static let logger = Logger(subsystem: "com.jonphillips.cockpit", category: "FindHandoff")

  static func record(_ message: String) {
    logger.warning("\(message, privacy: .public)")
  }
}

public enum RecipeCandidateKind {
  public static func matches(_ kind: String) -> Bool {
    kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "recipe"
  }
}

extension CockpitMigrations {
  static func registerFindHandoff(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 Gate 5 S-c1 Find referral log") { db in
      try #sql(
        """
        CREATE TABLE "pendingFindReferrals" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "pendingFindID" TEXT NOT NULL,
          "sentAt" TEXT NOT NULL,
          "resolvedAt" TEXT,
          "rawOutcomeSet" TEXT
        ) STRICT
        """
      ).execute(db)
      try #sql(
        "CREATE INDEX \"index_pendingFindReferrals_on_pendingFindID\" ON \"pendingFindReferrals\" (\"pendingFindID\")"
      ).execute(db)
    }
    migrator.registerMigration("M6 S-c3 Find referral hint source") { db in
      try #sql(
        "ALTER TABLE \"pendingFindReferrals\" ADD COLUMN \"hintSource\" TEXT NOT NULL DEFAULT 'extracted' CHECK (\"hintSource\" IN ('extracted', 'jonDeclared'))"
      ).execute(db)
    }
  }
}

public enum FindHintSource: String, Codable, QueryBindable, Sendable {
  case extracted
  case jonDeclared
}

@Table("pendingFindReferrals")
public struct PendingFindReferral: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let pendingFindID: PendingFind.ID
  public let sentAt: Date
  public var hintSource: FindHintSource
  public var resolvedAt: Date?
  public var rawOutcomeSet: String?

  public init(
    id: UUID, pendingFindID: PendingFind.ID, sentAt: Date,
    hintSource: FindHintSource = .extracted, resolvedAt: Date? = nil,
    rawOutcomeSet: String? = nil
  ) {
    self.id = id
    self.pendingFindID = pendingFindID
    self.sentAt = sentAt
    self.hintSource = hintSource
    self.resolvedAt = resolvedAt
    self.rawOutcomeSet = rawOutcomeSet
  }
}

public enum FindReferralHandoffError: LocalizedError, Equatable, Sendable {
  case appGroupUnavailable
  case readableBodyUnavailable
  case yesChefUnavailable
  case referralNoLongerPending

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable: "Cockpit could not access the Yes Chef handoff mailbox."
    case .readableBodyUnavailable: "Cockpit does not hold readable content to send for this Find."
    case .yesChefUnavailable: "Yes Chef isn't available. The Find is still confirmed and can be sent again."
    case .referralNoLongerPending: "This referral is no longer waiting for a Yes Chef response."
    }
  }
}

public struct FindReferralHandoffClient: Sendable {
  public var writeReferral: @Sendable (FindReferralMessage) async throws -> Void
  public var deleteReferral: @Sendable (UUID) async throws -> Bool
  public var openReferral: @Sendable (UUID) async -> Bool
  public var listVerdicts: @Sendable () async throws -> FindVerdictMailboxScan
  public var deleteVerdict: @Sendable (UUID) async throws -> Bool
  public var unconsumedReferralIDs: @Sendable () async throws -> Set<UUID>

  public init(
    writeReferral: @escaping @Sendable (FindReferralMessage) async throws -> Void,
    deleteReferral: @escaping @Sendable (UUID) async throws -> Bool,
    openReferral: @escaping @Sendable (UUID) async -> Bool,
    listVerdicts: @escaping @Sendable () async throws -> FindVerdictMailboxScan = { .init() },
    deleteVerdict: @escaping @Sendable (UUID) async throws -> Bool = { _ in false },
    unconsumedReferralIDs: @escaping @Sendable () async throws -> Set<UUID> = { [] }
  ) {
    self.writeReferral = writeReferral
    self.deleteReferral = deleteReferral
    self.openReferral = openReferral
    self.listVerdicts = listVerdicts
    self.deleteVerdict = deleteVerdict
    self.unconsumedReferralIDs = unconsumedReferralIDs
  }
}

extension FindReferralHandoffClient: DependencyKey {
  public static let liveValue = FindReferralHandoffClient(
    writeReferral: { _ in throw FindReferralHandoffError.appGroupUnavailable },
    deleteReferral: { _ in throw FindReferralHandoffError.appGroupUnavailable },
    openReferral: { _ in false }
  )
  public static let testValue = liveValue
}

extension DependencyValues {
  public var findReferralHandoffClient: FindReferralHandoffClient {
    get { self[FindReferralHandoffClient.self] }
    set { self[FindReferralHandoffClient.self] = newValue }
  }
}
