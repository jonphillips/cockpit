import Foundation
import Observation
import SwiftNavigation

/// The app-level navigation state. Feature models own their own data and detail selection; this
/// model owns only the five primary destinations and Settings' nested routes.
@MainActor
@Observable
public final class ShellModel {
  public enum Destination: String, CaseIterable, Hashable, Sendable {
    case today
    case edition
    case later
    case library
    case settings

    public var title: String { rawValue.capitalized }
  }

  public var selection: Destination = .today
  public var settingsPath: [SettingsRoute] = []

  public init() {}

  public func select(_ destination: Destination) {
    selection = destination
  }

  public func pushSettings(_ route: SettingsRoute) {
    selection = .settings
    settingsPath.append(route)
  }

  public func popSettings() {
    guard !settingsPath.isEmpty else { return }
    settingsPath.removeLast()
  }

  public func popToSettingsRoot() {
    settingsPath.removeAll()
  }
}

/// Payload-bearing Settings destinations stay in one explicit, testable route type. `You` can
/// optionally open a specific claim once M3's stewardship work makes that affordance real.
@CaseBindable
public enum SettingsRoute: Hashable, Sendable {
  case following
  case interestAreas
  case personalKnowledge(claimID: UUID?)
  case ai
  case pendingFinds
  case gmailAuthorizationProbe
}
