import Foundation
import SQLiteData

private struct DiscoveredLocatorEvidence {
  var pieceIDs = Set<ContentPiece.ID>()
  var displayLabel: String
}

enum RouteDecision {
  case role(ContentRole)
  case muted
  case unconfigured
}

func routeDecision(
  for contentPiece: ContentPiece?, candidates: [RouteCandidate],
  rules: [String: ContentRoleRoutingRule]
) -> RouteDecision {
  if contentPiece?.emailTreatment == .transactional {
    return .role(.transactional)
  }
  guard let rule = candidates
    .sorted(by: routeCandidatePrecedes)
    .compactMap({ matchingRule(for: $0.locator, in: rules) })
    .first
  else { return .unconfigured }
  return rule.isRouted ? .role(rule.role) : .muted
}

extension CurationRouting {
  public static func role(for locator: String) -> ContentRole? {
    let rules = normalizedSeededRules()
    guard let rule = matchingRule(for: locator, in: rules) else { return .forYou }
    return rule.isRouted ? rule.role : nil
  }
}

private func discoveredDisplayLabel(
  for contentPiece: ContentPiece, artifact: Artifact, stream: Stream?
) -> String {
  let directLabels = [contentPiece.publisher, contentPiece.creator, stream?.publisher, stream?.name]
  if let label = directLabels.compactMap({ $0?.trimmedNonEmpty }).first {
    return label
  }
  if let provenanceText = artifact.providerProvenance,
    let provenance = try? JSONDecoder().decode(
      GmailArtifactProvenance.self, from: Data(provenanceText.utf8)),
    let sender = provenance.senderAddress?.trimmedNonEmpty
  {
    return sender
  }
  return "Unknown sender"
}

/// Returns one deterministic, configurable locator for each Gmail ContentPiece that has no
/// matching seeded or explicit rule. The query is observational: it does not create routing rows.
func discoveredGmailLocators(
  in db: Database,
  artifacts: [Artifact],
  rules: [String: ContentRoleRoutingRule],
  streamsByID: [Stream.ID: Stream]
) throws -> [DiscoveredLocator] {
  let contentPiecesByID = Dictionary(
    uniqueKeysWithValues: try ContentPiece.all.fetchAll(db).map { ($0.id, $0) })
  let artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
  var candidatesByContentPieceID: [ContentPiece.ID: [RouteCandidate]] = [:]
  for artifact in artifacts where artifact.transport == .gmail {
    guard let contentPieceID = artifact.contentPieceID else { continue }
    let stream = artifact.streamID.flatMap { streamsByID[$0] }
    candidatesByContentPieceID[contentPieceID, default: []].append(contentsOf: routeCandidates(
      for: artifact, stream: stream))
  }

  var discoveredByLocator: [String: DiscoveredLocatorEvidence] = [:]
  for contentPieceID in candidatesByContentPieceID.keys.sorted(by: {
    $0.uuidString < $1.uuidString
  }) {
    guard let candidates = candidatesByContentPieceID[contentPieceID], !candidates.isEmpty,
      let contentPiece = contentPiecesByID[contentPieceID],
      contentPiece.emailTreatment != .transactional,
      candidates.allSatisfy({ matchingRule(for: $0.locator, in: rules) == nil }),
      let candidate = candidates.sorted(by: routeCandidatePrecedes).first,
      let artifact = artifactsByID[candidate.artifactID]
    else { continue }

    let locator = CurationRouting.canonicalLocator(candidate.locator)
    guard !locator.isEmpty else { continue }
    let stream = artifact.streamID.flatMap { streamsByID[$0] }
    let displayLabel = discoveredDisplayLabel(
      for: contentPiece, artifact: artifact, stream: stream)
    if var evidence = discoveredByLocator[locator] {
      evidence.pieceIDs.insert(contentPieceID)
      discoveredByLocator[locator] = evidence
    } else {
      discoveredByLocator[locator] = DiscoveredLocatorEvidence(
        pieceIDs: [contentPieceID], displayLabel: displayLabel)
    }
  }

  return discoveredByLocator.map { locator, evidence in
    DiscoveredLocator(
      locator: locator, displayLabel: evidence.displayLabel, pieceCount: evidence.pieceIDs.count)
  }.sorted { $0.locator < $1.locator }
}
