import SQLiteData

/// The explicit sender corrections that keep mail in the Transactional treatment.
public struct TransactionalCorrectionRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var senders: [String] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.senders = try EmailSenderTreatmentOverride
      .where { $0.treatment.eq(EmailTreatment.transactional) }
      .select { $0.senderKey }
      .order { $0.senderKey }
      .fetchAll(db)
    return value
  }
}
