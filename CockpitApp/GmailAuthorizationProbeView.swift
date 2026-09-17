import CockpitCore
import GoogleSignIn
import GoogleSignInSwift
import Observation
import Dependencies
import SQLiteData
import SwiftUI
import UIKit

@MainActor
@Observable
final class GmailAuthorizationProbe {
  enum Status: Equatable, Sendable {
    case ready
    case authorizing
    case checkingStoredAuthorization
    case authorized(email: String)
    case failed(message: String)
  }

  private(set) var status = Status.ready

  func authorize(from presentingViewController: UIViewController) {
    status = .authorizing

    GIDSignIn.sharedInstance.signIn(
      withPresenting: presentingViewController,
      hint: nil,
      additionalScopes: ["https://www.googleapis.com/auth/gmail.modify"]
    ) { [weak self] result, error in
      let updatedStatus: Status
      if let error {
        updatedStatus = .failed(message: error.localizedDescription)
      } else if let result {
        updatedStatus = .authorized(email: result.user.profile?.email ?? "Google account")
      } else {
        updatedStatus = .failed(message: "Google returned no authorization result.")
      }

      MainActor.assumeIsolated {
        guard let self else { return }
        self.status = updatedStatus
      }
    }
  }

  /// Revalidates the Keychain-managed authorization without beginning an interactive sign-in.
  func checkStoredAuthorization() {
    status = .checkingStoredAuthorization
    GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
      guard let user else {
        let message = error?.localizedDescription ?? "No stored Google authorization was found."
        MainActor.assumeIsolated { self?.status = .failed(message: message) }
        return
      }
      user.refreshTokensIfNeeded { refreshedUser, refreshError in
        let updatedStatus: Status
        if let refreshError {
          updatedStatus = .failed(message: refreshError.localizedDescription)
        } else if let refreshedUser {
          updatedStatus = .authorized(email: refreshedUser.profile?.email ?? "Google account")
        } else {
          updatedStatus = .failed(message: "Google returned no refreshed authorization.")
        }
        MainActor.assumeIsolated { self?.status = updatedStatus }
      }
    }
  }
}

@MainActor
@Observable
final class GmailInboxIngestModel {
  enum Status: Equatable, Sendable {
    case ready
    case ingesting
    case ingested(GmailInboxIngestReport)
    case failed(message: String)
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  private(set) var status = Status.ready

  func ingestCurrentInbox() async {
    status = .ingesting
    do {
      let accessToken = try await authorizedAccessToken()
      let report = try await GmailInboxIngestor(
        client: .live(accessToken: accessToken), treatmentProcessor: EmailTreatmentProcessor()
      ).ingest(into: database)
      status = .ingested(report)
    } catch is CancellationError {
      status = .ready
    } catch {
      status = .failed(message: error.localizedDescription)
    }
  }

  /// Restores and refreshes the stored authorization, returning only the `Sendable` access token.
  /// The non-`Sendable` `GIDGoogleUser` never crosses the continuation boundary.
  private func authorizedAccessToken() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
        guard let user else {
          continuation.resume(throwing: error ?? GmailInboxIngestError.missingAuthorization)
          return
        }
        user.refreshTokensIfNeeded { refreshedUser, refreshError in
          if let refreshedUser {
            continuation.resume(returning: refreshedUser.accessToken.tokenString)
          } else {
            continuation.resume(throwing: refreshError ?? GmailInboxIngestError.missingToken)
          }
        }
      }
    }
  }
}

private enum GmailInboxIngestError: LocalizedError {
  case missingAuthorization
  case missingToken

  var errorDescription: String? {
    switch self {
    case .missingAuthorization: "No stored Google authorization was found."
    case .missingToken: "Google returned no refreshed Gmail access token."
    }
  }
}

struct GmailAuthorizationProbeView: View {
  let probe: GmailAuthorizationProbe
  @State private var inboxIngest = GmailInboxIngestModel()

  var body: some View {
    Form {
      Section {
        Text("This one-off viability probe requests Gmail modification access. It does not read, change, or send any mail.")
      } header: {
        Text("Gmail authorization")
      }

      Section {
        switch probe.status {
        case .ready:
          Button("Check stored authorization", systemImage: "checkmark.shield") {
            probe.checkStoredAuthorization()
          }
          GoogleSignInButton { authorize() }
        case .authorizing:
          HStack {
            ProgressView()
            Text("Waiting for Google authorization…")
          }
        case .checkingStoredAuthorization:
          HStack {
            ProgressView()
            Text("Checking stored authorization…")
          }
        case let .authorized(email):
          Label("Authorized for \(email)", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        case let .failed(message):
          Text(message)
            .foregroundStyle(.red)
          GoogleSignInButton { authorize() }
        }
      }

      Section {
        switch inboxIngest.status {
        case .ready:
          Button("Read Current Inbox", systemImage: "tray.and.arrow.down") {
            Task { await inboxIngest.ingestCurrentInbox() }
          }
        case .ingesting:
          HStack {
            ProgressView()
            Text("Reading Inbox…")
          }
        case let .ingested(report):
          Label(
            "Read \(report.messageCount) \(report.messageCount == 1 ? "message" : "messages")",
            systemImage: "checkmark.circle.fill"
          )
          .foregroundStyle(.green)
          Text("\(report.accountID) · \(report.pageCount) \(report.pageCount == 1 ? "page" : "pages")")
            .font(.caption)
            .foregroundStyle(.secondary)
        case let .failed(message):
          Text(message)
            .foregroundStyle(.red)
          Button("Try Again") {
            Task { await inboxIngest.ingestCurrentInbox() }
          }
        }
      } header: {
        Text("Read-only Inbox ingest")
      } footer: {
        Text("Cockpit reads the current Inbox, creates local provider Artifacts and email ContentPieces, and does not change Gmail state.")
      }
    }
    .navigationTitle("Gmail Probe")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func authorize() {
    guard let presentingViewController = UIApplication.shared.activeRootViewController else {
      probe.reportMissingPresentationContext()
      return
    }
    probe.authorize(from: presentingViewController)
  }
}

private extension GmailAuthorizationProbe {
  func reportMissingPresentationContext() {
    status = .failed(message: "Cockpit could not find a window to present Google authorization.")
  }
}

private extension UIApplication {
  var activeRootViewController: UIViewController? {
    connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?
      .windows
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}
