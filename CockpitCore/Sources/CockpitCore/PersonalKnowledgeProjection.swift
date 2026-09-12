import Foundation

/// The model-facing representation of current, explicitly taught knowledge. It is generated
/// from canonical rows for each use and is never itself a durable source of truth.
public struct PersonalKnowledgeProjection: Equatable, Sendable {
  public let text: String
  public let includedClaimIDs: [PersonalKnowledgeClaim.ID]
  public let isFullSet: Bool

  public init(text: String, includedClaimIDs: [PersonalKnowledgeClaim.ID], isFullSet: Bool) {
    self.text = text
    self.includedClaimIDs = includedClaimIDs
    self.isFullSet = isFullSet
  }
}

public enum PersonalKnowledgeProjector {
  public static let fullSetThreshold = 150

  public static func project(
    _ claims: [PersonalKnowledgeClaim],
    relevantTo subjects: [String] = []
  ) -> PersonalKnowledgeProjection {
    let current = claims.filter { $0.status == .current }
    let included: [PersonalKnowledgeClaim]
    if current.count <= fullSetThreshold {
      included = current
    } else {
      let subjectTokens = Set(subjects.flatMap(tokens(in:)))
      included = current.filter { claim in
        !subjectTokens.isEmpty && !subjectTokens.isDisjoint(with: Set(tokens(in: claim.claim + " " + (claim.scope ?? ""))))
      }
    }
    let ordered = included.sorted {
      ($0.kind.rawValue, $0.createdAt, $0.id.uuidString) < ($1.kind.rawValue, $1.createdAt, $1.id.uuidString)
    }
    let text = PersonalKnowledgeKind.allCases.compactMap { kind -> String? in
      let lines = ordered.filter { $0.kind == kind }.map { claim in
        let scope = claim.scope.map { " [Scope: \($0)]" } ?? ""
        return "- \(claim.claim)\(scope)"
      }
      guard !lines.isEmpty else { return nil }
      return "\(kind.displayName):\n\(lines.joined(separator: "\n"))"
    }.joined(separator: "\n\n")

    return PersonalKnowledgeProjection(
      text: text,
      includedClaimIDs: ordered.map(\.id),
      isFullSet: current.count <= fullSetThreshold
    )
  }

  private static func tokens(in text: String) -> [String] {
    text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
  }
}
