import Foundation

public struct FindVerdictMailboxScan: Equatable, Sendable {
  public var verdicts: [FindVerdictMessage]
  public var unreadableReferralIDs: Set<UUID>

  public init(verdicts: [FindVerdictMessage] = [], unreadableReferralIDs: Set<UUID> = []) {
    self.verdicts = verdicts
    self.unreadableReferralIDs = unreadableReferralIDs
  }
}

/// File-backed transport for the pair-scoped App Group mailbox. The base directory is supplied by
/// the app so this stays testable without depending on UIKit or App Group APIs.
public struct FindReferralMailbox: Sendable {
  private let baseDirectory: URL

  public init(baseDirectory: URL) {
    self.baseDirectory = baseDirectory
  }

  public func writeReferral(_ message: FindReferralMessage) throws {
    let directory = try mailboxDirectory("find-referrals")
    let name = message.referralID.uuidString.lowercased()
    let destination = directory.appending(path: "\(name).json")
    let temporary = directory.appending(path: ".\(name).tmp")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(message).write(to: temporary)
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: temporary, to: destination)
  }

  @discardableResult
  public func deleteReferral(_ referralID: UUID) throws -> Bool {
    try delete(referralID, in: "find-referrals")
  }

  public func listVerdicts() throws -> FindVerdictMailboxScan {
    let directory = try mailboxDirectory("find-verdicts")
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
    )
    var scan = FindVerdictMailboxScan()
    for url in files where url.pathExtension == "json" {
      guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
      guard let filenameID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
        // The folder is shared, so unknown names may belong to another writer or an in-progress file.
        continue
      }
      do {
        let verdict = try JSONDecoder().decode(FindVerdictMessage.self, from: Data(contentsOf: url))
        guard verdict.referralID == filenameID else {
          scan.unreadableReferralIDs.insert(filenameID)
          continue
        }
        scan.verdicts.append(verdict)
      } catch {
        // Preserve the message for a future Cockpit build that may understand its wire version.
        scan.unreadableReferralIDs.insert(filenameID)
      }
    }
    return scan
  }

  @discardableResult
  public func deleteVerdict(_ referralID: UUID) throws -> Bool {
    try delete(referralID, in: "find-verdicts")
  }

  public func unconsumedReferralIDs() throws -> Set<UUID> {
    let directory = try mailboxDirectory("find-referrals")
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
    )
    return Set(files.compactMap { url in
      guard url.pathExtension == "json" else { return nil }
      guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
      return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
    })
  }

  private func delete(_ id: UUID, in name: String) throws -> Bool {
    let url = try mailboxDirectory(name).appending(path: "\(id.uuidString.lowercased()).json")
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    do {
      try FileManager.default.removeItem(at: url)
      return true
    } catch let error as CocoaError where error.code == .fileNoSuchFile {
      return false
    }
  }

  private func mailboxDirectory(_ name: String) throws -> URL {
    let directory = baseDirectory.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
