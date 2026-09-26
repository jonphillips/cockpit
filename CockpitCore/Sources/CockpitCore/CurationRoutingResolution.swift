import SQLiteData

/// The locator and rule that currently resolve one ContentPiece's surface route. The locator is
/// still returned when no rule exists so an explicit Reader correction can create the rule at the
/// same identity CurationRouting would use for the piece.
public struct CurationRoutingResolution: Equatable, Sendable {
  public let locator: String?
  public let rule: ContentRoleRoutingRule?
  private let isTransactional: Bool
  private let unconfiguredRole: ContentRole

  public init(
    locator: String?, rule: ContentRoleRoutingRule?, isTransactional: Bool = false,
    unconfiguredRole: ContentRole = .forYou
  ) {
    self.locator = locator
    self.rule = rule
    self.isTransactional = isTransactional
    self.unconfiguredRole = unconfiguredRole
  }

  public var role: ContentRole? {
    if isTransactional { return .transactional }
    guard let rule else { return locator == nil ? nil : unconfiguredRole }
    return rule.isRouted ? rule.role : nil
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
    let isTransactional = try ContentPiece.find(contentPieceID).fetchOne(db)?.emailTreatment
      == .transactional
    let candidates = artifacts.flatMap { artifact in
      routeCandidates(for: artifact, stream: artifact.streamID.flatMap { streamsByID[$0] })
    }.sorted(by: routeCandidatePrecedes)

    guard let candidate = candidates.first else {
      return CurationRoutingResolution(
        locator: nil, rule: nil, isTransactional: isTransactional)
    }
    if let matched = candidates.compactMap({ candidate in
      matchingRule(for: candidate.locator, in: rules).map { (candidate, $0) }
    }).first {
      return CurationRoutingResolution(
        locator: canonicalLocator(matched.0.locator), rule: matched.1,
        isTransactional: isTransactional)
    }
    return CurationRoutingResolution(
      locator: canonicalLocator(candidate.locator), rule: nil, isTransactional: isTransactional,
      unconfiguredRole: defaultsPromotionsToOffers(for: candidates) ? .offers : .forYou)
  }
}
