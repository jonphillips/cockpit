@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 10_000)
    try $0.bootstrapDatabase()
  }
)
struct Gate4DispositionSeparationTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Archive preserves a followed Gmail Stream and its Essential Edition state")
  func archivePreservesStreamAndEditionState() async throws {
    try await assertDispositionPreservesStreamAndEditionState(
      .archive, messageID: "gate4-s-c-archive", in: database)
  }

  @Test("Trash preserves a followed Gmail Stream and its Essential Edition state")
  func trashPreservesStreamAndEditionState() async throws {
    try await assertDispositionPreservesStreamAndEditionState(
      .trash, messageID: "gate4-s-c-trash", in: database)
  }

  @Test("Substantive-primary classification cannot change followed Gmail Stream routing")
  func substantivePrimaryDoesNotRouteGmailStreamContent() async throws {
    let fixture = try await seedRoutingFixture(in: database)

    let snapshot = try await database.read { db in
      try CurationRouting.snapshot(in: db)
    }

    expectNoDifference(
      snapshot.followedGmailStreamContentPieceIDs, [fixture.0, fixture.1]
    )
    expectNoDifference(snapshot.todayTriageGmailContentPieceIDs, [])
    #expect(snapshot.editionExcludedContentPieceIDs.contains(fixture.0))
    #expect(snapshot.editionExcludedContentPieceIDs.contains(fixture.1))
  }
}

private struct FixtureState: Equatable, Sendable {
  let stream: CockpitCore.Stream
  let artifact: Artifact
  let piece: ContentPiece
  let edition: Edition
  let entry: EditionEntry
  let essentialPieceIDs: Set<ContentPiece.ID>
}

private struct Fixture {
  let streamID: CockpitCore.Stream.ID
  let pieceID: ContentPiece.ID
  let editionID: Edition.ID
  let entryID: EditionEntry.ID
  let providerID: String
}

private func assertDispositionPreservesStreamAndEditionState(
  _ disposition: GmailSourceDisposition,
  messageID: String,
  in database: any DatabaseWriter
) async throws {
  let fixture = try await seedFixture(messageID: messageID, in: database)
  let before = try await database.read { db in
    try state(for: fixture, in: db)
  }
  let queueBefore = try await database.read { db in
    try TodayReadingQueueRequest().fetch(db).rows.first { $0.id == fixture.pieceID }
  }
  #expect(queueBefore?.isFollowedStreamPiece == true)
  #expect(queueBefore?.editionEntryID == fixture.entryID)

  let log = CallLog()
  let service = GmailDispositionService(client: log.client, now: { .distantPast })
  let logEntry = try await service.apply(
    disposition, toContentPieceID: fixture.pieceID, in: database)

  expectNoDifference(log.calls, ["\(disposition.rawValue):\(messageID)"])
  #expect(logEntry != nil)

  let after = try await database.read { db in
    try state(for: fixture, in: db)
  }
  expectNoDifference(after, before)
  let queueAfter = try await database.read { db in
    try TodayReadingQueueRequest().fetch(db).rows.first { $0.id == fixture.pieceID }
  }
  #expect(queueAfter == queueBefore)

  // The applied source disposition is the only new state: it points at the provider Artifact and
  // does not become a ContentPiece, Stream, Edition, or Essential-state mutation.
  let storedLog = try await database.read { db in
    try GmailDispositionLogEntry.where { $0.providerID.eq(fixture.providerID) }.fetchAll(db)
  }
  expectNoDifference(storedLog.count, 1)
  expectNoDifference(storedLog.first?.operation.rawValue, disposition.rawValue)
}

private func seedRoutingFixture(
  in database: any DatabaseWriter
) async throws -> (ContentPiece.ID, ContentPiece.ID) {
  let streamID = UUID(93_001)
  let substantivePieceID = UUID(93_002)
  let accessoryPieceID = UUID(93_003)

  try await database.write { db in
    try CockpitCore.Stream.insert {
      CockpitCore.Stream.Draft(CockpitCore.Stream(
        id: streamID,
        name: "Gate 4 newsletter",
        publisher: "Publisher",
        transport: .gmail,
        locator: "gate4.example.com",
        isEssential: true
      ))
    }.execute(db)

    try insertRoutingPiece(
      id: substantivePieceID, title: "Substantive issue", isSubstantivePrimary: true, in: db)
    try insertRoutingPiece(
      id: accessoryPieceID, title: "Accessory issue", isSubstantivePrimary: false, in: db)
    for (artifactID, pieceID) in [
      (UUID(93_004), substantivePieceID),
      (UUID(93_005), accessoryPieceID),
    ] {
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: artifactID,
          streamID: streamID,
          transport: .gmail,
          providerID: "gmail:jon@example.com:message:\(artifactID.uuidString)",
          acquiredAt: .distantPast,
          contentPieceID: pieceID
        ))
      }.execute(db)
    }
  }
  return (substantivePieceID, accessoryPieceID)
}

private func insertRoutingPiece(
  id: ContentPiece.ID, title: String, isSubstantivePrimary: Bool, in db: Database
) throws {
  try ContentPiece.insert {
    ContentPiece.Draft(ContentPiece(
      id: id,
      kind: .email,
      title: title,
      publisher: "Publisher",
      isSubstantivePrimary: isSubstantivePrimary,
      emailTreatment: .newsletter,
      createdAt: .distantPast
    ))
  }.execute(db)
}

private func seedFixture(messageID: String, in database: any DatabaseWriter) async throws -> Fixture {
  let streamID = UUID(), pieceID = UUID()
  let editionID = EditionDay.editionID(for: .distantPast)
  let entryID = UUID()
  let providerID = "gmail:jon@example.com:message:\(messageID)"

  try await database.write { db in
    try insertDispositionSource(
      streamID: streamID, pieceID: pieceID, providerID: providerID, in: db)
    try insertDispositionEdition(
      editionID: editionID, entryID: entryID, pieceID: pieceID, in: db)
  }

  return Fixture(
    streamID: streamID,
    pieceID: pieceID,
    editionID: editionID,
    entryID: entryID,
    providerID: providerID
  )
}

private func insertDispositionSource(
  streamID: CockpitCore.Stream.ID,
  pieceID: ContentPiece.ID,
  providerID: String,
  in db: Database
) throws {
  try CockpitCore.Stream.insert {
    CockpitCore.Stream.Draft(CockpitCore.Stream(
      id: streamID,
      name: "Gate 4 Essential newsletter",
      publisher: "Publisher",
      transport: .gmail,
      locator: "gate4-essential.example.com",
      isEssential: true
    ))
  }.execute(db)
  try ContentPiece.insert {
    ContentPiece.Draft(ContentPiece(
      id: pieceID,
      kind: .email,
      title: "A durable newsletter issue",
      publisher: "Publisher",
      summary: "The stored summary survives source disposition.",
      isSubstantivePrimary: true,
      bodyCompleteness: .full,
      emailTreatment: .newsletter,
      createdAt: .distantPast
    ))
  }.execute(db)
  try Artifact.insert {
    Artifact.Draft(Artifact(
      id: UUID(),
      streamID: streamID,
      transport: .gmail,
      providerID: providerID,
      acquiredAt: .distantPast,
      rawSourceText: "The source body remains provenance, not the ContentPiece identity.",
      contentPieceID: pieceID
    ))
  }.execute(db)
}

private func insertDispositionEdition(
  editionID: Edition.ID, entryID: EditionEntry.ID, pieceID: ContentPiece.ID, in db: Database
) throws {
  try Edition.insert {
    Edition.Draft(Edition(
      id: editionID,
      date: EditionDay.start(of: .distantPast),
      state: .open
    ))
  }.execute(db)
  try EditionEntry.insert {
    EditionEntry.Draft(EditionEntry(
      id: entryID,
      editionID: editionID,
      contentPieceID: pieceID,
      section: .essentialBacklog,
      rank: 1,
      rationale: "Essential state is stored on the Edition entry.",
      entryState: .seen,
      firstAdmittedEditionID: editionID,
      timesCarried: EditionPolicy.essentialBacklogRelief + 1
    ))
  }.execute(db)
}

private func state(for fixture: Fixture, in db: Database) throws -> FixtureState {
  guard
    let stream = try CockpitCore.Stream.find(fixture.streamID).fetchOne(db),
    let artifact = try Artifact.where({
      $0.contentPieceID.eq(fixture.pieceID) && $0.transport.eq(StreamTransport.gmail)
    }).fetchOne(db),
    let piece = try ContentPiece.find(fixture.pieceID).fetchOne(db),
    let edition = try Edition.find(fixture.editionID).fetchOne(db),
    let entry = try EditionEntry.find(fixture.entryID).fetchOne(db)
  else {
    throw NSError(domain: "Gate4DispositionSeparationTests", code: 1)
  }
  return FixtureState(
    stream: stream,
    artifact: artifact,
    piece: piece,
    edition: edition,
    entry: entry,
    essentialPieceIDs: try EditionOperations.essentialSubstantivePrimaryPieceIDs(in: db)
  )
}
