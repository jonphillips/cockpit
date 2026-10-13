@MainActor
final class ReloadHandlerRegistration {
  weak var owner: AnyObject?
  let reload: @MainActor () async -> Void

  init(owner: AnyObject, reload: @escaping @MainActor () async -> Void) {
    self.owner = owner
    self.reload = reload
  }
}

@MainActor
final class BatchReference {
  weak var owner: AnyObject?
  let batchID: UUID

  init(owner: AnyObject, batchID: UUID) {
    self.owner = owner
    self.batchID = batchID
  }
}
import Foundation
