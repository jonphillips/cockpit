import Foundation
import Observation

/// The app-level navigation state. Feature models own their own data and detail selection; this
/// model owns only the five primary destinations and Settings' nested routes.
@MainActor
@Observable
public final class ShellModel {
  public enum Destination: String, CaseIterable, Hashable, Sendable {
    case today
    case process
    case later
    case library
    case settings

    public var title: String { rawValue.capitalized }
  }

  public var selection: Destination = .today
  public var settingsPath: [SettingsRoute] = []
  @ObservationIgnored private var processSelectionHandler: ((ContentPiece.ID?) -> Void)?

  public init() {}

  /// Connects the shell's Process route to the feature-owned queue selection without moving queue
  /// state into the shell itself.
  public func connectProcessSelection(_ handler: @escaping (ContentPiece.ID?) -> Void) {
    processSelectionHandler = handler
  }

  /// Opens Process at a specific piece when supplied. A nil piece deliberately preserves the
  /// queue's current selection.
  public func process(from contentPieceID: ContentPiece.ID?) {
    if let contentPieceID {
      processSelectionHandler?(contentPieceID)
    }
    selection = .process
  }

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
  case dailyLinks
  case reader(contentPieceID: UUID)
  case gmailAuthorizationProbe
}
