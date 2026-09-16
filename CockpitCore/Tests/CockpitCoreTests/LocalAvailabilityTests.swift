@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.dependencies {
  try $0.bootstrapDatabase()
  $0.date.now = Date(timeIntervalSince1970: 123)
})
@MainActor
struct LocalAvailabilityTests {
  @Dependency(\.defaultDatabase) var database

  @Test("Offline until retains locally held substance and exposes its visible expiry")
  func offlineUntil() async throws {
    let id = UUID(9401)
    let expiry = Date(timeIntervalSince1970: 2_592_123)
    try await seedText("Held reading", for: id)

    let model = ContentPieceReaderModel(contentPieceID: id)
    try await model.$content.load()
    await model.keepOffline(until: expiry)

    expectNoDifference(model.offlinePresentation, .offlineUntil(expiry))
    let availability = try await database.read { db in
      try LocalAvailability.find(id).fetchOne(db)
    }
    expectNoDifference(availability?.mode, .until)
    expectNoDifference(availability?.expiresAt, expiry)
    expectNoDifference(availability?.verifiedAt, Date(timeIntervalSince1970: 123))
    let heldText = try await database.read { db in
      try NormalizedTextOperations.text(for: id, in: db)
    }
    expectNoDifference(heldText, "Held reading")
  }

  @Test("Keep Offline is indefinite until explicitly released")
  func pinnedUntilRelease() async throws {
    let id = UUID(9402)
    try await seedText("Held reading", for: id)
    let model = ContentPieceReaderModel(contentPieceID: id)
    try await model.$content.load()

    await model.keepOffline()
    expectNoDifference(model.offlinePresentation, .keptOffline)
    let pinned = try await database.read { db in try LocalAvailability.find(id).fetchOne(db) }
    expectNoDifference(pinned?.mode, .pinned)
    #expect(pinned?.expiresAt == nil)

    await model.releaseOffline()
    expectNoDifference(model.offlinePresentation, .ordinaryCache)
    let released = try await database.read { db in try LocalAvailability.find(id).fetchOne(db) }
    #expect(released == nil)
  }

  @Test("Cache eviction preserves every active offline promise")
  func evictionProtectsPromises() async throws {
    let cacheID = UUID(9403)
    let untilID = UUID(9404)
    let pinnedID = UUID(9405)
    let expiry = Date(timeIntervalSince1970: 2_592_123)
    try await database.write { db in
      try LocalAvailability.insert {
        LocalAvailability.Draft(
          contentPieceID: cacheID, mode: .cache, expiresAt: nil, verifiedAt: .distantPast,
          payloadRef: "cache-payload")
      }.execute(db)
      try LocalAvailability.insert {
        LocalAvailability.Draft(
          contentPieceID: untilID, mode: .until, expiresAt: expiry, verifiedAt: .distantPast,
          payloadRef: "until-payload")
      }.execute(db)
      try LocalAvailability.insert {
        LocalAvailability.Draft(
          contentPieceID: pinnedID, mode: .pinned, expiresAt: nil, verifiedAt: .distantPast,
          payloadRef: "pinned-payload")
      }.execute(db)
      try NormalizedTextOperations.store("Text must not be evicted.", for: untilID, in: db)
    }

    try await database.write { db in
      try LocalAvailabilityOperations.evictAutomaticPayloads(
        at: Date(timeIntervalSince1970: 123), in: db)
    }

    let state = try await database.read { db in
      (
        try LocalAvailability.find(cacheID).fetchOne(db),
        try LocalAvailability.find(untilID).fetchOne(db),
        try LocalAvailability.find(pinnedID).fetchOne(db),
        try NormalizedTextOperations.text(for: untilID, in: db)
      )
    }
    expectNoDifference(state.0?.mode, .cache)
    #expect(state.0?.payloadRef == nil)
    expectNoDifference(state.1?.payloadRef, "until-payload")
    expectNoDifference(state.2?.payloadRef, "pinned-payload")
    expectNoDifference(state.3, "Text must not be evicted.")
  }

  @Test("A lapsed promise becomes ordinary cache without losing normalized text")
  func lapsedPromiseDegradesHonestly() async throws {
    let id = UUID(9406)
    let expiry = Date(timeIntervalSince1970: 122)
    try await seedText("Still useful normalized text", for: id)
    try await database.write { db in
      try LocalAvailability.insert {
        LocalAvailability.Draft(
          contentPieceID: id, mode: .until, expiresAt: expiry, verifiedAt: .distantPast,
          payloadRef: "expired-payload")
      }.execute(db)
    }
    let model = ContentPieceReaderModel(contentPieceID: id)
    try await model.$content.load()
    expectNoDifference(model.offlinePresentation, .expired(expiry))

    try await database.write { db in
      try LocalAvailabilityOperations.evictAutomaticPayloads(
        at: Date(timeIntervalSince1970: 123), in: db)
    }
    try await model.$content.load()
    expectNoDifference(model.offlinePresentation, .ordinaryCache)
    let retained = try await database.read { db in
      (
        try LocalAvailability.find(id).fetchOne(db),
        try NormalizedTextOperations.text(for: id, in: db)
      )
    }
    expectNoDifference(retained.0?.mode, .cache)
    #expect(retained.0?.payloadRef == nil)
    expectNoDifference(retained.1, "Still useful normalized text")
  }

  @Test("Reader refuses an offline promise it cannot honestly keep")
  func unavailableSubstanceDoesNotCreatePromise() async throws {
    let id = UUID(9407)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: id, kind: .article, title: "No local substance", publisher: "Publisher",
          createdAt: .distantPast)
      }.execute(db)
    }
    let model = ContentPieceReaderModel(contentPieceID: id)
    try await model.$content.load()

    await model.keepOffline()

    expectNoDifference(
      model.errorMessage,
      LocalAvailabilityOperations.Failure.substanceUnavailable.localizedDescription
    )
    let availability = try await database.read { db in try LocalAvailability.find(id).fetchOne(db) }
    #expect(availability == nil)
  }

  private func seedText(_ text: String, for id: ContentPiece.ID) async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: id, kind: .article, title: "Piece", publisher: "Publisher",
          isSubstantivePrimary: true, bodyCompleteness: .full, createdAt: .distantPast)
      }.execute(db)
      try NormalizedTextOperations.store(text, for: id, in: db)
    }
  }
}
