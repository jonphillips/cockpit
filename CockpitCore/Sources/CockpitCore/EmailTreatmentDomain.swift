import SQLiteData

/// The presentation treatment for Gmail-backed input. This is a routing tag, not an importance
/// score: every email remains visible and Today chooses how to render each tag.
public enum EmailTreatment: String, Codable, QueryBindable, CaseIterable, Sendable {
  case personal
  case newsletter
  case offer
  case grabBag = "grab-bag"
  case transactional
}

/// The only transactional distinction Cockpit currently needs is whether a notice is still useful
/// as reference material or has already gone stale. This is a routing fact for a future explicit
/// disposition policy, never authority to act on Gmail by itself.
public enum EmailTransactionalKind: String, Codable, QueryBindable, Sendable {
  case reference
  case ephemeral
}
