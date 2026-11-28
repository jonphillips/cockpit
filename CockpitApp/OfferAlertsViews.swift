import CockpitCore
import SwiftUI
import UIKit
import UserNotifications

struct OfferAlertsSettingsView: View {
  let model: OfferAlertsModel
  @State private var copied = false

  var body: some View {
    List {
      Section {
        LabeledContent("APNs environment", value: model.environment.capitalized)
        if let token = model.deviceToken {
          Text(token).font(.caption.monospaced()).textSelection(.enabled)
          Button(copied ? "Copied" : "Copy device token") {
            UIPasteboard.general.string = token
            copied = true
          }
        } else {
          Text("No device token yet").foregroundStyle(.secondary)
        }
        if let message = model.registrationError {
          Text(message).font(.caption).foregroundStyle(.secondary)
        }
        Button(model.registration == .enabled ? "Refresh registration" : "Enable offer alerts") {
          Task {
            await model.enableTapped(
              requestPermission: {
                (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
              },
              registerForRemoteNotifications: {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
              })
          }
        }
      } footer: {
        Text("Paste this token and environment into Offer Watch on your Mac. Notification permission is requested only when you choose Enable offer alerts.")
      }
    }
    .navigationTitle("Offer alerts")
    .task {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      await model.authorizationDidChange(
        authorized: settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
        loadPersistedToken: { UserDefaults.standard.string(forKey: "offerWatch.deviceToken") },
        registerForRemoteNotifications: {
          await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        })
    }
  }
}

struct OfferAlertMessageView: View {
  let messageID: String
  let model: ShellModel
  let offerAlerts: OfferAlertsModel

  var body: some View {
    Group {
      if case let .found(foundContentPieceID) = offerAlerts.messageResolution {
        ContentUnavailableView {
          Label("Opening message", systemImage: "envelope.open")
        } description: {
          Text("The Gmail message is available in Cockpit.")
        }
        .task {
          model.popSettings(ifShowing: .offerAlert(messageID: messageID))
          model.pushSettings(.reader(contentPieceID: foundContentPieceID))
        }
      } else {
        switch offerAlerts.messageResolution {
        case .resolving:
          ProgressView("Finding message…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .idle, .absent:
          ContentUnavailableView {
            Label("Message not synced", systemImage: "envelope.badge")
          } description: {
            Text("This Gmail message is not available in Cockpit yet. Open it in Gmail, then retry after syncing.")
          } actions: {
            HStack {
              if OfferAlertsModel.isValidMessageID(messageID),
                let url = URL(string: "https://mail.google.com/mail/u/0/#all/\(messageID)") {
                Link("Open in Gmail", destination: url)
              }
              Button("Retry") { Task { await resolve(retrySync: true) } }
            }
          }
          .navigationTitle("Offer alert")
        case .found:
          EmptyView()
        }
      }
    }
    .task { await resolve(retrySync: true) }
  }

  private func resolve(retrySync: Bool) async {
    await offerAlerts.resolveMessage(
      messageID: messageID, syncMail: { try await MorningPrepWiring.syncMailOnce() }, retrySync: retrySync)
  }
}
