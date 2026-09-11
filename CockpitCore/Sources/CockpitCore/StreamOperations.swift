import Foundation
import SQLiteData

public struct StreamDraft: Equatable, Identifiable, Sendable {
  public var id: UUID?
  public var name: String
  public var publisher: String
  public var transport: StreamTransport
  public var locator: String
  public var interestAreaName: String
  public var handlingGuidance: String
  public var isEssential: Bool

  public init(
    id: UUID? = nil,
    name: String = "",
    publisher: String = "",
    transport: StreamTransport = .rss,
    locator: String = "",
    interestAreaName: String = "General",
    handlingGuidance: String = "",
    isEssential: Bool = false
  ) {
    self.id = id
    self.name = name
    self.publisher = publisher
    self.transport = transport
    self.locator = locator
    self.interestAreaName = interestAreaName
    self.handlingGuidance = handlingGuidance
    self.isEssential = isEssential
  }
}

public enum StreamOperations {
  public enum Failure: Error, Equatable, Sendable {
    case missingStream
    case missingRequiredField
  }

  public static func activeStreams(in db: Database) throws -> [Stream] {
    try Stream.where { $0.followState.eq(StreamFollowState.active) }
      .order { $0.id }
      .fetchAll(db)
  }

  public static func save(
    _ draft: StreamDraft,
    streamID: Stream.ID,
    interestAreaID: InterestArea.ID,
    in db: Database
  ) throws {
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let publisher = draft.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
    let locator = draft.locator.trimmingCharacters(in: .whitespacesAndNewlines)
    let interestAreaName = draft.interestAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !publisher.isEmpty, !locator.isEmpty, !interestAreaName.isEmpty else {
      throw Failure.missingRequiredField
    }

    let interestArea = try matchingInterestArea(named: interestAreaName, in: db)
      ?? InterestArea(id: interestAreaID, name: interestAreaName)
    if try InterestArea.find(interestArea.id).fetchOne(db) == nil {
      try InterestArea.insert { InterestArea.Draft(interestArea) }.execute(db)
    }

    if let id = draft.id {
      guard try Stream.find(id).fetchOne(db) != nil else { throw Failure.missingStream }
      try Stream.find(id)
        .update {
          $0.name = #bind(name)
          $0.publisher = #bind(publisher)
          $0.interestAreaID = #bind(interestArea.id)
          $0.transport = #bind(draft.transport)
          $0.locator = #bind(locator)
          $0.handlingGuidance = #bind(draft.handlingGuidance)
          $0.isEssential = #bind(draft.isEssential)
        }
        .execute(db)
    } else {
      try Stream.insert {
        Stream.Draft(
          Stream(
            id: streamID,
            name: name,
            publisher: publisher,
            interestAreaID: interestArea.id,
            transport: draft.transport,
            locator: locator,
            handlingGuidance: draft.handlingGuidance,
            isEssential: draft.isEssential
          )
        )
      }.execute(db)
    }
  }

  public static func setFollowState(
    _ followState: StreamFollowState,
    for streamID: Stream.ID,
    in db: Database
  ) throws {
    guard try Stream.find(streamID).fetchOne(db) != nil else { throw Failure.missingStream }
    try Stream.find(streamID).update { $0.followState = #bind(followState) }.execute(db)
  }

  public static func insertSeedsIfMissing(in db: Database) throws {
    let interestArea = StreamSeed.interestArea
    if try InterestArea.find(interestArea.id).fetchOne(db) == nil {
      try InterestArea.insert { InterestArea.Draft(interestArea) }.execute(db)
    }
    for stream in StreamSeed.streams where try Stream.find(stream.id).fetchOne(db) == nil {
      try Stream.insert { Stream.Draft(stream) }.execute(db)
    }
  }

  private static func matchingInterestArea(named name: String, in db: Database) throws -> InterestArea? {
    try InterestArea.all.fetchAll(db)
      .filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
      .sorted { $0.id.uuidString < $1.id.uuidString }
      .first
  }
}

public enum StreamSeed {
  public static let interestArea = InterestArea(
    id: UUID(uuidString: "2A8B00F4-994B-4ED9-9703-70E81975CC31")!,
    name: "Technology & Making"
  )

  public static let streams: [Stream] = [
    Stream(
      id: UUID(uuidString: "107C6C54-D4AA-44B1-98C2-53471AD91D95")!,
      name: "Slow Boring",
      publisher: "Matthew Yglesias",
      interestAreaID: interestArea.id,
      transport: .rss,
      locator: "https://www.slowboring.com/feed",
      handlingGuidance: "Treat Slow Boring as a writer I generally want available rather than a publication to filter aggressively. Brief the thesis enough that I can decide whether to read now, later, or skip. Elevate an issue when it strongly intersects with an existing Interest, but do not infer that skipping an issue means I no longer care about the writer/topic."
    ),
    Stream(
      id: UUID(uuidString: "6FF0BB87-74D5-4204-BB22-3248DDDF6FD1")!,
      name: "Astral Codex Ten",
      publisher: "Scott Alexander",
      interestAreaID: interestArea.id,
      transport: .rss,
      locator: "https://www.astralcodexten.com/feed",
      handlingGuidance: "Brief substantive essays enough to decide whether to read and screen community/announcement-style posts much more aggressively. Do not treat every post from the same publication as equally valuable merely because the sender is high-signal."
    ),
    Stream(
      id: UUID(uuidString: "B7A28B6E-BD34-4D12-9E6D-A8E63A99A3A4")!,
      name: "Techmeme",
      publisher: "Techmeme",
      interestAreaID: interestArea.id,
      transport: .rss,
      locator: "https://www.techmeme.com/feed.xml",
      handlingGuidance: "Screen the technology stories for developments that materially intersect with my current interests—especially AI capabilities, developer tooling, Apple/mobile platforms, and changes that could affect the app family. Routine industry deal/news churn can stay suppressed. When a platform release could expand an actual harness, surface it with the concrete reason it matters."
    ),
    Stream(
      id: UUID(uuidString: "65D970B1-AC82-40FE-9F3B-A9C71E6BEAD5")!,
      name: "Point-Free",
      publisher: "Point-Free",
      interestAreaID: interestArea.id,
      transport: .rss,
      locator: "https://www.pointfree.co/feed/episodes.xml",
      handlingGuidance: "Treat Point-Free as an architecture/tooling source relevant to patterns actually used in the app family. Surface library changes, techniques, or releases that could materially improve our current architecture. Do not surface every product update merely because we use Point-Free libraries. Explain the concrete seam or problem a new capability might affect."
    ),
    Stream(
      id: UUID(uuidString: "D489292C-C1BA-4F9F-824F-A749C4847D8F")!,
      name: "Benedict Evans",
      publisher: "Benedict Evans",
      interestAreaID: interestArea.id,
      transport: .rss,
      locator: "https://www.ben-evans.com/benedictevans?format=RSS",
      handlingGuidance: "Screen the newsletter for AI/platform/technology analysis that is unusually relevant to my current thinking. Preserve the high-level argument when it is useful, but avoid surfacing every industry link. If a contained item changes the practical capability landscape for my apps, elevate it separately."
    ),
  ]
}
