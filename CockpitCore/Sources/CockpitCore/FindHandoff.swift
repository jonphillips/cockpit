import Dependencies
import Foundation
import SQLiteData

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
  }
}

@Table("pendingFindReferrals")
public struct PendingFindReferral: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let pendingFindID: PendingFind.ID
  public let sentAt: Date
  public var resolvedAt: Date?
  public var rawOutcomeSet: String?

  public init(
    id: UUID, pendingFindID: PendingFind.ID, sentAt: Date, resolvedAt: Date? = nil,
    rawOutcomeSet: String? = nil
  ) {
    self.id = id
    self.pendingFindID = pendingFindID
    self.sentAt = sentAt
    self.resolvedAt = resolvedAt
    self.rawOutcomeSet = rawOutcomeSet
  }
}

public enum FindReferralHandoffError: LocalizedError, Equatable, Sendable {
  case appGroupUnavailable
  case readableBodyUnavailable
  case yesChefUnavailable

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable: "Cockpit could not access the Yes Chef handoff mailbox."
    case .readableBodyUnavailable: "Cockpit does not hold readable content to send for this Find."
    case .yesChefUnavailable: "Yes Chef isn't available. The Find is still confirmed and can be sent again."
    }
  }
}

public struct FindReferralHandoffClient: Sendable {
  public var writeReferral: @Sendable (FindReferralMessage) async throws -> Void
  public var deleteReferral: @Sendable (UUID) async throws -> Void
  public var openReferral: @Sendable (UUID) async -> Bool

  public init(
    writeReferral: @escaping @Sendable (FindReferralMessage) async throws -> Void,
    deleteReferral: @escaping @Sendable (UUID) async throws -> Void,
    openReferral: @escaping @Sendable (UUID) async -> Bool
  ) {
    self.writeReferral = writeReferral
    self.deleteReferral = deleteReferral
    self.openReferral = openReferral
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
