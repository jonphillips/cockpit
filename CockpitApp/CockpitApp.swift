import CockpitCore
import Dependencies
import GoogleSignIn
import GoogleSignInSwift
import Observation
import SQLiteData
import SwiftUI
import UIKit

@main
struct CockpitApp: App {
  init() {
    prepareDependencies {
      try! $0.bootstrapDatabase()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentPieceDebugList()
        .onOpenURL { url in
          _ = GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}

struct ContentPieceDebugList: View {
  @Selection struct Row: Identifiable {
    let id: ContentPiece.ID
    let title: String
    let publisher: String
    let publishedAt: Date?
    let streamName: String?
  }

  @FetchAll(
    ContentPiece
      .order { $0.publishedAt.desc() }
      .group(by: \.id)
      .leftJoin(Artifact.all) { $1.contentPieceID.eq($0.id) }
      .leftJoin(CockpitCore.Stream.all) { $1.streamID.eq($2.id) }
      .select {
        Row.Columns(
          id: $0.id,
          title: $0.title,
          publisher: $0.publisher,
          publishedAt: $0.publishedAt,
          streamName: $2.name
        )
      }
  ) private var rows

  @State private var gmailAuthorizationProbe = GmailAuthorizationProbe()
  @State private var isPresentingGmailAuthorizationProbe = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(rows) { row in
          VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
              .font(.headline)
            Text(row.publisher)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            HStack {
              Text(row.publishedAt ?? .distantPast, format: .dateTime.year().month().day())
              Text(row.streamName ?? "Unknown stream")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .overlay {
        if rows.isEmpty {
          ContentUnavailableView(
            "No Content Pieces",
            systemImage: "newspaper",
            description: Text("Ingested RSS and Atom entries appear here for inspection.")
          )
        }
      }
      .navigationTitle("Content Pieces")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Gmail authorization probe", systemImage: "envelope.badge") {
            isPresentingGmailAuthorizationProbe = true
          }
          .accessibilityLabel("Gmail authorization probe")
        }
      }
      .sheet(isPresented: $isPresentingGmailAuthorizationProbe) {
        GmailAuthorizationProbeView(probe: gmailAuthorizationProbe)
      }
    }
  }
}

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
