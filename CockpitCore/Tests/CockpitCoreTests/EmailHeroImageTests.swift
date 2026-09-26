@testable import CockpitCore
import Dependencies
import Foundation
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    try $0.bootstrapDatabase()
  }
)
struct EmailHeroImageTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Skips a tracking pixel and selects a declared wide hero")
  func trackingPixelBeforeHero() {
    let url = EmailHeroImage.candidate(inHTML: """
      <img width="1" height="1" src="https://tracker.example/open.gif">
      <img width="600" height="400" src="https://cdn.example/hero.jpg">
      """)

    #expect(url?.absoluteString == "https://cdn.example/hero.jpg")
  }

  @Test("Drops a small logo before choosing an undeclared-width hero")
  func logoBeforeUndeclaredHero() {
    let url = EmailHeroImage.candidate(inHTML: """
      <img width="120" alt="Publisher logo" src="https://cdn.example/logo.png">
      <img src="https://cdn.example/product.jpg" alt="Bottle">
      """)

    #expect(url?.absoluteString == "https://cdn.example/product.jpg")
  }

  @Test("Skips HTTP images")
  func skipsHTTP() {
    #expect(EmailHeroImage.candidate(inHTML: "<img width='600' src='http://cdn.example/hero.jpg'>") == nil)
  }

  @Test("Returns nil when only social icons remain")
  func skipsSocialIcons() {
    let url = EmailHeroImage.candidate(inHTML: """
      <img width="600" src="https://cdn.example/social.png" alt="Share">
      <img width="600" class="facebook-button" src="https://cdn.example/share.jpg">
      """)

    #expect(url == nil)
  }

  @Test("Skips hidden images")
  func skipsHidden() {
    let url = EmailHeroImage.candidate(inHTML: """
      <img width="600" style="display: none" src="https://cdn.example/hidden.jpg">
      """)

    #expect(url == nil)
  }

  @Test("Returns nil when there are no images")
  func noImages() {
    #expect(EmailHeroImage.candidate(inHTML: "<p>Offer details</p>") == nil)
  }

  @Test("Prefers the first remaining declared width of at least 300 pixels")
  func declaredWidthPriority() {
    let url = EmailHeroImage.candidate(inHTML: """
      <img width="180" src="https://cdn.example/small.jpg">
      <img style="width: 320px" src="https://cdn.example/wide-first.jpg">
      <img width="640" src="https://cdn.example/wide-second.jpg">
      """)

    #expect(url?.absoluteString == "https://cdn.example/wide-first.jpg")
    #expect(EmailHeroImage.candidate(inHTML: """
      <img width="180" src="https://cdn.example/small.jpg">
      <img src="https://cdn.example/unknown.jpg">
      """) == nil)
  }

  @Test("Reads the newest Gmail Artifact source HTML")
  func readsLatestGmailArtifact() async throws {
    let pieceID = UUID(19_501)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Offer", publisher: "Sender", createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(19_502), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 1),
          rawSourceText: "<img src='https://cdn.example/old.jpg'>", contentPieceID: pieceID))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(19_503), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 2),
          rawSourceText: "<img src='https://cdn.example/new.jpg'>", contentPieceID: pieceID))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(19_504), transport: .rss, acquiredAt: Date(timeIntervalSince1970: 3),
          rawSourceText: "<img src='https://cdn.example/rss.jpg'>", contentPieceID: pieceID))
      }.execute(db)
    }

    let url = try await database.read { db in
      try OfferHeroImageOperations.url(for: pieceID, in: db)
    }

    #expect(url?.absoluteString == "https://cdn.example/new.jpg")
  }
}
