@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(
  .serialized,
  .dependencies {
    try $0.bootstrapDatabase()
    $0.date.now = Date(timeIntervalSince1970: 123)
  }
)
@MainActor
struct GmailReplyTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Reply message uses Reply-To, preserves threading, encodes subject, and emits CRLF")
  func buildsThreadedReply() throws {
    let headers = GmailReplyHeaders(
      from: "Sender <sender@example.com>", replyTo: "Replies <reply@example.com>", subject: "Café notes",
      messageID: "<message@example.com>", references: "<first@example.com>"
    )
    let raw = GmailReplyMessage.make(original: headers, fromAddress: "jon@example.com", body: "Thanks\nsee you")

    #expect(raw.contains("To: Replies <reply@example.com>\r\n"))
    #expect(raw.contains("Subject: =?UTF-8?B?"))
    #expect(raw.contains("In-Reply-To: <message@example.com>\r\n"))
    #expect(raw.contains("References: <first@example.com> <message@example.com>\r\n"))
    #expect(!raw.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    let encodedBody = try #require(raw.components(separatedBy: "\r\n\r\n").last)
      .replacingOccurrences(of: "\r\n", with: "")
    #expect(try #require(Data(base64Encoded: encodedBody)) == Data("Thanks\r\nsee you".utf8))
  }

  @Test("Reply subject does not duplicate Re and References works without prior chain")
  func existingReplySubjectAndEmptyReferences() {
    let headers = GmailReplyHeaders(
      from: "a@example.com", replyTo: nil, subject: "rE: Existing", messageID: "<id>", references: nil
    )
    let raw = GmailReplyMessage.make(original: headers, fromAddress: "jon@example.com", body: "Hi")
    #expect(headers.replySubject == "rE: Existing")
    #expect(raw.contains("To: a@example.com\r\n"))
    #expect(raw.contains("References: <id>\r\n"))
    #expect(raw.components(separatedBy: "Subject:").count == 2)
  }

  @Test("Missing subject becomes an empty reply subject and encoded words stay within RFC limit")
  func missingAndLongSubject() throws {
    let missingSubject = GmailReplyHeaders(
      from: "person@example.com", replyTo: nil, subject: "", messageID: "<id>", references: nil
    )
    #expect(missingSubject.replySubject == "Re: ")

    let longSubject = GmailReplyHeaders(
      from: "person@example.com", replyTo: nil, subject: String(repeating: "é", count: 100),
      messageID: "<id>", references: nil
    )
    let raw = GmailReplyMessage.make(original: longSubject, fromAddress: "jon@example.com", body: "")
    let encodedWords = raw.components(separatedBy: "\r\n")
      .flatMap { $0.components(separatedBy: " ") }
      .filter { $0.hasPrefix("=?UTF-8?B?") }
    #expect(!encodedWords.isEmpty)
    #expect(encodedWords.allSatisfy { $0.utf8.count <= 75 })
  }

  @Test("Reader reply sends once and optionally archives only after success")
  func sendsAndArchivesAfterSuccess() async throws {
    let pieceID = UUID(28_001)
    try await seedGmailPiece(pieceID)
    let sent = Mutex<[(String, String)]>([])
    let archived = Mutex(0)
    let replyHeaders = Self.headers
    let client = GmailReplyClient(
      replyHeaders: { id in
        #expect(id.hasPrefix("message-"))
        return replyHeaders
      },
      send: { raw, threadID in sent.withLock { $0.append((raw, threadID)) } }
    )
    let model = withDependencies { $0.gmailReplyClient = client } operation: {
      ReaderReplyModel(contentPieceID: pieceID)
    }
    await model.load()
    model.body = "Hello"
    await model.send(thenArchive: true) { archived.withLock { $0 += 1 } }

    #expect(model.didSend)
    #expect(!model.canSend)
    #expect(model.errorMessage == nil)
    #expect(sent.withLock { $0.count } == 1)
    #expect(sent.withLock { $0.first?.1.hasPrefix("thread-") } == true)
    #expect(archived.withLock { $0 } == 1)
  }

  @Test("Send without archive leaves the queue disposition untouched")
  func sendsWithoutArchiving() async throws {
    let pieceID = UUID(28_004)
    try await seedGmailPiece(pieceID)
    let archived = Mutex(0)
    let replyHeaders = Self.headers
    let client = GmailReplyClient(
      replyHeaders: { _ in replyHeaders },
      send: { _, _ in }
    )
    let model = withDependencies { $0.gmailReplyClient = client } operation: {
      ReaderReplyModel(contentPieceID: pieceID)
    }
    await model.load()
    model.body = "Hello"
    await model.send(thenArchive: false) { archived.withLock { $0 += 1 } }

    #expect(model.didSend)
    #expect(archived.withLock { $0 } == 0)
  }

  @Test("Recipient uses the display name while keeping the actual address visible")
  func recipientDisplayAndAddress() async throws {
    let pieceID = UUID(28_005)
    try await seedGmailPiece(pieceID)
    let headers = GmailReplyHeaders(
      from: "Original Sender <from@example.com>", replyTo: "Matthew Yglesias <reply@example.com>",
      subject: "Question", messageID: "<id>", references: nil
    )
    let client = GmailReplyClient(replyHeaders: { _ in headers }, send: { _, _ in })
    let model = withDependencies { $0.gmailReplyClient = client } operation: {
      ReaderReplyModel(contentPieceID: pieceID)
    }
    await model.load()

    #expect(model.recipientDisplay == "Matthew Yglesias")
    #expect(model.recipientAddress == "reply@example.com")
    #expect(model.recipientSummary == "Matthew Yglesias <reply@example.com>")
  }

  @Test("Failed send keeps the body, surfaces error, and does not archive or retry")
  func failedSendIsNotRetried() async throws {
    let pieceID = UUID(28_002)
    try await seedGmailPiece(pieceID)
    let calls = Mutex(0)
    let archived = Mutex(0)
    let replyHeaders = Self.headers
    let client = GmailReplyClient(
      replyHeaders: { _ in replyHeaders },
      send: { _, _ in
        calls.withLock { $0 += 1 }
        throw ReplySendFailure.failed
      }
    )
    let model = withDependencies { $0.gmailReplyClient = client } operation: {
      ReaderReplyModel(contentPieceID: pieceID)
    }
    await model.load()
    model.body = "Keep this reply"
    await model.send(thenArchive: true) { archived.withLock { $0 += 1 } }

    #expect(!model.didSend)
    #expect(model.body == "Keep this reply")
    #expect(model.errorMessage == "send failed")
    #expect(calls.withLock { $0 } == 1)
    #expect(archived.withLock { $0 } == 0)
  }

  @Test("Empty body cannot be sent")
  func emptyBodyDisabled() async throws {
    let pieceID = UUID(28_003)
    try await seedGmailPiece(pieceID)
    let calls = Mutex(0)
    let replyHeaders = Self.headers
    let client = GmailReplyClient(
      replyHeaders: { _ in replyHeaders },
      send: { _, _ in calls.withLock { $0 += 1 } }
    )
    let model = withDependencies { $0.gmailReplyClient = client } operation: {
      ReaderReplyModel(contentPieceID: pieceID)
    }
    await model.load()
    model.body = " \n "
    #expect(!model.canSend)
    await model.send(thenArchive: false)
    #expect(calls.withLock { $0 } == 0)
  }

  private static let headers = GmailReplyHeaders(
    from: "Person <person@example.com>", replyTo: nil, subject: "Question", messageID: "<id-1>",
    references: nil
  )

  private func seedGmailPiece(_ id: ContentPiece.ID) async throws {
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: "message-\(id.uuidString.suffix(5))",
      threadID: "thread-\(id.uuidString.suffix(5))", rfcMessageID: nil, listUnsubscribe: nil,
      listID: nil, precedence: nil, senderAddress: "person@example.com", sendingDomain: "example.com",
      dkimDomain: nil, toRecipientCount: 1, ccRecipientCount: 0
    )
    let provenanceText = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: id, kind: .email, title: "A note", publisher: "Person", emailTreatment: .personal,
          createdAt: .distantPast
        ))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail, providerID: provenance.messageID, acquiredAt: .distantPast,
          providerProvenance: provenanceText, contentPieceID: id
        ))
      }.execute(db)
    }
  }
}

private enum ReplySendFailure: LocalizedError {
  case failed
  var errorDescription: String? { "send failed" }
}
