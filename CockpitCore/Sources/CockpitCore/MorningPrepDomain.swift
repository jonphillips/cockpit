import Foundation
import Synchronization

public enum MorningPrepTrigger: String, Codable, Sendable {
  case open
  case manual
  case manualPrepare
  case automation
  case backgroundRefresh

  var isUnattended: Bool { self == .automation || self == .backgroundRefresh }
  var appliesPolicies: Bool { self == .open || self == .manual }
  var skipsFreshData: Bool { self != .manual && self != .manualPrepare }
}

public struct MorningPrepRequest: Sendable {
  public let trigger: MorningPrepTrigger
  public let timeBudget: Duration?

  public init(trigger: MorningPrepTrigger, timeBudget: Duration? = nil) {
    self.trigger = trigger
    self.timeBudget = timeBudget
  }
}

public enum MorningPrepMailResult: Codable, Equatable, Sendable {
  case synced(Int)
  case skippedFresh
  case notAuthorized
  case failed(String)
  case outOfTime
}

public enum MorningPrepFeedsResult: Codable, Equatable, Sendable {
  case completed(succeeded: Int, attempted: Int)
  case skippedFresh
  case outOfTime
}

public enum MorningPrepSummariesResult: Codable, Equatable, Sendable {
  case completed(done: Int, waiting: Int)
  case skipped
  case outOfTime
}

public struct MorningPrepRun: Codable, Equatable, Identifiable, Sendable {
  public enum State: String, Codable, Sendable { case running, finished, interrupted }

  public let id: UUID
  public let trigger: MorningPrepTrigger
  public let startedAt: Date
  public var endedAt: Date?
  public var state: State
  public var mail: MorningPrepMailResult?
  public var feeds: MorningPrepFeedsResult?
  public var summaries: MorningPrepSummariesResult?

  public init(
    id: UUID = UUID(), trigger: MorningPrepTrigger, startedAt: Date,
    endedAt: Date? = nil, state: State = .running,
    mail: MorningPrepMailResult? = nil, feeds: MorningPrepFeedsResult? = nil,
    summaries: MorningPrepSummariesResult? = nil
  ) {
    self.id = id
    self.trigger = trigger
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.state = state
    self.mail = mail
    self.feeds = feeds
    self.summaries = summaries
  }
}

public struct MorningPrepDay: Codable, Equatable, Sendable {
  public let day: String
  public let timeZoneID: String
  public let firstOpenAt: Date

  public init(day: String, timeZoneID: String, firstOpenAt: Date) {
    self.day = day
    self.timeZoneID = timeZoneID
    self.firstOpenAt = firstOpenAt
  }
}

/// Device-local history. Only trigger, timing, and step outcomes are retained; no content or
/// provider identifiers enter this store.
public struct MorningPrepRecordStore: Sendable {
  private let loadRecords: @Sendable () -> [MorningPrepRun]
  private let saveRecords: @Sendable ([MorningPrepRun]) -> Void
  private let loadDays: @Sendable () -> [MorningPrepDay]
  private let saveDays: @Sendable ([MorningPrepDay]) -> Void

  public init(
    loadRecords: @escaping @Sendable () -> [MorningPrepRun],
    saveRecords: @escaping @Sendable ([MorningPrepRun]) -> Void,
    loadDays: @escaping @Sendable () -> [MorningPrepDay] = { [] },
    saveDays: @escaping @Sendable ([MorningPrepDay]) -> Void = { _ in }
  ) {
    self.loadRecords = loadRecords
    self.saveRecords = saveRecords
    self.loadDays = loadDays
    self.saveDays = saveDays
  }

  public var records: [MorningPrepRun] { loadRecords() }
  public var days: [MorningPrepDay] { loadDays() }

  public func save(_ run: MorningPrepRun, now: Date) {
    var records = loadRecords().filter { now.timeIntervalSince($0.startedAt) < 14 * 24 * 60 * 60 }
    if let index = records.firstIndex(where: { $0.id == run.id }) { records[index] = run }
    else { records.append(run) }
    saveRecords(records.sorted { $0.startedAt > $1.startedAt })
  }

  public func recordFirstOpen(at date: Date, calendar inputCalendar: Calendar = .current) {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone
    guard let fourAM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: date), date >= fourAM else { return }
    let day = calendar.startOfDay(for: date)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    let key = formatter.string(from: day)
    var days = loadDays()
    guard !days.contains(where: { $0.day == key && $0.timeZoneID == calendar.timeZone.identifier }) else { return }
    days.append(MorningPrepDay(day: key, timeZoneID: calendar.timeZone.identifier, firstOpenAt: date))
    saveDays(days.sorted { $0.firstOpenAt > $1.firstOpenAt }.prefix(14).map { $0 })
  }

  public static func live(defaults: UserDefaults = .standard) -> Self {
    let defaults = MorningPrepDefaults(defaults)
    return Self(
      loadRecords: {
        guard let data = defaults.value.data(forKey: "cockpit.morningPrep.runs") else { return [] }
        return (try? JSONDecoder().decode([MorningPrepRun].self, from: data)) ?? []
      },
      saveRecords: { value in
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.value.set(data, forKey: "cockpit.morningPrep.runs")
      },
      loadDays: {
        guard let data = defaults.value.data(forKey: "cockpit.morningPrep.days") else { return [] }
        return (try? JSONDecoder().decode([MorningPrepDay].self, from: data)) ?? []
      },
      saveDays: { value in
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.value.set(data, forKey: "cockpit.morningPrep.days")
      }
    )
  }

  public static func inMemory() -> Self {
    let records = Mutex<[MorningPrepRun]>([])
    let days = Mutex<[MorningPrepDay]>([])
    return Self(
      loadRecords: { records.withLock { $0 } },
      saveRecords: { newValue in records.withLock { $0 = newValue } },
      loadDays: { days.withLock { $0 } },
      saveDays: { newValue in days.withLock { $0 = newValue } }
    )
  }
}

private final class MorningPrepDefaults: @unchecked Sendable {
  let value: UserDefaults
  init(_ value: UserDefaults) { self.value = value }
}

public struct MorningPrepClient: Sendable {
  public var lastMailSync: @Sendable () async throws -> Date?
  public var syncMail: @Sendable () async throws -> Int
  public var applyPolicies: @Sendable () async -> Void
  public var lastFeedPoll: @Sendable () async throws -> Date?
  public var pollFeeds: @Sendable (_ maximumConcurrent: Int, _ totalTimeout: Duration) async -> (succeeded: Int, attempted: Int)
  public var processOffers: @Sendable (_ maximum: Int) async -> (done: Int, waiting: Int)

  public init(
    lastMailSync: @escaping @Sendable () async throws -> Date?,
    syncMail: @escaping @Sendable () async throws -> Int,
    applyPolicies: @escaping @Sendable () async -> Void = {},
    lastFeedPoll: @escaping @Sendable () async throws -> Date?,
    pollFeeds: @escaping @Sendable (Int, Duration) async -> (succeeded: Int, attempted: Int),
    processOffers: @escaping @Sendable (Int) async -> (done: Int, waiting: Int)
  ) {
    self.lastMailSync = lastMailSync
    self.syncMail = syncMail
    self.applyPolicies = applyPolicies
    self.lastFeedPoll = lastFeedPoll
    self.pollFeeds = pollFeeds
    self.processOffers = processOffers
  }
}
public enum MorningPrepAuthorizationError: Error { case notAuthorized }
