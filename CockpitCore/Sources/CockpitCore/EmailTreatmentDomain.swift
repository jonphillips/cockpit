import SQLiteData

/// The presentation treatment for Gmail-backed input. This is a routing tag, not an importance
/// score: every email remains visible and Today chooses how to render each tag.
public enum EmailTreatment: String, Codable, QueryBindable, CaseIterable, Sendable {
  case personal
  case newsletter
  case offer
  case grabBag = "grab-bag"
  case transactional

  public var displayName: String {
    switch self {
    case .personal: "Personal"
    case .newsletter: "Newsletter"
    case .offer: "Offer"
    case .grabBag: "Grab-bag"
    case .transactional: "Transactional"
    }
  }
}

/// Transactional sub-kinds carry deterministic handling posture for a future explicit disposition
/// policy. They are routing facts, never authority to act on Gmail by themselves.
public enum EmailTransactionalKind: String, Codable, QueryBindable, Sendable {
  case reference
  case ephemeral
  case finance
  case shipment
}
