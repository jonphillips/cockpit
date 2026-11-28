import CockpitCore
import SwiftUI
import UIKit
import UserNotifications

struct OfferAlertsSettingsView: View {
  let model: OfferAlertsModel
  @State private var copied = false

  var body: some View {
    @Bindable var model = model
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
  }
}

struct OfferAlertMessageView: View {
  let messageID: String
  let model: ShellModel
  let offerAlerts: OfferAlertsModel
  @State private var foundContentPieceID: UUID?
  @State private var didAttemptIngest = false

  var body: some View {
    Group {
      if let foundContentPieceID {
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
    ContentUnavailableView {
      Label("Message not synced", systemImage: "envelope.badge")
    } description: {
      Text("This Gmail message is not available in Cockpit yet. Open it in Gmail, then return and retry after syncing.")
    } actions: {
      HStack {
        Link("Open in Gmail", destination: URL(string: "https://mail.google.com/mail/u/0/#all/\(messageID)")!)
        Button("Retry") { Task { await resolveMessage(ingestIfMissing: false) } }
      }
    }
    .navigationTitle("Offer alert")
      }
    }
    .task { await resolveMessage(ingestIfMissing: true) }
  }

  private func resolveMessage(ingestIfMissing: Bool) async {
    if let pieceID = await offerAlerts.contentPieceID(for: messageID) {
      foundContentPieceID = pieceID
      return
    }
    guard ingestIfMissing, !didAttemptIngest else { return }
    didAttemptIngest = true
    try? await MorningPrepWiring.syncMailOnce()
    foundContentPieceID = await offerAlerts.contentPieceID(for: messageID)
  }
}
