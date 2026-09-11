import GoogleSignIn
import GoogleSignInSwift
import Observation
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

struct GmailAuthorizationProbeView: View {
  @Environment(\.dismiss) private var dismiss
  let probe: GmailAuthorizationProbe

  var body: some View {
    NavigationStack {
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
      }
      .navigationTitle("Gmail Probe")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
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
