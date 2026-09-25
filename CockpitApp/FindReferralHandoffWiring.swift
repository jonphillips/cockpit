import CockpitCore
import Foundation
import UIKit

enum FindReferralHandoffWiring {
  static let appGroupIdentifier = "group.com.jonphillips.cockpit-yeschef"

  static let liveClient = FindReferralHandoffClient(
    writeReferral: writeReferral,
    deleteReferral: deleteReferral,
    openReferral: { await openReferral($0) }
  )

  private static func writeReferral(_ message: FindReferralMessage) async throws {
    let directory = try mailboxDirectory("find-referrals")
    let destination = directory.appending(path: "\(message.referralID.uuidString.lowercased()).json")
    let temporary = directory.appending(path: ".\(message.referralID.uuidString.lowercased()).tmp")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(message).write(to: temporary)
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: temporary, to: destination)
  }

  private static func deleteReferral(_ referralID: UUID) async throws {
    let url = try mailboxDirectory("find-referrals")
      .appending(path: "\(referralID.uuidString.lowercased()).json")
    try? FileManager.default.removeItem(at: url)
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

  private static func mailboxDirectory(_ name: String) throws -> URL {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else { throw FindReferralHandoffError.appGroupUnavailable }
    let directory = container.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
