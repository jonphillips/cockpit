import Foundation
import Observation
import Dependencies
import SQLiteData

/// Device-local registration state for Offer Watch APNs pairing. The push token is never persisted
/// in Cockpit's synced database; Settings can show it again after APNs re-registers the device.
@MainActor
@Observable
public final class OfferAlertsModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  public enum Registration: Equatable, Sendable { case notRequested, denied, enabled, failed }
  public private(set) var registration: Registration = .notRequested
  public private(set) var deviceToken: String?
  public private(set) var registrationError: String?
  public let environment: String

  public init(environment: String) { self.environment = environment }

  public func enableTapped(
    requestPermission: @Sendable () async -> Bool,
    registerForRemoteNotifications: @Sendable () async -> Void
  ) async {
    guard await requestPermission() else { registration = .denied; return }
    registration = .enabled
    await registerForRemoteNotifications()
  }

  public func didRegister(deviceToken: String) {
    self.deviceToken = deviceToken
    registrationError = nil
    registration = .enabled
  }

  public func didFailRegistration(_ message: String) {
    registration = .failed
    registrationError = message
  }

  public func contentPieceID(for messageID: String) async -> UUID? {
    try? await database.read { db in
      let artifacts = try Artifact.where { $0.transport.eq(StreamTransport.gmail) }.fetchAll(db)
      for artifact in artifacts {
        guard let raw = artifact.providerProvenance, let data = raw.data(using: .utf8),
          let provenance = try? JSONDecoder().decode(GmailArtifactProvenance.self, from: data),
          provenance.messageID == messageID else { continue }
        return artifact.contentPieceID
      }
      return nil
    } ?? nil
  }
}
