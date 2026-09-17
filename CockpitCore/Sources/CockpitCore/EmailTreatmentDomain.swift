import SQLiteData

/// The presentation treatment for Gmail-backed input. This is a routing tag, not an importance
/// score: every email remains visible and Today chooses how to render each tag.
public enum EmailTreatment: String, Codable, QueryBindable, CaseIterable, Sendable {
  case personal
  case newsletter
  case offer
  case grabBag = "grab-bag"
}
