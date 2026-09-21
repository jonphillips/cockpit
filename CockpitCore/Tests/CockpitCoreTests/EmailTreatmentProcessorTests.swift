@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMClientKit
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  try $0.bootstrapDatabase()
})
@MainActor
struct EmailTreatmentProcessorTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("An offer gets a one-line treatment summary and a durable Pending Find")
  func offerProducesSummaryAndFind() async throws {
    let pieceID = UUID(8_001)
    try await seed(pieceID, treatment: .offer, text: "A wine allocation of 2023 Example Estate Pinot Noir.")
    let requestCount = Mutex(0)
    let processor = EmailTreatmentProcessor(modelClient: StubModelClient { request in
      requestCount.withLock { $0 += 1 }
      #expect(request.messages.last?.text.contains(pieceID.uuidString) == true)
      return ModelResponse(text: #"""
      {"summary":"Example Estate offers its 2023 Pinot Noir allocation.","find":{"kind":"wine","name":"2023 Example Estate Pinot Noir","descriptor":"A limited allocation wine offer.","rationale":"The offer identifies a specific bottle to consider later.","sourceURL":"https://example.com/pinot","hints":{"vintage":"2023"}}}
      """#)
    })

    let details = try await processor.process(emailContentPieceIDs: [pieceID], in: database)

    #expect(requestCount.withLock { $0 } == 1)
    #expect(details.first?.offerSummary == "Example Estate offers its 2023 Pinot Noir allocation.")
    let persisted = try await database.read { db in
      (
        try EmailTreatmentDetails.find(pieceID).fetchOne(db),
        try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)
      )
    }
    #expect(persisted.0?.offerSummary == "Example Estate offers its 2023 Pinot Noir allocation.")
    #expect(persisted.1?.kind == "wine")
    #expect(persisted.1?.name == "2023 Example Estate Pinot Noir")

    let model = TodayModel()
    try await model.$content.load()
    #expect(model.tiers.first?.rows.first?.treatmentSummary == persisted.0?.offerSummary)
  }

  @Test("A Feed Me grab-bag links to its manual Stream and extracts only within that issue")
  func grabBagLinksAndExtractsWithinIssue() async throws {
    let stream = Stream(
      id: UUID(8_101), name: "Feed Me", publisher: "Feed Me", transport: .gmail,
      locator: "digest@example.com", isGrabBag: true)
    try await database.write { db in
      try Stream.insert { Stream.Draft(stream) }.execute(db)
    }
    let message = GmailInboxMessage(
      id: "feed-me-1", threadID: "feed-me-thread",
      headers: [
        .init(name: "From", value: "Feed Me <digest@example.com>"),
        .init(name: "Subject", value: "This week's links"),
        .init(name: "To", value: "jon@example.com"),
        .init(name: "List-ID", value: "Feed Me <digest.example.com>"),
      ],
      bodyPlainText: "First: Swift concurrency notes https://example.com/swift\nSecond: A useful wine essay https://example.com/wine")
    let report = try await GmailInboxIngestor(
      client: .init(currentInbox: { .init(accountID: "jon@example.com", messages: [message]) }),
      now: { .distantPast }
    ).ingest(into: database)
    let piece = try #require(report.contentPieces.first)
    #expect(piece.emailTreatment == .grabBag)
    let linkedArtifact = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchOne(db)
    }
    #expect(linkedArtifact?.streamID == stream.id)

    let requestedPieceIDs = Mutex<[String]>([])
    let processor = EmailTreatmentProcessor(modelClient: StubModelClient { request in
      requestedPieceIDs.withLock { $0.append(request.messages.last?.text ?? "") }
      return ModelResponse(text: #"""
      {"items":[
        {"title":"Swift concurrency notes","summary":"Notes on structured concurrency for Swift applications.","sourceURL":"https://example.com/swift"},
        {"title":"A useful wine essay","summary":"An essay on choosing wine for dinner.","sourceURL":"https://example.com/wine"}
      ]}
      """#)
    })

    let details = try await processor.process(emailContentPieceIDs: [piece.id], in: database)

    #expect(requestedPieceIDs.withLock { $0.count } == 1)
    #expect(requestedPieceIDs.withLock { $0.first?.contains(piece.id.uuidString) } == true)
    #expect(details.first?.decodedGrabBagItems.map(\.title) == ["Swift concurrency notes", "A useful wine essay"])
    let streamRows = try await database.read { db in
      try StreamHandlingRequest(streamID: stream.id).fetch(db).rows
    }
    #expect(streamRows.map(\.id) == [piece.id])
    let todayRows = try await database.read { db in try TodayRequest().fetch(db).rows }
    #expect(todayRows.contains { $0.id == piece.id } == false)
  }

  @Test("Treatment processing is one message at a time and never turns a model failure into hiding")
  func processingIsPerPieceAndFailsOpen() async throws {
    let first = UUID(8_201)
    let second = UUID(8_202)
    try await seed(first, treatment: .offer, text: "First allocation")
    try await seed(second, treatment: .offer, text: "Second allocation")
    let prompts = Mutex<[String]>([])
    let processor = EmailTreatmentProcessor(modelClient: StubModelClient { request in
      prompts.withLock { $0.append(request.messages.last?.text ?? "") }
      throw StubError.failed
    })

    let details = try await processor.process(emailContentPieceIDs: [first, second], in: database)

    #expect(details.isEmpty)
    let capturedPrompts = prompts.withLock { $0 }
    #expect(capturedPrompts.count == 2)
    #expect(capturedPrompts.allSatisfy { prompt in
      prompt.contains(first.uuidString) != prompt.contains(second.uuidString)
    })
    let today = try await database.read { db in try TodayRequest().fetch(db) }
    #expect(Set(today.rows.map(\.id)) == [first, second])
  }

  private func seed(_ id: UUID, treatment: EmailTreatment, text: String) async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: id, kind: .email, title: "\(id.uuidString) offer", publisher: "Sender",
          emailTreatment: treatment, createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          id: UUID(id.hashValue), transport: .gmail, providerID: "gmail:message:\(id.uuidString)",
          acquiredAt: .distantPast, rawSourceText: text, providerProvenance: "{}", contentPieceID: id)
      }.execute(db)
      try NormalizedTextOperations.store(text, for: id, in: db)
    }
  }

  private enum StubError: Error { case failed }
}
