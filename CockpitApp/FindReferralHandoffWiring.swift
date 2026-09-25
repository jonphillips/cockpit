import CockpitCore
import Foundation
import OSLog
import UIKit

enum FindReferralHandoffWiring {
  static let appGroupIdentifier = "group.com.jonphillips.cockpit-yeschef"
  private static let logger = Logger(subsystem: "com.jonphillips.cockpit", category: "FindHandoff")

  static let liveClient = FindReferralHandoffClient(
    writeReferral: writeReferral,
    deleteReferral: deleteReferral,
    openReferral: { await openReferral($0) },
    listVerdicts: listVerdicts,
    deleteVerdict: deleteVerdict,
    unconsumedReferralIDs: unconsumedReferralIDs
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

  private static func listVerdicts() async throws -> [FindVerdictMessage] {
    let directory = try mailboxDirectory("find-verdicts")
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey]
    )
    var verdicts: [FindVerdictMessage] = []
    for url in files where url.pathExtension == "json" {
      guard let filenameID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
        logger.warning("Discarding verdict mailbox file with an invalid name: \(url.lastPathComponent, privacy: .public)")
        try? FileManager.default.removeItem(at: url)
        continue
      }
      do {
        let verdict = try JSONDecoder().decode(FindVerdictMessage.self, from: Data(contentsOf: url))
        guard verdict.referralID == filenameID else {
          logger.error("Discarding verdict whose filename and referral ID disagree: \(url.lastPathComponent, privacy: .public)")
          try? FileManager.default.removeItem(at: url)
          continue
        }
        verdicts.append(verdict)
      } catch {
        logger.error("Discarding unreadable verdict \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        try? FileManager.default.removeItem(at: url)
      }
    }
    return verdicts
  }

  private static func deleteVerdict(_ referralID: UUID) async throws {
    let url = try mailboxDirectory("find-verdicts")
      .appending(path: "\(referralID.uuidString.lowercased()).json")
    try? FileManager.default.removeItem(at: url)
  }

  private static func unconsumedReferralIDs() async throws -> Set<UUID> {
    let directory = try mailboxDirectory("find-referrals")
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey]
    )
    return Set(files.compactMap { url in
      guard url.pathExtension == "json" else { return nil }
      return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
    })
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
