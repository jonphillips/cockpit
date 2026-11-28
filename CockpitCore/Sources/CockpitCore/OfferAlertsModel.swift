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
  public enum MessageResolution: Equatable, Sendable { case idle, resolving, found(UUID), absent }
  public private(set) var registration: Registration = .notRequested
  public private(set) var deviceToken: String?
  public private(set) var registrationError: String?
  public private(set) var pendingMessageID: String?
  public private(set) var messageResolution: MessageResolution = .idle
  public let environment: String
  private let lookupContentPiece: (@Sendable (String) async -> UUID?)?

  public init(environment: String, lookupContentPiece: (@Sendable (String) async -> UUID?)? = nil) {
    self.environment = environment
    self.lookupContentPiece = lookupContentPiece
  }

  public func notificationTapped(messageID: String) {
    guard Self.isValidMessageID(messageID) else { return }
    pendingMessageID = messageID
    messageResolution = .resolving
  }

  public func clearPendingTap() { pendingMessageID = nil }

  public func resolveMessage(
    messageID: String,
    syncMail: @Sendable () async throws -> Void,
    retrySync: Bool = false
  ) async {
    guard Self.isValidMessageID(messageID) else { messageResolution = .absent; return }
    messageResolution = .resolving
    if let id = await contentPieceID(for: messageID) { messageResolution = .found(id); return }
    if retrySync {
      try? await syncMail()
      if let id = await contentPieceID(for: messageID) { messageResolution = .found(id); return }
    }
    messageResolution = .absent
  }

  public static func isValidMessageID(_ value: String) -> Bool {
    !value.isEmpty && value.unicodeScalars.allSatisfy {
      (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value)
    }
  }

  public func authorizationDidChange(
    authorized: Bool,
    loadPersistedToken: @Sendable () async -> String?,
    registerForRemoteNotifications: @Sendable () async -> Void
  ) async {
    guard authorized else { return }
    if let token = await loadPersistedToken() { deviceToken = token }
    registration = .enabled
    await registerForRemoteNotifications()
  }

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
    UserDefaults.standard.set(deviceToken, forKey: "offerWatch.deviceToken")
    registrationError = nil
    registration = .enabled
  }

  public func didFailRegistration(_ message: String) {
    registration = .failed
    registrationError = message
  }

  public func contentPieceID(for messageID: String) async -> UUID? {
    if let lookupContentPiece { return await lookupContentPiece(messageID) }
    return try? await database.read { db in
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
