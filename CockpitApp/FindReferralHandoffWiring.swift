import CockpitCore
import Foundation
import UIKit

enum FindReferralHandoffWiring {
  static let appGroupIdentifier = "group.com.jonphillips.cockpit-yeschef"

  static let liveClient = FindReferralHandoffClient(
    writeReferral: writeReferral,
    deleteReferral: deleteReferral,
    openReferral: { await openReferral($0) },
    listVerdicts: listVerdicts,
    deleteVerdict: deleteVerdict,
    unconsumedReferralIDs: unconsumedReferralIDs
  )

  private static func writeReferral(_ message: FindReferralMessage) async throws {
    try mailbox().writeReferral(message)
  }

  private static func deleteReferral(_ referralID: UUID) async throws -> Bool {
    try mailbox().deleteReferral(referralID)
  }

  private static func listVerdicts() async throws -> FindVerdictMailboxScan {
    try mailbox().listVerdicts()
  }

  private static func deleteVerdict(_ referralID: UUID) async throws -> Bool {
    try mailbox().deleteVerdict(referralID)
  }

  private static func unconsumedReferralIDs() async throws -> Set<UUID> {
    try mailbox().unconsumedReferralIDs()
  }

  @MainActor
  private static func openReferral(_ referralID: UUID) async -> Bool {
    var components = URLComponents()
    components.scheme = "yeschef"
    components.host = "find-referral"
    components.queryItems = [URLQueryItem(name: "id", value: referralID.uuidString.lowercased())]
    guard let url = components.url else { return false }
    return await withCheckedContinuation { continuation in
      UIApplication.shared.open(url, options: [:]) { didOpen in
        continuation.resume(returning: didOpen)
      }
    }
  }

  private static func mailbox() throws -> FindReferralMailbox {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else { throw FindReferralHandoffError.appGroupUnavailable }
    return FindReferralMailbox(baseDirectory: container)
  }
}
