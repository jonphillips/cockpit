import AppIntents
import CockpitCore

@available(iOS 26.0, *)
struct PrepareCockpitIntent: AppIntent {
  static let title: LocalizedStringResource = "Prepare Cockpit"
  static let description = IntentDescription("Refresh mail and feeds for Cockpit.")
  static var supportedModes: IntentModes { .background }
  static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
  static var allowedExecutionTargets: IntentExecutionTargets { .main }

  func perform() async throws -> some IntentResult {
    let task = await MainActor.run {
      Task { await MorningPrepWiring.shared.run(.init(trigger: .automation, timeBudget: .seconds(20))) }
    }
    let run = await task.value
    let failed: Bool
    if case .notAuthorized? = run.mail { failed = true }
    else if case .failed? = run.mail { failed = true }
    else if case .outOfTime? = run.mail { failed = true }
    else if case .outOfTime? = run.feeds { failed = true }
    else { failed = false }
    return failed ? .result(dialog: "Cockpit couldn't finish") : .result(dialog: "Cockpit is ready")
  }
}

@available(iOS 26.0, *)
struct CockpitShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PrepareCockpitIntent(),
      phrases: ["Prepare \(.applicationName)"],
      shortTitle: "Prepare Cockpit",
      systemImageName: "sunrise"
    )
  }
}
