import Dependencies
import Foundation
import Observation
import SQLiteData

/// The enabled policies, for a settings surface to reflect and toggle.
public struct GmailDispositionPolicyRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var enabledKinds: Set<GmailDispositionPolicyKind> = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.enabledKinds = Set(try GmailDispositionPolicyOperations.enabledKinds(in: db))
    return value
  }
}

/// Owns the establish/disable of the explicit disposition policies. Establishing a policy is the only
/// way one comes to exist, and it happens here only in response to an explicit user toggle — never
/// inferred (ADR-0002 D7; DECISIONS §8). Application itself lives in `GmailDispositionPolicyService`.
@MainActor
@Observable
public final class GmailDispositionPolicyModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(GmailDispositionPolicyRequest()) public var policies = .init()
  public var errorMessage: String?

  public init() {}

  public var allKinds: [GmailDispositionPolicyKind] { GmailDispositionPolicyKind.allCases }

  public func isEnabled(_ kind: GmailDispositionPolicyKind) -> Bool {
    policies.enabledKinds.contains(kind)
  }

  public func setEnabled(_ kind: GmailDispositionPolicyKind, _ enabled: Bool) async {
    let date = now
    do {
      try await database.write { db in
        if enabled {
          try GmailDispositionPolicyOperations.establish(kind, at: date, in: db)
        } else {
          try GmailDispositionPolicyOperations.setEnabled(kind, false, in: db)
        }
      }
      try await $policies.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
