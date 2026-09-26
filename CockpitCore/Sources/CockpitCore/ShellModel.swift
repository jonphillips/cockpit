import Foundation
import Observation

/// The app-level navigation state. Feature models own their own data and detail selection; this
/// model owns only the four primary destinations and Settings' nested routes.
@MainActor
@Observable
public final class ShellModel {
  public enum Destination: String, CaseIterable, Hashable, Sendable {
    case today
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

  /// Pops only while `route` is still on top, so a late async completion can't pop the screen
  /// beneath it after Jon has already navigated back.
  public func popSettings(ifShowing route: SettingsRoute) {
    guard settingsPath.last == route else { return }
    settingsPath.removeLast()
  }

  public func popToSettingsRoot() {
    settingsPath.removeAll()
  }
}

/// Payload-bearing Settings destinations stay in one explicit, testable route type. `You` can
/// optionally open a specific claim once M3's stewardship work makes that affordance real.
public enum SettingsRoute: Hashable, Sendable {
  case following
  case subfeedRouting
  case streamHandling(streamID: UUID)
  case interestAreas
  case personalKnowledge(claimID: UUID?)
  case ai
  case pendingFinds
  case reader(contentPieceID: UUID)
  case gmailAuthorizationProbe
}
