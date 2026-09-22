import SQLiteData

/// The surface section for a ContentPiece. This is deliberately separate from Gmail's
/// attention treatment and from Stream membership: delivery, treatment, and placement are
/// different axes.
public enum ContentRole: String, Codable, QueryBindable, CaseIterable, Hashable, Sendable {
  case forYou = "for-you"
  case transactional
  case dailyNews = "daily-news"
  case opinion
  case grabBag = "grab-bag"
  case food = "food"
  case wine
  case offers

  public var displayName: String {
    switch self {
    case .forYou: "For you"
    case .transactional: "Transactional"
    case .dailyNews: "Daily news"
    case .opinion: "Opinion"
    case .grabBag: "Grab-bag"
    case .food: "Food"
    case .wine: "Wine"
    case .offers: "Offers"
    }
  }

  public var sortOrder: Int {
    switch self {
    case .forYou: 0
    case .transactional: 1
    case .dailyNews: 2
    case .opinion: 3
    case .grabBag: 4
    case .food: 5
    case .wine: 6
    case .offers: 7
    }
  }
}

/// A deterministic locator rule. `role` records the intended destination even when a locator is
/// muted so Settings can later show the route that was silenced. Muted or unfollowed locators do
/// not produce a surface section. The table stores only explicit edits; seeded defaults remain in
/// `CurationRouting` so adding a new seed does not require a data migration.
@Table("contentRoleRoutingRules")
public struct ContentRoleRoutingRule: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let locator: String
  public var role: ContentRole
  public var isFollowed: Bool
  public var isMuted: Bool

  public var id: String { locator }

  public init(
    locator: String, role: ContentRole, isFollowed: Bool = true, isMuted: Bool = false
  ) {
    self.locator = locator
    self.role = role
    self.isFollowed = isFollowed
    self.isMuted = isMuted
  }

  public var isRouted: Bool { isFollowed && !isMuted }
}
