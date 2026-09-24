@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

struct MailMessageLinkTests {
  @Test("Mail message ID keeps its exact opaque URL form")
  func wrapsAndPreservesMessageID() throws {
    let noteFixture = "<7A.8E.15342.8EF44BA6@i-0a25a4edc84d77c0e.mta1vrest.sd.prd.sparkpost>"
    #expect(
      try #require(MailMessageLink.url(rfcMessageID: noteFixture)?.absoluteString)
        == "message:%3C7A.8E.15342.8EF44BA6@i-0a25a4edc84d77c0e.mta1vrest.sd.prd.sparkpost%3E"
    )
    #expect(
      MailMessageLink.url(rfcMessageID: "message@example.com")?.absoluteString
        == "message:%3Cmessage@example.com%3E"
    )
  }

  @Test("Invalid IDs are rejected and reserved characters are encoded")
  func validatesAndEncodes() {
    let invalidIDs: [String?] = [nil, "", "<>", "  \n", "<has whitespace@example.com>"]
    for value in invalidIDs {
      #expect(MailMessageLink.url(rfcMessageID: value) == nil)
    }
    #expect(
      MailMessageLink.url(rfcMessageID: "<CAF+ab=cd/ef@mail.gmail.com>")?.absoluteString
        == "message:%3CCAF%2Bab%3Dcd%2Fef@mail.gmail.com%3E"
    )
  }
}

@Suite(.dependencies { try $0.bootstrapDatabase() })
@MainActor
struct ReaderMailMessageLinkTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Reader exposes a Mail URL only for an email with local RFC message provenance")
  func modelRequiresEmailAndLocalMessageID() async throws {
    let emailID = UUID(93_001)
    let missingMessageID = UUID(93_002)
    let articleID = UUID(93_003)
    let noArtifactID = UUID(93_004)
    try await seed(id: emailID, kind: .email, rfcMessageID: "<mail@example.com>")
    try await seed(id: missingMessageID, kind: .email, rfcMessageID: nil)
    try await seed(id: articleID, kind: .article, rfcMessageID: "<mail@example.com>")
    try await seed(id: noArtifactID, kind: .email, rfcMessageID: "<not-held@example.com>", hasArtifact: false)

    let email = ContentPieceReaderModel(contentPieceID: emailID)
    try await email.$content.load()
    await email.loadMailMessageLink()
    #expect(email.mailMessageURL?.absoluteString == "message:%3Cmail@example.com%3E")

    let missingID = ContentPieceReaderModel(contentPieceID: missingMessageID)
    try await missingID.$content.load()
    await missingID.loadMailMessageLink()
    #expect(missingID.mailMessageURL == nil)

    let article = ContentPieceReaderModel(contentPieceID: articleID)
    try await article.$content.load()
    await article.loadMailMessageLink()
    #expect(article.mailMessageURL == nil)

    let noArtifact = ContentPieceReaderModel(contentPieceID: noArtifactID)
    try await noArtifact.$content.load()
    await noArtifact.loadMailMessageLink()
    #expect(noArtifact.mailMessageURL == nil)
  }

  private func seed(
    id: UUID, kind: ContentKind, rfcMessageID: String?, hasArtifact: Bool = true
  ) async throws {
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: "provider-\(id.uuidString)",
      threadID: "thread-\(id.uuidString)", rfcMessageID: rfcMessageID, listUnsubscribe: nil,
      listID: nil, precedence: nil, senderAddress: "person@example.com", sendingDomain: "example.com",
      dkimDomain: nil, toRecipientCount: 1, ccRecipientCount: 0
    )
    let provenanceText = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: id, kind: kind, title: "Mail link fixture", publisher: "Fixture",
          createdAt: .distantPast))
      }.execute(db)
      if hasArtifact {
        try Artifact.insert {
          Artifact.Draft(Artifact(
            id: UUID(), transport: .gmail, acquiredAt: .distantPast,
            providerProvenance: provenanceText, contentPieceID: id))
        }.execute(db)
      }
    }
  }
}
