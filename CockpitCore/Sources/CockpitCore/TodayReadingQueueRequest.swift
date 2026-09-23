import Foundation
import SQLiteData

/// The ordered reading queue for Today. The queue is a projection rather than persisted state:
/// content role determines its section boundary while ContentPiece, Stream, Artifact, and Edition
/// remain authoritative.
public struct TodayReadingQueueRequest: FetchKeyRequest {
  public init() {}
}

extension TodayReadingQueueRequest {
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let summary: String?
    public let role: ContentRole
    public let arrivedAt: Date
    public let isGmailSource: Bool
    public let isFollowedStreamPiece: Bool
    public let streamID: Stream.ID?
    public let streamName: String?
    public let editionEntryID: EditionEntry.ID?
    public let editionRationale: String?
    public let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?

    public init(
      id: ContentPiece.ID,
      title: String,
      publisher: String,
      summary: String? = nil,
      role: ContentRole,
      arrivedAt: Date,
      isGmailSource: Bool = false,
      isFollowedStreamPiece: Bool = false,
      streamID: Stream.ID? = nil,
      streamName: String? = nil,
      editionEntryID: EditionEntry.ID? = nil,
      editionRationale: String? = nil,
      matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID? = nil
    ) {
      self.id = id
      self.title = title
      self.publisher = publisher
      self.summary = summary
      self.role = role
      self.arrivedAt = arrivedAt
      self.isGmailSource = isGmailSource
      self.isFollowedStreamPiece = isFollowedStreamPiece
      self.streamID = streamID
      self.streamName = streamName
      self.editionEntryID = editionEntryID
      self.editionRationale = editionRationale
      self.matchedPersonalKnowledgeClaimID = matchedPersonalKnowledgeClaimID
    }

    public var sourceLabel: String {
      if let streamName, !streamName.isEmpty { return streamName }
      return SenderDisplayName.make(from: publisher)
    }
  }
}

extension TodayReadingQueueRequest {
  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []

    public init(rows: [Row] = []) {
      self.rows = rows
    }
  }
}

private struct TodayReadingQueueFetchInputs {
  let pieces: [ContentPiece]
  let artifactsByContentPieceID: [ContentPiece.ID: [Artifact]]
  let streamByID: [Stream.ID: Stream]
  let routing: CurationRoutingSnapshot
  let clearedIDs: Set<ContentPiece.ID>
  let disposedIDs: Set<ContentPiece.ID>
  let editionEntryByContentPieceID: [ContentPiece.ID: EditionEntry]

  init(db: Database) throws {
    let artifacts = try Artifact.all.fetchAll(db)
    let streams = try Stream.all.fetchAll(db)
    streamByID = Dictionary(uniqueKeysWithValues: streams.map { ($0.id, $0) })
    pieces = try ContentPiece.all.fetchAll(db)
    routing = try CurationRouting.snapshot(in: db)
    clearedIDs = Set(try TodayAttention.all.fetchAll(db).map(\.contentPieceID))

    let activeProviderIDs = Set(
      try GmailDispositionLogEntry.where { $0.reversedAt.is(nil) }.fetchAll(db).map(\.providerID))
    disposedIDs = Set(artifacts.compactMap { artifact -> ContentPiece.ID? in
      guard let providerID = artifact.providerID,
        activeProviderIDs.contains(providerID),
        let contentPieceID = artifact.contentPieceID
      else { return nil }
      return contentPieceID
    })

    let currentEditionID = try Edition.order { $0.date.desc() }.fetchOne(db)?.id
    let activeEntries: [EditionEntry] = if let currentEditionID {
      try EditionEntry.where {
        $0.editionID.eq(currentEditionID)
          && ($0.entryState.eq(EditionEntryState.admitted) || $0.entryState.eq(EditionEntryState.seen))
      }.fetchAll(db)
    } else {
      []
    }
    editionEntryByContentPieceID = Dictionary(
      activeEntries.map { ($0.contentPieceID, $0) }, uniquingKeysWith: { first, _ in first })
    artifactsByContentPieceID = Dictionary(grouping: artifacts.compactMap { artifact in
      artifact.contentPieceID.map { ($0, artifact) }
    }, by: \.0).mapValues { $0.map(\.1) }
  }
}

extension TodayReadingQueueRequest {
  public func fetch(_ db: Database) throws -> Value {
    let inputs = try TodayReadingQueueFetchInputs(db: db)
    let rows = inputs.pieces.compactMap { row(for: $0, inputs: inputs) }
    return Value(rows: ReadingQueueOrdering.ordered(rows))
  }

  private func row(for piece: ContentPiece, inputs: TodayReadingQueueFetchInputs) -> Row? {
    let pieceArtifacts = inputs.artifactsByContentPieceID[piece.id] ?? []
    let isGmailSource = pieceArtifacts.contains { $0.transport == .gmail }
    let followedStream = inputs.routing.followedGmailStreamContentPieceIDs.contains(piece.id)
    let editionEntry = inputs.editionEntryByContentPieceID[piece.id]
    let routedRole = inputs.routing.role(for: piece.id)
    if isGmailSource
      && (inputs.clearedIDs.contains(piece.id) || inputs.disposedIDs.contains(piece.id))
    {
      return nil
    }
    // TodayRequest requires a resolved role for Gmail material. Keep the split reader on the same
    // membership boundary instead of defaulting an unrouted Gmail piece into a blank detail path.
    guard !isGmailSource || routedRole != nil else { return nil }
    guard !inputs.routing.mutedContentPieceIDs.contains(piece.id),
      isGmailSource || editionEntry != nil
    else { return nil }

    let streamID = pieceArtifacts.compactMap(\.streamID)
      .first(where: { inputs.streamByID[$0]?.followState == .active })
    return Row(
      id: piece.id,
      title: piece.title,
      publisher: piece.publisher,
      summary: piece.summary,
      role: routedRole ?? editionRole(for: editionEntry?.section),
      arrivedAt: ReceivedDate.resolve(
        publishedAt: piece.publishedAt,
        artifactAcquiredAt: pieceArtifacts.map(\.acquiredAt).max(),
        createdAt: piece.createdAt
      ),
      isGmailSource: isGmailSource,
      isFollowedStreamPiece: followedStream,
      streamID: streamID,
      streamName: streamID.flatMap { inputs.streamByID[$0]?.name },
      editionEntryID: editionEntry?.id,
      editionRationale: editionEntry?.rationale,
      matchedPersonalKnowledgeClaimID: editionEntry?.matchedPersonalKnowledgeClaimID
    )
  }

  private func editionRole(for section: JudgmentSection?) -> ContentRole {
    switch section {
    case .interestArea: .dailyNews
    case .forYou, .essentials, .essentialBacklog, nil: .forYou
    }
  }
}

/// Shared ordering for the orientation's sections and the reading surface's single queue.
public enum ReadingQueueOrdering {
  public static func ordered(_ rows: [TodayReadingQueueRequest.Row]) -> [TodayReadingQueueRequest.Row] {
    rows.sorted {
      if $0.role.sortOrder != $1.role.sortOrder { return $0.role.sortOrder < $1.role.sortOrder }
      if $0.arrivedAt != $1.arrivedAt { return $0.arrivedAt > $1.arrivedAt }
      return $0.id.uuidString < $1.id.uuidString
    }
  }
}
