import Synchronization

final class EmailTreatmentProcessingCursor: @unchecked Sendable {
  let value = Mutex<Int>(0)
}
