import Foundation
import SQLiteData

struct RouteCandidate {
  let locator: String
  let priority: Int
  let artifactID: Artifact.ID
}

private func normalizedRule(_ rule: ContentRoleRoutingRule) -> ContentRoleRoutingRule {
  ContentRoleRoutingRule(
    locator: CurationRouting.canonicalLocator(rule.locator), role: rule.role,
    isFollowed: rule.isFollowed, isMuted: rule.isMuted)
}

func normalizedSeededRules() -> [String: ContentRoleRoutingRule] {
  Dictionary(uniqueKeysWithValues: CurationRouting.seededRules.map {
    let rule = normalizedRule($0)
    return (rule.locator, rule)
  })
}

func routeCandidates(
  for artifact: Artifact, stream: Stream?
) -> [RouteCandidate] {
  var candidates: [RouteCandidate] = []
  // Explicit Stream routing wins over message-level evidence. A publisher-wide Stream locator
  // must not be seeded for a pick-apart publisher; its distinct List-IDs are what preserve the
  // D-C split into Daily news, Opinion, and muted feeds.
  if let streamLocator = stream?.locator {
    candidates.append(RouteCandidate(
      locator: streamLocator, priority: 0, artifactID: artifact.id))
  }
  if artifact.transport == .gmail,
    let provenanceText = artifact.providerProvenance,
    let provenance = try? JSONDecoder().decode(
      GmailArtifactProvenance.self, from: Data(provenanceText.utf8)) {
    // List-ID is the series identity. Sender is retained as the fallback when List-ID is absent,
    // matching GmailSeriesKey.seriesKey exactly.
    if let listID = provenance.listID {
      candidates.append(RouteCandidate(
        locator: listID, priority: 1, artifactID: artifact.id))
    }
    if let sender = provenance.senderAddress {
      candidates.append(RouteCandidate(
        locator: sender, priority: 2, artifactID: artifact.id))
    }
  }
  if let canonicalURL = artifact.canonicalURL {
    candidates.append(RouteCandidate(
      locator: canonicalURL, priority: 3, artifactID: artifact.id))
  }
  return candidates
}

func routeCandidatePrecedes(_ lhs: RouteCandidate, _ rhs: RouteCandidate) -> Bool {
  if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
  let lhsLocator = lhs.locator.lowercased()
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let rhsLocator = rhs.locator.lowercased()
    .trimmingCharacters(in: .whitespacesAndNewlines)
  if lhsLocator != rhsLocator { return lhsLocator < rhsLocator }
  return lhs.artifactID.uuidString < rhs.artifactID.uuidString
}

func matchingRule(
  for locator: String, in rules: [String: ContentRoleRoutingRule]
) -> ContentRoleRoutingRule? {
  // locatorKeys returns a Set because aliases are equivalent. Sort it before lookup so an
  // overlapping future rule cannot make the result depend on Set iteration order.
  for key in GmailSeriesKey.locatorKeys(locator).sorted() {
    if let rule = rules[key] { return rule }
  }
  return nil
}

/// The locator and rule that currently resolve one ContentPiece's surface route. The locator is
/// still returned when no rule exists so an explicit Reader correction can create the rule at the
/// same identity CurationRouting would use for the piece.
public struct CurationRoutingResolution: Equatable, Sendable {
  public let locator: String?
  public let rule: ContentRoleRoutingRule?

  public init(locator: String?, rule: ContentRoleRoutingRule?) {
    self.locator = locator
    self.rule = rule
  }

  public var role: ContentRole? {
    guard let rule else { return locator == nil ? nil : .forYou }
    return rule.isRouted ? rule.role : nil
  }
}

/// The current surface role of ContentPieces. This is deliberately derived from configured
/// locators rather than from transport, treatment, or sender alone: the same publisher can fan
/// into multiple roles while a Gmail message can remain loose Primary mail.
public struct CurationRoutingSnapshot: Sendable {
  public let followedGmailStreamContentPieceIDs: Set<ContentPiece.ID>
  /// Gmail ContentPieces that remain in Today's loose Primary triage. This includes artifacts
  /// with no Stream and artifacts linked to a paused or stopped Stream: only an active Stream is
  /// currently a followed Stream for routing purposes. Keep that state decision explicit here so
  /// a future paused-Stream policy is not hidden by the old `primary` name.
  public let todayTriageGmailContentPieceIDs: Set<ContentPiece.ID>

  /// The resolved surface role for each ContentPiece with an Artifact. A missing value means the
  /// piece is muted by its locator rule. Unconfigured locators resolve to `.forYou`.
  public let roleByContentPieceID: [ContentPiece.ID: ContentRole]
  public let mutedContentPieceIDs: Set<ContentPiece.ID>
  public let routingRules: [String: ContentRoleRoutingRule]
  /// Gmail locators seen on ingested ContentPieces that still fall through to `.forYou`.
  /// These are intentionally observations only; saving one as a rule remains an explicit user
  /// action in Settings.
  public let discoveredLocators: [DiscoveredLocator]

  /// Both Gmail roles stay outside the uncurated Edition tail. S-b supplies the Stream Handling
  /// surface for the first role; Today owns the second.
  public var editionExcludedContentPieceIDs: Set<ContentPiece.ID> {
    followedGmailStreamContentPieceIDs.union(todayTriageGmailContentPieceIDs)
  }

  public func role(for contentPieceID: ContentPiece.ID) -> ContentRole? {
    roleByContentPieceID[contentPieceID]
  }
}

/// A Gmail sub-feed that has been observed but has no seeded or explicit routing rule yet.
public struct DiscoveredLocator: Equatable, Identifiable, Sendable {
  public let locator: String
  public let displayLabel: String
  public let pieceCount: Int

  public var id: String { locator }

  public init(locator: String, displayLabel: String, pieceCount: Int) {
    self.locator = locator
    self.displayLabel = displayLabel
    self.pieceCount = pieceCount
  }
}

public enum CurationRouting {
  /// The first deterministic routing table. It is intentionally small and locator-based: a
  /// publisher can fan out into multiple roles when its List-IDs are distinct, while a publisher
  /// that has not been split yet falls back to `.forYou` until a later classifier is justified.
  public static let seededRules: [ContentRoleRoutingRule] = [
    ContentRoleRoutingRule(
      locator: "list.washingtonpost.com/morning", role: .dailyNews),
    ContentRoleRoutingRule(
      locator: "list.washingtonpost.com/evening", role: .dailyNews),
    ContentRoleRoutingRule(
      locator: "list.washingtonpost.com/opinions", role: .opinion),
    ContentRoleRoutingRule(
      locator: "list.washingtonpost.com/food", role: .food),
    ContentRoleRoutingRule(
      locator: "substack.com/slowboring", role: .opinion),
    ContentRoleRoutingRule(
      locator: "nl.nytimes.com/morning", role: .dailyNews),
    ContentRoleRoutingRule(
      locator: "e.nordstrom.com", role: .offers),
    ContentRoleRoutingRule(
      locator: "substack.com/emilysundberg", role: .grabBag),
  ]

  /// The single canonical locator normalizer shared with Gmail Stream resolution and series
  /// identity. A List-ID display form becomes its bracketed value; ordinary locators are trimmed
  /// and lowercased. This is the identity used by persisted user edits.
  public static func canonicalLocator(_ locator: String) -> String {
    GmailSeriesKey.normalizedListID(locator)
      ?? locator.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  /// Returns seeded rules overlaid by durable user edits. The overlay is intentionally narrow:
  /// it changes only the route for a known locator and does not become a sender reputation store.
  public static func effectiveRules(in db: Database) throws -> [ContentRoleRoutingRule] {
    var rules = normalizedSeededRules()
    let persistedRules = try ContentRoleRoutingRule.all.fetchAll(db)
    for persistedRule in persistedRules.sorted(by: { $0.locator < $1.locator }) {
      let rule = normalizedRule(persistedRule)
      rules[rule.locator] = rule
    }
    return rules.values.sorted { $0.locator < $1.locator }
  }

  public static func snapshot(in db: Database) throws -> CurationRoutingSnapshot {
    // One ordered Artifact read supplies both Gmail curation membership and role-routing evidence.
    // ContentPiece identity can converge across several Artifacts, so role resolution happens once
    // per ContentPiece below rather than once per Artifact.
    let artifacts = try Artifact.all.fetchAll(db).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let gmailArtifacts = artifacts.filter { $0.transport == .gmail }
    let gmailContentPieceIDs = Set(gmailArtifacts.compactMap(\.contentPieceID))

    let activeGmailStreamIDs = try Stream
      .where {
        $0.transport.eq(StreamTransport.gmail)
          && $0.followState.eq(StreamFollowState.active)
      }
      .select(\.id)
      .fetchAll(db)
    let activeGmailStreamIDSet = Set(activeGmailStreamIDs)
    var followedGmailStreamContentPieceIDs = Set<ContentPiece.ID>()
    for artifact in gmailArtifacts {
      guard let streamID = artifact.streamID,
        activeGmailStreamIDSet.contains(streamID),
        let contentPieceID = artifact.contentPieceID
      else { continue }
      followedGmailStreamContentPieceIDs.insert(contentPieceID)
    }

    let streamsByID = Dictionary(
      uniqueKeysWithValues: try Stream.all.fetchAll(db).map { ($0.id, $0) })
    let rules = Dictionary(uniqueKeysWithValues: try effectiveRules(in: db).map {
      ($0.locator, $0)
    })
    var candidatesByContentPieceID: [ContentPiece.ID: [RouteCandidate]] = [:]
    for artifact in artifacts {
      guard let contentPieceID = artifact.contentPieceID else { continue }
      let stream = artifact.streamID.flatMap { streamsByID[$0] }
      candidatesByContentPieceID[contentPieceID, default: []].append(contentsOf: routeCandidates(
        for: artifact, stream: stream))
    }

    var roleByContentPieceID: [ContentPiece.ID: ContentRole] = [:]
    var mutedContentPieceIDs = Set<ContentPiece.ID>()
    for (contentPieceID, candidates) in candidatesByContentPieceID {
      let rule = candidates
        .sorted(by: routeCandidatePrecedes)
        .compactMap { matchingRule(for: $0.locator, in: rules) }
        .first
      guard let rule else {
        roleByContentPieceID[contentPieceID] = .forYou
        continue
      }
      if rule.isRouted {
        roleByContentPieceID[contentPieceID] = rule.role
      } else {
        mutedContentPieceIDs.insert(contentPieceID)
      }
    }

    let discoveredLocators = try discoveredGmailLocators(
      in: db, artifacts: gmailArtifacts, rules: rules, streamsByID: streamsByID)

    return CurationRoutingSnapshot(
      followedGmailStreamContentPieceIDs: followedGmailStreamContentPieceIDs,
      todayTriageGmailContentPieceIDs: gmailContentPieceIDs.subtracting(followedGmailStreamContentPieceIDs),
      roleByContentPieceID: roleByContentPieceID,
      mutedContentPieceIDs: mutedContentPieceIDs,
      routingRules: rules,
      discoveredLocators: discoveredLocators
    )
  }
}

extension CurationRouting {
  /// Resolves the same ordered locator candidates used by `snapshot` for one ContentPiece. This is
  /// the Reader-facing seam for editing a route without introducing a second locator policy.
  public static func resolution(
    for contentPieceID: ContentPiece.ID, in db: Database
  ) throws -> CurationRoutingResolution {
    let artifacts = try Artifact.where { $0.contentPieceID.eq(contentPieceID) }
      .fetchAll(db)
      .sorted { $0.id.uuidString < $1.id.uuidString }
    let streamsByID = Dictionary(
      uniqueKeysWithValues: try Stream.all.fetchAll(db).map { ($0.id, $0) })
    let rules = Dictionary(uniqueKeysWithValues: try effectiveRules(in: db).map {
      ($0.locator, $0)
    })
    let candidates = artifacts.flatMap { artifact in
      routeCandidates(for: artifact, stream: artifact.streamID.flatMap { streamsByID[$0] })
    }.sorted(by: routeCandidatePrecedes)

    guard let candidate = candidates.first else {
      return CurationRoutingResolution(locator: nil, rule: nil)
    }
    if let matched = candidates.compactMap({ candidate in
      matchingRule(for: candidate.locator, in: rules).map { (candidate, $0) }
    }).first {
      return CurationRoutingResolution(
        locator: canonicalLocator(matched.0.locator), rule: matched.1)
    }
    return CurationRoutingResolution(locator: canonicalLocator(candidate.locator), rule: nil)
  }

}
