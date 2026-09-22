import SQLiteData

/// The surface section for a ContentPiece. This is deliberately separate from Gmail's
/// attention treatment and from Stream membership: delivery, treatment, and placement are
/// different axes.
public enum ContentRole: String, Codable, QueryBindable, CaseIterable, Hashable, Sendable {
  case forYou = "for-you"
  case dailyNews = "daily-news"
  case opinion
  case grabBag = "grab-bag"
  case offers

  public var displayName: String {
    switch self {
    case .forYou: "For you"
    case .dailyNews: "Daily news"
    case .opinion: "Opinion"
    case .grabBag: "Grab-bag"
    case .offers: "Offers"
    }
  }

  public var sortOrder: Int {
    switch self {
    case .forYou: 0
    case .dailyNews: 1
    case .opinion: 2
    case .grabBag: 3
    case .offers: 4
    }
  }
}

/// A deterministic locator rule. `role` records the intended destination even when a locator is
/// muted so Settings can later show the route that was silenced. Muted or unfollowed locators do
/// not produce a surface section.
public struct ContentRoleRoutingRule: Equatable, Sendable {
  public let locator: String
  public let role: ContentRole
  public let isFollowed: Bool
  public let isMuted: Bool

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
