import CockpitCore
import Foundation
import Testing

@Suite
struct FindReferralMailboxTests {
  @Test("Verdict scan reads JSON, skips hidden files, and preserves unknown or unreadable files")
  func scanOnlyConsumesRecognizedJSON() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: "FindReferralMailboxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    let mailbox = FindReferralMailbox(baseDirectory: root)
    let directory = root.appending(path: "find-verdicts", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let validID = UUID()
    let unreadableID = UUID()
    let hiddenID = UUID()
    let verdict = FindVerdictMessage(referralID: validID, outcomes: [.declined(reason: .dismissed)])
    let encoder = JSONEncoder()
    try encoder.encode(verdict).write(to: directory.appending(path: "\(validID.uuidString.lowercased()).json"))
    try Data("{invalid".utf8).write(
      to: directory.appending(path: "\(unreadableID.uuidString.lowercased()).json")
    )
    try Data("{\"version\":2}".utf8).write(
      to: directory.appending(path: "\(hiddenID.uuidString.lowercased()).json")
    )
    let unknownName = directory.appending(path: "in-progress.json")
    try Data("temporary".utf8).write(to: unknownName)
    let hiddenFile = directory.appending(path: ".\(UUID().uuidString.lowercased()).json")
    try encoder.encode(FindVerdictMessage(referralID: hiddenID, outcomes: [])).write(to: hiddenFile)

    let scan = try mailbox.listVerdicts()

    #expect(scan.verdicts == [verdict])
    #expect(scan.unreadableReferralIDs == [unreadableID, hiddenID])
    #expect(FileManager.default.fileExists(atPath: unknownName.path))
    #expect(FileManager.default.fileExists(atPath: directory.appending(path: "\(unreadableID.uuidString.lowercased()).json").path))
    #expect(FileManager.default.fileExists(atPath: directory.appending(path: "\(hiddenID.uuidString.lowercased()).json").path))
    #expect(!scan.verdicts.contains { $0.referralID == hiddenID })
  }

  @Test("Deleting a referral reports whether the message was still queued")
  func deleteReferralReportsPresence() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: "FindReferralMailboxDeleteTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let mailbox = FindReferralMailbox(baseDirectory: root)
    let referralID = UUID()
    let provenance = FindReferralProvenance(
      sender: "Cockpit", publisher: "Publisher", arrivalDate: Date(timeIntervalSince1970: 1),
      seriesID: nil, contentPieceToken: "token", note: nil, hints: [:]
    )
    let message = FindReferralMessage(
      referralID: referralID, rawText: "Recipe", provenance: provenance
    )
    try mailbox.writeReferral(message)

    #expect(try mailbox.deleteReferral(referralID))
    #expect(try !mailbox.deleteReferral(referralID))
  }
}
