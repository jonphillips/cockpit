import Foundation
import Observation

@MainActor
@Observable
public final class MorningPrep {
  public static let unattendedBudget: Duration = .seconds(20)
  public static let mailFreshness: TimeInterval = 5 * 60
  public static let feedsFreshness: TimeInterval = 30 * 60

  public internal(set) var records: [MorningPrepRun]
  public internal(set) var days: [MorningPrepDay]
  public internal(set) var isRunning = false
  public internal(set) var scheduleFailure: String?

  let client: MorningPrepClient
  let scheduler: MorningPrepSchedulerClient
  let scheduleStore: MorningPrepScheduleStore
  let store: MorningPrepRecordStore
  let now: @Sendable () -> Date
  let calendar: @Sendable () -> Calendar
  let monotonicNow: @Sendable () -> ContinuousClock.Instant
  var activeTask: Task<MorningPrepRun, Never>?
  var activeTrigger: MorningPrepTrigger?
  var activeID: UUID?
  /// The one follow-up started after the run `joinedID` finished; later waiters on that run join it.
  var followUp: (joinedID: UUID, task: Task<MorningPrepRun, Never>)?

  public init(
    client: MorningPrepClient,
    scheduler: MorningPrepSchedulerClient = .init(schedule: { _ in }),
    scheduleStore: MorningPrepScheduleStore = .live(),
    store: MorningPrepRecordStore = .live(),
    now: @escaping @Sendable () -> Date = Date.init,
    calendar: @escaping @Sendable () -> Calendar = { .current },
    monotonicNow: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now }
  ) {
    self.client = client
    self.scheduler = scheduler
    self.scheduleStore = scheduleStore
    self.store = store
    self.now = now
    self.calendar = calendar
    self.monotonicNow = monotonicNow
    self.scheduleFailure = scheduleStore.failure
    self.records = store.records.map { run in
      guard run.state == .running else { return run }
      var interrupted = run
      interrupted.state = .interrupted
      store.save(interrupted, now: now())
      return interrupted
    }
    self.days = store.days
  }

  public func run(_ request: MorningPrepRequest) async -> MorningPrepRun {
    if request.trigger == .backgroundRefresh { await scheduleNextRefresh() }
    if let activeTask, let activeID {
      let joinedID = activeID
      let joinedTrigger = activeTrigger
      let existing = await activeTask.value
      if let followUp, followUp.joinedID == joinedID { return await followUp.task.value }
      // Another waiter may already have started the one shared follow-up operation.
      if self.activeID != nil, self.activeID != joinedID { return await run(request) }
      let needsPolicyPass = joinedTrigger?.isUnattended == true && request.trigger.appliesPolicies
      let bypassSkippedFreshData = !request.trigger.skipsFreshData &&
        (existing.mail == .skippedFresh || existing.feeds == .skippedFresh)
      if needsPolicyPass || bypassSkippedFreshData {
        return await start(request, following: joinedID)
      }
      return existing
    }
    if request.trigger == .backgroundRefresh, let ready = readyUnattendedRun(at: now()) {
      return ready
    }
    return await start(request)
  }

  public func recordOpen(at date: Date? = nil, calendar: Calendar = .current) {
    store.recordFirstOpen(at: date ?? now(), calendar: calendar)
    days = store.days
  }

  public func readyRun(on day: MorningPrepDay) -> MorningPrepRun? {
    records.first { run in
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(identifier: day.timeZoneID) ?? .current
      guard run.trigger.isUnattended, run.state == .finished, let end = run.endedAt,
        calendar.isDate(end, inSameDayAs: day.firstOpenAt), end < day.firstOpenAt,
        calendar.component(.hour, from: end) >= 4,
        run.mail == .skippedFresh || ifSynced(run.mail),
        case .completed(_, _)? = run.feeds
      else { return false }
      return true
    }
  }

  private func ifSynced(_ mail: MorningPrepMailResult?) -> Bool {
    if case .synced = mail { return true }
    return false
  }

}
