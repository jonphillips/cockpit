@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMClientKit
import SQLiteData
import Synchronization
import Testing

// MARK: - Fixtures and a prompt-driven stub

/// A per-candidate stubbed judgment. The stub reads the candidate IDs out of the prompt and emits
/// exactly one judgment object per candidate, so it satisfies the strict decoder (S2) for whatever
/// set of pieces a composition actually gathered.
private struct StubOutcome: Sendable {
  var admit = true
  var substantive = true
  var section = "forYou"
  var rank = 1
}

private func editionStub(
  overrides: [UUID: StubOutcome] = [:], `default`: StubOutcome = StubOutcome()
) -> StubModelClient {
  StubModelClient { request in
    let prompt = request.messages.last?.text ?? ""
    let ids = uuids(in: prompt)
    let judgments = ids.map { id -> String in
      let outcome = overrides[id] ?? `default`
      return """
        {"contentPieceID":"\(id.uuidString)","admit":\(outcome.admit),\
        "isSubstantivePrimary":\(outcome.substantive),"section":"\(outcome.section)",\
        "rank":\(outcome.rank),"rationale":"Because you follow this.",\
        "subjects":["policy","housing","cities"],"summary":"A concise summary.","finds":[]}
        """
    }
    return ModelResponse(
      text: "{\"judgments\":[\(judgments.joined(separator: ","))]}",
      usage: ModelUsage(inputTokens: 4_000, outputTokens: 1_200))
  }
}

/// A thread-safe capture box for the prompt a stub was sent.
private final class PromptBox: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: String?
  var text: String? { lock.withLock { stored } }
  func set(_ value: String?) { lock.withLock { stored = value } }
}

/// A test-only model-request gate that deliberately ignores cancellation while waiting. Unlike
/// `Task.sleep`, its checked continuation remains suspended until `open()` is called.
private actor CancellationIgnoringGate {
  private var entered = false
  private var isOpen = false
  private var enteredContinuation: CheckedContinuation<Void, Never>?
  private var waiter: CheckedContinuation<Void, Never>?

  func wait() async {
    entered = true
    enteredContinuation?.resume()
    enteredContinuation = nil
    guard !isOpen else { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func waitUntilEntered() async {
    guard !entered else { return }
    await withCheckedContinuation { enteredContinuation = $0 }
  }

  func open() {
    isOpen = true
    waiter?.resume()
    waiter = nil
  }
}

/// Like `editionStub` but records the prompt it was sent, so a test can assert what the judge saw.
private func capturingStub(into prompt: PromptBox) -> StubModelClient {
  StubModelClient { request in
    let text = request.messages.last?.text ?? ""
    prompt.set(text)
    let judgments = uuids(in: text).map { id in
      """
      {"contentPieceID":"\(id.uuidString)","admit":true,"isSubstantivePrimary":true,\
      "section":"forYou","rank":1,"rationale":"why","subjects":["a","b","c"],\
      "summary":"s","finds":[]}
      """
    }
    return ModelResponse(
      text: "{\"judgments\":[\(judgments.joined(separator: ","))]}",
      usage: ModelUsage(inputTokens: 100, outputTokens: 50))
  }
}

/// Every distinct UUID appearing in a string, in first-seen order. Candidate IDs are the only
/// UUIDs in the judgment prompt.
private func uuids(in text: String) -> [UUID] {
  let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
  let regex = try! NSRegularExpression(pattern: pattern)
  let range = NSRange(text.startIndex..., in: text)
  var seen: [UUID] = []
  var set = Set<UUID>()
  for match in regex.matches(in: text, range: range) {
    guard let r = Range(match.range, in: text), let id = UUID(uuidString: String(text[r])) else {
      continue
    }
    if set.insert(id).inserted { seen.append(id) }
  }
  return seen
}

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
    try $0.bootstrapDatabase()
  }
)
@MainActor
struct EditionTests {
  @Dependency(\.defaultDatabase) private var database

  // Fixture IDs are kept high so they never collide with the composer's incrementing entry IDs.
  private let interestAreaID = UUID(9001)
  private let base = Date(timeIntervalSince1970: 1_700_000_000)

  private func day(_ n: Int) -> Date { base.addingTimeInterval(86_400 * Double(n)) }

  private func seedStream(id: UUID, essential: Bool) async throws {
    try await database.write { db in
      if try InterestArea.find(self.interestAreaID).fetchOne(db) == nil {
        try InterestArea.insert {
          InterestArea.Draft(InterestArea(id: self.interestAreaID, name: "General", guidance: "Useful."))
        }.execute(db)
      }
      try Stream.insert {
        Stream.Draft(
          Stream(
            id: id, name: "Stream \(id.uuidString.prefix(4))", publisher: "Publisher",
            interestAreaID: self.interestAreaID, transport: .rss, locator: "https://example.com/feed",
            handlingGuidance: "Read the original argument.", isEssential: essential))
      }.execute(db)
    }
  }

  private func seedPiece(id: UUID, streamID: UUID, createdAt: Date) async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: id, kind: .article, title: "Piece \(id.uuidString.prefix(4))", publisher: "Publisher",
            createdAt: createdAt))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: UUID(8000 + (id.hashValue & 0xFFF)), streamID: streamID, transport: .rss,
            acquiredAt: createdAt, contentPieceID: id))
      }.execute(db)
      try NormalizedTextOperations.store("A concrete original article body.", for: id, in: db)
    }
  }

  private func entry(dayIndex: Int, piece: UUID) async throws -> EditionEntry? {
    let editionID = EditionDay.editionID(for: day(dayIndex))
    return try await database.read { db in
      try EditionEntry
        .where { $0.editionID.eq(editionID) && $0.contentPieceID.eq(piece) }
        .fetchOne(db)
    }
  }

  private func compose(dayIndex: Int, stub: StubModelClient) async throws -> EditionComposer.Result {
    let composer = EditionComposer(engine: JudgmentEngine(modelClient: stub))
    return try await composer.composeIfNeeded(now: day(dayIndex), in: database)
  }

  // MARK: - Composition from real Streams (end to end through the model)

  @Test("A real Edition composes from Streams: entries, sections, classifications, and cost")
  func composesFromStreams() async throws {
    let streamID = UUID(1001)
    try await seedStream(id: streamID, essential: false)
    let pieceA = UUID(1101), pieceB = UUID(1102)
    try await seedPiece(id: pieceA, streamID: streamID, createdAt: base)
    try await seedPiece(id: pieceB, streamID: streamID, createdAt: base)

    let model = withDependencies { $0.modelClient = editionStub() } operation: { EditionModel() }
    await model.composeIfNeeded()

    let edition = try #require(model.edition)
    expectNoDifference(edition.state, .open)
    #expect(edition.composedAt != nil)
    #expect(model.entries.count == 2)
    #expect(model.entries.allSatisfy { $0.section == .forYou })
    #expect(model.entries.allSatisfy { $0.rationale?.isEmpty == false })
    #expect(model.errorMessage == nil)

    // Done-criterion 3: composition cost recorded, with the model and prompt version.
    #expect((edition.estimatedCostUSD ?? 0) > 0)
    expectNoDifference(edition.promptVersion, JudgmentEngine.promptVersion)
    expectNoDifference(edition.modelName, JudgmentModel.displayName)

    // Classifications back-written onto the ContentPiece from the same pass.
    let piece = try #require(try await database.read { try ContentPiece.find(pieceA).fetchOne($0) })
    expectNoDifference(piece.isSubstantivePrimary, true)
    expectNoDifference(piece.summary, "A concise summary.")
    #expect(piece.subjects?.contains("housing") == true)
    expectNoDifference(model.compositionState, .composed)
  }

  @Test("Tail composition reaches a retryable error when a model ignores cancellation")
  func compositionTimeoutIsVisibleAndDoesNotMaterialize() async throws {
    let streamID = UUID(1151)
    try await seedStream(id: streamID, essential: false)
    try await seedPiece(id: UUID(1152), streamID: streamID, createdAt: base)

    let gate = CancellationIgnoringGate()
    let slowStub = StubModelClient { _ in
      // `withCheckedContinuation` deliberately does not react to task cancellation. This models
      // a model framework that keeps its request alive after the timeout asks it to stop.
      await gate.wait()
      return ModelResponse(text: "{\"judgments\":[]}")
    }
    let model = withDependencies { $0.modelClient = slowStub } operation: {
      EditionModel(timeout: .seconds(1))
    }

    let task = Task { await model.composeIfNeeded() }
    await gate.waitUntilEntered()
    expectNoDifference(model.compositionState, .composing(.screeningCandidates))
    await task.value

    expectNoDifference(model.compositionState, .failed)
    #expect(model.errorMessage?.contains("eight minutes") == true)
    let timedOutEdition = try await database.read { try Edition.find(EditionDay.editionID(for: self.base)).fetchOne($0) }
    expectNoDifference(timedOutEdition?.state, .composing)
    let entryCount = try await database.read { try EditionEntry.fetchCount($0) }
    expectNoDifference(entryCount, 0)
    await gate.open()
  }

  @Test("An empty tail is a definite completion state")
  func emptyTailIsVisibleAsEmpty() async {
    let model = withDependencies { $0.modelClient = editionStub() } operation: { EditionModel() }
    await model.composeIfNeeded()
    expectNoDifference(model.compositionState, .empty)
    #expect(model.errorMessage == nil)
  }

  @Test("Composing twice on the same day is a no-op (materialise once, ADR-0001 D5)")
  func materialisesOncePerDay() async throws {
    let streamID = UUID(1201)
    try await seedStream(id: streamID, essential: false)
    try await seedPiece(id: UUID(1301), streamID: streamID, createdAt: base)

    let first = try await compose(dayIndex: 0, stub: editionStub())
    let second = try await compose(dayIndex: 0, stub: editionStub())
    guard case .composed = first else { Issue.record("first compose should materialise"); return }
    guard case .alreadyComposed = second else {
      Issue.record("second compose same day should be a no-op"); return
    }
    let count = try await database.read { try Edition.fetchCount($0) }
    expectNoDifference(count, 1)
  }

  @Test("A curated Gmail corpus never invokes the Edition judgment passes")
  func curatedGmailIsOutsideTheTail() async throws {
    let pieceID = UUID(1351)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: pieceID, kind: .email, title: "A curated message", publisher: "Sender",
            createdAt: self.base))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: UUID(1352), transport: .gmail, providerID: "gmail:message:1351",
            acquiredAt: self.base, contentPieceID: pieceID))
      }.execute(db)
    }

    let calls = Mutex(0)
    let client = StubModelClient { _ in
      calls.withLock { $0 += 1 }
      return ModelResponse(text: "{\"judgments\":[]}")
    }
    let composer = EditionComposer(engine: JudgmentEngine(modelClient: client))
    let result = try await composer.composeIfNeeded(now: base, in: database)

    expectNoDifference(result, .nothingToCompose)
    expectNoDifference(calls.withLock { $0 }, 0)
  }

  @Test("A mixed corpus judges the non-Gmail tail and excludes Gmail")
  func mixedCorpusExcludesGmailWithoutShortCircuitingTheTail() async throws {
    let streamID = UUID(1361)
    let tailPieceID = UUID(1362)
    let gmailPieceID = UUID(1363)
    try await seedStream(id: streamID, essential: false)
    try await seedPiece(id: tailPieceID, streamID: streamID, createdAt: base)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: gmailPieceID, kind: .email, title: "A curated message", publisher: "Sender",
            createdAt: self.base))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: UUID(1364), transport: .gmail, providerID: "gmail:message:1363",
            acquiredAt: self.base, contentPieceID: gmailPieceID))
      }.execute(db)
    }

    guard case .composed = try await compose(dayIndex: 0, stub: editionStub()) else {
      Issue.record("the non-Gmail tail should still compose"); return
    }
    #expect(try await entry(dayIndex: 0, piece: tailPieceID) != nil)
    #expect(try await entry(dayIndex: 0, piece: gmailPieceID) == nil)
  }

  // MARK: - Entry-state machine (owned by the model)

  @Test("The model drives every legal transition and rejects every illegal one")
  func transitionMatrix() async throws {
    let editionID = EditionDay.editionID(for: base)
    let pieceID = UUID(1401)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(id: pieceID, kind: .article, title: "T", publisher: "P", createdAt: self.base))
      }.execute(db)
    }

    // The legal edges, restated independently of the production table (IMPLEMENTATION-CONTRACT §3).
    let legal: Set<[EditionEntryState]> = [
      [.admitted, .seen],
      [.admitted, .dismissed], [.seen, .dismissed],
      [.admitted, .resolved], [.seen, .resolved],
      [.admitted, .aged], [.seen, .aged],
      [.admitted, .carried], [.seen, .carried],
    ]

    let model = EditionModel()
    var index = 0
    for from in EditionEntryState.allCases {
      for to in EditionEntryState.allCases {
        index += 1
        let entryID = UUID(5000 + index)
        try await database.write { db in
          try EditionEntry.insert {
            EditionEntry.Draft(
              EditionEntry(
                id: entryID, editionID: editionID, contentPieceID: pieceID, section: .forYou,
                rank: 1, entryState: from, firstAdmittedEditionID: editionID))
          }.execute(db)
        }

        await model.transition(entryID, to: to)
        let after = try #require(try await database.read { try EditionEntry.find(entryID).fetchOne($0) })

        if legal.contains([from, to]) {
          expectNoDifference(after.entryState, to, "expected \(from) → \(to) to be legal")
          #expect(model.errorMessage == nil)
        } else {
          expectNoDifference(after.entryState, from, "expected \(from) → \(to) to be rejected")
          #expect(model.errorMessage != nil)
          model.errorMessage = nil
        }
      }
    }
  }

  @Test("Mark-Seen on open is idempotent: reopening a Seen or resolved entry never errors")
  func markSeenIsIdempotent() async throws {
    let editionID = EditionDay.editionID(for: base)
    let pieceID = UUID(1451)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(id: pieceID, kind: .article, title: "T", publisher: "P", createdAt: self.base))
      }.execute(db)
    }
    let model = EditionModel()

    // admitted → seen advances and reports no error.
    let admittedID = UUID(5501)
    try await database.write { db in
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: admittedID, editionID: editionID, contentPieceID: pieceID, section: .forYou,
            rank: 1, entryState: .admitted, firstAdmittedEditionID: editionID))
      }.execute(db)
    }
    await model.markSeen(admittedID)
    var after = try #require(try await database.read { try EditionEntry.find(admittedID).fetchOne($0) })
    expectNoDifference(after.entryState, .seen)
    #expect(model.errorMessage == nil)

    // Reopening the now-Seen entry is a no-op, not the `seen → seen` illegal transition that
    // surfaced "EditionOperations.Failure error 1" in the Reader.
    await model.markSeen(admittedID)
    after = try #require(try await database.read { try EditionEntry.find(admittedID).fetchOne($0) })
    expectNoDifference(after.entryState, .seen)
    #expect(model.errorMessage == nil)

    // Opening an already-resolved/dismissed entry (e.g. reached from Later) is likewise a no-op.
    let dismissedID = UUID(5502)
    try await database.write { db in
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: dismissedID, editionID: editionID, contentPieceID: pieceID, section: .forYou,
            rank: 1, entryState: .dismissed, firstAdmittedEditionID: editionID))
      }.execute(db)
    }
    await model.markSeen(dismissedID)
    after = try #require(try await database.read { try EditionEntry.find(dismissedID).fetchOne($0) })
    expectNoDifference(after.entryState, .dismissed)
    #expect(model.errorMessage == nil)
  }

  // MARK: - Reader resolution actions (M2 S4)

  @Test("Save for Later resolves the entry and writes LaterMembership in one atomic write")
  func saveForLaterWritesMembership() async throws {
    let streamID = UUID(6001)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(6101)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)
    let editionID = EditionDay.editionID(for: base)
    let entryID = UUID(6201)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: entryID, editionID: editionID, contentPieceID: pieceID, section: .forYou, rank: 1,
            entryState: .admitted, firstAdmittedEditionID: editionID))
      }.execute(db)
    }

    let model = EditionModel()
    await model.saveForLater(entryID)

    #expect(model.errorMessage == nil)
    let entry = try #require(try await database.read { try EditionEntry.find(entryID).fetchOne($0) })
    expectNoDifference(entry.entryState, .resolved)
    let membership = try await database.read { try LaterMembership.find(pieceID).fetchOne($0) }
    expectNoDifference(membership?.addedAt, base)
  }

  @Test("Save for Later on an already-terminal entry is rejected and writes no membership")
  func saveForLaterRejectsIllegalTransition() async throws {
    let streamID = UUID(6301)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(6401)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)
    let editionID = EditionDay.editionID(for: base)
    let entryID = UUID(6501)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: entryID, editionID: editionID, contentPieceID: pieceID, section: .forYou, rank: 1,
            entryState: .dismissed, firstAdmittedEditionID: editionID))
      }.execute(db)
    }

    let model = EditionModel()
    await model.saveForLater(entryID)

    #expect(model.errorMessage != nil)
    let entry = try #require(try await database.read { try EditionEntry.find(entryID).fetchOne($0) })
    expectNoDifference(entry.entryState, .dismissed)
    let count = try await database.read { try LaterMembership.fetchCount($0) }
    expectNoDifference(count, 0)
  }

  @Test("Add to Library writes the membership and leaves entryState untouched (orthogonal)")
  func addToLibraryLeavesEntryStateUnchanged() async throws {
    let streamID = UUID(6601)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(6701)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)
    let editionID = EditionDay.editionID(for: base)
    let entryID = UUID(6801)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: entryID, editionID: editionID, contentPieceID: pieceID, section: .forYou, rank: 1,
            entryState: .seen, firstAdmittedEditionID: editionID))
      }.execute(db)
    }

    let model = EditionModel()
    await model.addToLibrary(entryID)

    #expect(model.errorMessage == nil)
    let entry = try #require(try await database.read { try EditionEntry.find(entryID).fetchOne($0) })
    expectNoDifference(entry.entryState, .seen)
    let membership = try await database.read { try LibraryMembership.find(pieceID).fetchOne($0) }
    expectNoDifference(membership?.admittedBy, "explicit")
  }

  @Test("isSubstantivePrimary is correctable from the Reader independent of the judged value")
  func correctsSubstantivePrimary() async throws {
    let streamID = UUID(6901)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(6902)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)
    try await database.write { db in
      try ContentPiece.find(pieceID).update { $0.isSubstantivePrimary = #bind(true) }.execute(db)
    }
    let editionID = EditionDay.editionID(for: base)
    let entryID = UUID(6903)
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: EditionDay.start(of: self.base), state: .open))
      }.execute(db)
      try EditionEntry.insert {
        EditionEntry.Draft(
          EditionEntry(
            id: entryID, editionID: editionID, contentPieceID: pieceID, section: .forYou, rank: 1,
            entryState: .admitted, firstAdmittedEditionID: editionID))
      }.execute(db)
    }

    let model = EditionModel()
    await model.correctIsSubstantivePrimary(entryID, to: false)

    #expect(model.errorMessage == nil)
    let piece = try #require(try await database.read { try ContentPiece.find(pieceID).fetchOne($0) })
    expectNoDifference(piece.isSubstantivePrimary, false)
  }

  @Test("Contextual Stream Handling access: streamID resolves a piece back to the Stream it arrived through")
  func resolvesStreamIDForContextualAccess() async throws {
    let streamID = UUID(7001)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(7101)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    let resolved = try await database.read { try EditionOperations.streamID(for: pieceID, in: $0) }
    expectNoDifference(resolved, streamID)

    let orphanPieceID = UUID(7102)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: orphanPieceID, kind: .article, title: "Orphan", publisher: "Publisher",
            createdAt: self.base))
      }.execute(db)
    }
    let noStream = try await database.read { try EditionOperations.streamID(for: orphanPieceID, in: $0) }
    #expect(noStream == nil)
  }

  // MARK: - Carryover budget

  @Test("A non-Essential entry carries at most 3 times, then ages (contract §3)")
  func carryoverBudgetAges() async throws {
    let streamID = UUID(2001)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(2101)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // Admitted day 0; carried across the next three boundaries; aged at the fourth.
    for dayIndex in 0...4 {
      _ = try await compose(dayIndex: dayIndex, stub: editionStub())
    }

    let day0 = try #require(try await entry(dayIndex: 0, piece: pieceID))
    let day1 = try #require(try await entry(dayIndex: 1, piece: pieceID))
    let day3 = try #require(try await entry(dayIndex: 3, piece: pieceID))
    expectNoDifference(day0.timesCarried, 0)
    expectNoDifference(day0.entryState, .carried)
    expectNoDifference(day1.timesCarried, 1)
    expectNoDifference(day3.timesCarried, 3)
    // The day-3 entry has been carried 3 times; the day-4 boundary ages it, and with no new
    // candidates no day-4 Edition is materialised.
    expectNoDifference(day3.entryState, .aged)
    #expect(try await entry(dayIndex: 4, piece: pieceID) == nil)

    // firstAdmittedEditionID is preserved across the whole carried chain.
    expectNoDifference(day3.firstAdmittedEditionID, EditionDay.editionID(for: day(0)))
  }

  @Test("A carryover is re-judged sighted: its carriedEntry context reaches the prompt")
  func carriedEntryReachesTheJudge() async throws {
    let streamID = UUID(2201)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(2301)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // Day 0 admits it fresh — no carryover context yet.
    let day0Prompt = PromptBox()
    _ = try await compose(dayIndex: 0, stub: capturingStub(into: day0Prompt))
    #expect(day0Prompt.text?.contains("carriedEntry") != true)

    // Day 1 re-judges the carryover; the prompt must carry its fatigue signal.
    let day1Prompt = PromptBox()
    _ = try await compose(dayIndex: 1, stub: capturingStub(into: day1Prompt))
    let prompt = try #require(day1Prompt.text)
    #expect(prompt.contains("\"entryState\":\"carried\""))
    #expect(prompt.contains("\"timesCarried\":1"))
  }

  @Test("A crashed composing Edition is re-driven, not left blocking the day")
  func recoversFromInterruptedComposition() async throws {
    let streamID = UUID(2401)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(2501)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // Simulate a process death between Phase 1 and Phase 3: a `composing` row with no entries.
    let editionID = EditionDay.editionID(for: day(0))
    let dayStart = EditionDay.start(of: day(0))
    try await database.write { db in
      try Edition.insert {
        Edition.Draft(Edition(id: editionID, date: dayStart, state: .composing))
      }.execute(db)
    }

    let result = try await compose(dayIndex: 0, stub: editionStub())
    guard case .composed = result else { Issue.record("should re-drive the crashed compose"); return }
    let edition = try #require(try await database.read { try Edition.find(editionID).fetchOne($0) })
    expectNoDifference(edition.state, .open)
    #expect(try await entry(dayIndex: 0, piece: pieceID) != nil)
  }

  // MARK: - Essential guarantee and relief valve

  @Test("An Essential substantive-primary piece is never aged, even when the model declines it")
  func essentialNeverAged() async throws {
    let streamID = UUID(3001)
    try await seedStream(id: streamID, essential: true)
    let pieceID = UUID(3101)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // The model declines it every day, but it is substantive-primary from an Essential Stream.
    let stub = editionStub(overrides: [pieceID: StubOutcome(admit: false, substantive: true)])
    for dayIndex in 0...20 {
      _ = try await compose(dayIndex: dayIndex, stub: stub)
    }

    // It is admitted despite the decline, and no entry in the whole chain is ever aged (invariant 5).
    let allEntries = try await database.read { db in
      try EditionEntry.where { $0.contentPieceID.eq(pieceID) }.fetchAll(db)
    }
    #expect(allEntries.count >= 20)
    #expect(allEntries.allSatisfy { $0.entryState != .aged })

    let day0 = try #require(try await entry(dayIndex: 0, piece: pieceID))
    expectNoDifference(day0.section, .essentials)
  }

  @Test("An Essential entry carried more than 14 times moves to the Essential backlog (contract §3)")
  func essentialBacklogReliefValve() async throws {
    let streamID = UUID(3201)
    try await seedStream(id: streamID, essential: true)
    let pieceID = UUID(3301)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    let stub = editionStub(overrides: [pieceID: StubOutcome(admit: false, substantive: true)])
    for dayIndex in 0...16 {
      _ = try await compose(dayIndex: dayIndex, stub: stub)
    }

    // timesCarried 0…14 stay in essentials; the first entry past 14 is relieved into the backlog.
    let day14 = try #require(try await entry(dayIndex: 14, piece: pieceID))
    expectNoDifference(day14.timesCarried, 14)
    expectNoDifference(day14.section, .essentials)

    let day16 = try #require(try await entry(dayIndex: 16, piece: pieceID))
    expectNoDifference(day16.timesCarried, 16)
    expectNoDifference(day16.section, .essentialBacklog)
    expectNoDifference(day16.entryState, .admitted)
  }

  @Test("A carried piece is never duplicated within an Edition (invariant 4)")
  func noDuplicatePieceWithinEdition() async throws {
    let streamID = UUID(3401)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(3501)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // Compose across several days; the piece is carried each time. No day may hold two entries
    // for it — the carried path and the new-piece path stay disjoint.
    for dayIndex in 0...3 {
      _ = try await compose(dayIndex: dayIndex, stub: editionStub())
    }

    for dayIndex in 0...3 {
      let editionID = EditionDay.editionID(for: day(dayIndex))
      let count = try await database.read { db in
        try EditionEntry
          .where { $0.editionID.eq(editionID) && $0.contentPieceID.eq(pieceID) }
          .fetchCount(db)
      }
      #expect(count <= 1, "day \(dayIndex) held \(count) entries for one piece")
    }
  }

  // MARK: - Fail-closed and stored-state rendering

  @Test("A fail-closed piece is not admitted and does not sink the composition")
  func failClosedIsNotAdmitted() async throws {
    let streamID = UUID(4001)
    try await seedStream(id: streamID, essential: false)
    let good = UUID(4101), bad = UUID(4102)
    try await seedPiece(id: good, streamID: streamID, createdAt: base)
    try await seedPiece(id: bad, streamID: streamID, createdAt: base)

    // The stub omits `bad` entirely, so the strict decoder fails it closed while `good` stands.
    let stub = StubModelClient { request in
      let ids = uuids(in: request.messages.last?.text ?? "").filter { $0 != bad }
      let judgments = ids.map {
        """
        {"contentPieceID":"\($0.uuidString)","admit":true,"isSubstantivePrimary":true,\
        "section":"forYou","rank":1,"rationale":"why","subjects":["a","b","c"],\
        "summary":"s","finds":[]}
        """
      }
      return ModelResponse(
        text: "{\"judgments\":[\(judgments.joined(separator: ","))]}",
        usage: ModelUsage(inputTokens: 100, outputTokens: 50))
    }
    _ = try await compose(dayIndex: 0, stub: stub)

    #expect(try await entry(dayIndex: 0, piece: good) != nil)
    #expect(try await entry(dayIndex: 0, piece: bad) == nil)
    // The failed piece keeps no phantom classification.
    let badPiece = try #require(try await database.read { try ContentPiece.find(bad).fetchOne($0) })
    #expect(badPiece.isSubstantivePrimary == nil)
  }

  @Test("A wholesale judgment failure rolls back so the day can be recomposed, not frozen empty")
  func wholesaleJudgmentFailureIsRecoverable() async throws {
    let streamID = UUID(4401)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(4501)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // Every candidate fails at once — the live symptom of a timeout on the single batched judgment
    // call. No candidate yields a valid outcome, so this is not a legitimate zero-entry Edition.
    let failing = StubModelClient { _ in throw URLError(.timedOut) }
    await #expect(throws: EditionComposer.CompositionError.self) {
      _ = try await self.compose(dayIndex: 0, stub: failing)
    }

    // Nothing was frozen in place: no Edition row exists, so composeIfNeeded is free to retry.
    let editionID = EditionDay.editionID(for: day(0))
    #expect(try await database.read { try Edition.find(editionID).fetchOne($0) } == nil)

    // The retry, now with a working judge, composes normally and admits the piece.
    let result = try await compose(dayIndex: 0, stub: editionStub())
    guard case .composed = result else { Issue.record("retry should compose"); return }
    #expect(try await entry(dayIndex: 0, piece: pieceID) != nil)
  }

  @Test("Recompose discards today's Edition and re-drives it (explicit reconsider, contract §3)")
  func recomposeRebuildsToday() async throws {
    let streamID = UUID(4601)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(4701)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    // First compose declines everything → a legitimate but empty open Edition (the same shape a
    // stale timeout leaves behind). composeIfNeeded is now a no-op on it.
    let declineAll = editionStub(default: StubOutcome(admit: false, substantive: false))
    guard case .composed = try await compose(dayIndex: 0, stub: declineAll) else {
      Issue.record("first compose should materialise"); return
    }
    #expect(try await entry(dayIndex: 0, piece: pieceID) == nil)
    guard case .alreadyComposed = try await compose(dayIndex: 0, stub: editionStub()) else {
      Issue.record("composeIfNeeded should be a no-op once open"); return
    }

    // Recompose (now admitting) discards the empty Edition and re-drives — one Edition for the day,
    // now with the piece admitted.
    let composer = EditionComposer(engine: JudgmentEngine(modelClient: editionStub()))
    guard case .composed = try await composer.recompose(now: day(0), in: database) else {
      Issue.record("recompose should re-drive"); return
    }
    #expect(try await entry(dayIndex: 0, piece: pieceID) != nil)
    let count = try await database.read { try Edition.fetchCount($0) }
    expectNoDifference(count, 1)
  }

  @Test("A closed Edition renders entirely from stored state (done-criterion 4)")
  func closedEditionRendersFromStoredState() async throws {
    let streamID = UUID(4201)
    try await seedStream(id: streamID, essential: false)
    let pieceID = UUID(4301)
    try await seedPiece(id: pieceID, streamID: streamID, createdAt: base)

    _ = try await compose(dayIndex: 0, stub: editionStub())
    // A second day closes day 0.
    try await seedPiece(id: UUID(4302), streamID: streamID, createdAt: day(1).addingTimeInterval(1))
    _ = try await compose(dayIndex: 1, stub: editionStub())

    let day0ID = EditionDay.editionID(for: day(0))
    let closed = try #require(try await database.read { try Edition.find(day0ID).fetchOne($0) })
    expectNoDifference(closed.state, .closed)

    // Its entry still explains itself from stored columns — section, rank, rationale — no re-run.
    let storedEntry = try #require(try await entry(dayIndex: 0, piece: pieceID))
    expectNoDifference(storedEntry.section, .forYou)
    #expect(storedEntry.rationale?.isEmpty == false)
    #expect(storedEntry.entryState == .carried || storedEntry.entryState == .admitted)
  }
}
