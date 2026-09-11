@testable import CockpitCore
import CloudKit
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies { try $0.bootstrapDatabase() })
struct CloudSyncTests {
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.defaultSyncEngine) var engine

  @Test("D6: engine constructs, registers exactly six tables, and sends no non-Library text or Artifacts")
  func syncRegistrationAndTextExclusion() async throws {
    let memberID = UUID(-1)
    let localID = UUID(-2)
    let largeText = String(repeating: "読", count: 400_000)
    try await database.write { db in
      try InterestArea.insert {
        InterestArea.Draft(id: UUID(-1), name: "Area", guidance: "", sortOrder: 0)
      }.execute(db)
      try CockpitCore.Stream.insert {
        CockpitCore.Stream.Draft(CockpitCore.Stream(
          id: UUID(-1), name: "Stream", publisher: "Publisher", transport: .rss,
          locator: "https://example.com/feed"
        ))
      }.execute(db)
      try StreamPollState.insert {
        StreamPollState.Draft(
          streamID: UUID(-1),
          health: .failed,
          lastReceivedAt: .distantPast,
          consecutiveFailureCount: 2,
          lastFailureDescription: "Local-only failure"
        )
      }.execute(db)
      for id in [memberID, localID] {
        try ContentPiece.insert {
          ContentPiece.Draft(id: id, kind: .article, title: "Piece", publisher: "Publisher", createdAt: .distantPast)
        }.execute(db)
        try Artifact.insert {
          Artifact.Draft(id: id == memberID ? UUID(-10) : UUID(-20), transport: .rss, acquiredAt: .distantPast, rawSourceText: "RAW SECRET", contentPieceID: id)
        }.execute(db)
      }
      try NormalizedTextOperations.store(largeText, for: memberID, in: db)
      try NormalizedTextOperations.store("LOCAL ONLY SECRET", for: localID, in: db)
      try DestinationOperations.saveForLater(localID, at: .distantPast, in: db)
      try DestinationOperations.addToLibrary(memberID, at: .distantPast, in: db)
    }
    try await engine.start()
    try await engine.sendChanges()
    let records = try await database.read { db in
      try SyncMetadata.fetchAll(db)
    }
    expectNoDifference(Set(records.map(\.recordType)), Set([
      "interestAreas", "streams", "contentPieces", "laterMemberships", "libraryMemberships", "libraryNormalizedTexts"
    ]))
    #expect(!records.map(\.recordType).contains("streamPollStates"))
    let sent = records.compactMap(\._lastKnownServerRecordAllFields)
    #expect(!sent.isEmpty)
    let textRecords = sent.filter { $0.recordType == "libraryNormalizedTexts" }
    expectNoDifference(textRecords.count, 1)
    let textRecord = try #require(textRecords.first)
    #expect(textRecord["utf8"] is CKAsset)
    for record in sent {
      #expect(!record.allKeys().contains("normalizedText"))
      #expect(!record.allKeys().contains("rawSourceText"))
      #expect(!record.encryptedValues.allKeys().contains("normalizedText"))
      #expect(!record.encryptedValues.allKeys().contains("rawSourceText"))
    }
    let actualBody = try await database.read { db in
      try LibraryNormalizedText.find(memberID).fetchOne(db)?.utf8
    }
    expectNoDifference(actualBody, Data(largeText.utf8))

    try await database.write { db in
      try DestinationOperations.removeFromLibrary(memberID, in: db)
    }
    try await engine.sendChanges()
    let removedRecord = try await database.read { db in
      try SyncMetadata.find(LibraryNormalizedText(contentPieceID: memberID).syncMetadataID)
        .fetchOne(db)?._lastKnownServerRecordAllFields
    }
    let sentRemoval = try #require(removedRecord)
    #expect(sentRemoval["utf8"] == nil)
    engine.stop()
  }
}
