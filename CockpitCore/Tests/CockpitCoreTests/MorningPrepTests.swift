@testable import CockpitCore
import Foundation
import Synchronization
import Testing

@Suite
@MainActor
struct MorningPrepTests {
  @Test("Freshness is checked separately and manual refresh bypasses both checks")
  func independentFreshness() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let mailCalls = Mutex(0)
    let feedCalls = Mutex(0)
    let client = MorningPrepClient(
      lastMailSync: { now.addingTimeInterval(-2 * 60) },
      syncMail: { mailCalls.withLock { $0 += 1 }; return 3 },
      lastFeedPoll: { now.addingTimeInterval(-31 * 60) },
      pollFeeds: { _, _ in feedCalls.withLock { $0 += 1 }; return (2, 3) },
      processOffers: { _ in (0, 0) }
    )
    let model = MorningPrep(client: client, store: .inMemory(), now: { now })

    let opened = await model.run(.init(trigger: .open))
    #expect(opened.mail == .skippedFresh)
    #expect(opened.feeds == .completed(succeeded: 2, attempted: 3))
    #expect(mailCalls.withLock { $0 } == 0)
    #expect(feedCalls.withLock { $0 } == 1)

    let manual = await model.run(.init(trigger: .manual))
    #expect(manual.mail == .synced(3))
    #expect(manual.feeds == .completed(succeeded: 2, attempted: 3))
    #expect(mailCalls.withLock { $0 } == 1)
    #expect(feedCalls.withLock { $0 } == 2)
  }

  @Test("Unattended refresh never applies policies and missing authorization does not stop feeds")
  func unattendedAuthorizationBoundary() async {
    let policyCalls = Mutex(0)
    let feedCalls = Mutex(0)
    let client = MorningPrepClient(
      lastMailSync: { nil },
      syncMail: { throw MorningPrepAuthorizationError.notAuthorized },
      applyPolicies: { policyCalls.withLock { $0 += 1 } },
      lastFeedPoll: { nil },
      pollFeeds: { _, _ in feedCalls.withLock { $0 += 1 }; return (1, 1) },
      processOffers: { _ in (0, 0) }
    )
    let model = MorningPrep(client: client, store: .inMemory())
    let run = await model.run(.init(trigger: .automation))

    #expect(run.mail == .notAuthorized)
    #expect(run.feeds == .completed(succeeded: 1, attempted: 1))
    #expect(policyCalls.withLock { $0 } == 0)
    #expect(feedCalls.withLock { $0 } == 1)
  }

  @Test("A completed step is retained when the deadline passes before the next step")
  func budgetStopsRemainingSteps() async {
    let feedCalls = Mutex(0)
    let summaryCalls = Mutex(0)
    let didFinishMail = Mutex(false)
    let instant = ContinuousClock().now
    let client = MorningPrepClient(
      lastMailSync: { nil },
      syncMail: { didFinishMail.withLock { $0 = true }; return 1 },
      lastFeedPoll: { nil },
      pollFeeds: { _, _ in feedCalls.withLock { $0 += 1 }; return (0, 0) },
      processOffers: { _ in summaryCalls.withLock { $0 += 1 }; return (0, 0) }
    )
    let model = MorningPrep(
      client: client, store: .inMemory(),
      monotonicNow: { didFinishMail.withLock { $0 } ? instant.advanced(by: .seconds(1)) : instant })
    let run = await model.run(.init(trigger: .automation, timeBudget: .milliseconds(10)))

    #expect(run.mail == .synced(1))
    #expect(run.feeds == .outOfTime)
    #expect(run.summaries == .outOfTime)
    #expect(feedCalls.withLock { $0 } == 0)
    #expect(summaryCalls.withLock { $0 } == 0)
  }

  @Test("Concurrent callers share one operation, and cancelling a waiter leaves it running")
  func singleFlightAndCancelledWaiter() async {
    let mailCalls = Mutex(0)
    let policyCalls = Mutex(0)
    let lastSync = Mutex<Date?>(nil)
    let gate = AsyncGate()
    let client = MorningPrepClient(
      lastMailSync: { lastSync.withLock { $0 } },
      syncMail: {
        mailCalls.withLock { $0 += 1 }
        await gate.pause()
        lastSync.withLock { $0 = Date() }
        return 1
      },
      applyPolicies: { policyCalls.withLock { $0 += 1 } },
      lastFeedPoll: { nil },
      pollFeeds: { _, _ in (1, 1) },
      processOffers: { _ in (0, 0) }
    )
    let model = MorningPrep(client: client, store: .inMemory())
    let first = Task { await model.run(.init(trigger: .automation)) }
    await gate.waitUntilEntered()
    let waiter = Task { await model.run(.init(trigger: .open)) }
    let secondWaiter = Task { await model.run(.init(trigger: .open)) }
    waiter.cancel()
    await Task.yield()
    await gate.release()
    _ = await first.value
    _ = await waiter.value
    _ = await secondWaiter.value

    #expect(mailCalls.withLock { $0 } == 1)
    #expect(policyCalls.withLock { $0 } == 1)
  }

  @Test("A failed mail attempt does not make a later unattended run fresh")
  func failedMailIsRetried() async {
    let calls = Mutex(0)
    let client = MorningPrepClient(
      lastMailSync: { nil },
      syncMail: {
        let attempt = calls.withLock { value -> Int in value += 1; return value }
        if attempt == 1 { throw NSError(domain: "mail", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline"]) }
        return 4
      },
      lastFeedPoll: { nil }, pollFeeds: { _, _ in (1, 1) },
      processOffers: { _ in (0, 0) })
    let model = MorningPrep(client: client, store: .inMemory())

    let failed = await model.run(.init(trigger: .automation))
    let retried = await model.run(.init(trigger: .automation))

    #expect(failed.mail == .failed("Offline"))
    #expect(retried.mail == .synced(4))
    #expect(calls.withLock { $0 } == 2)
  }

  @Test("A successful recent summary pass is skipped on the next app open")
  func summariesHaveFreshness() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let summaryCalls = Mutex(0)
    let client = MorningPrepClient(
      lastMailSync: { now }, syncMail: { 0 }, lastFeedPoll: { now },
      pollFeeds: { _, _ in (0, 0) },
      processOffers: { _ in summaryCalls.withLock { $0 += 1 }; return (1, 0) })
    let model = MorningPrep(client: client, store: .inMemory(), now: { now })

    let first = await model.run(.init(trigger: .open))
    let second = await model.run(.init(trigger: .open))

    #expect(first.summaries == .completed(done: 1, waiting: 0))
    #expect(second.summaries == .skipped)
    #expect(summaryCalls.withLock { $0 } == 1)
  }

  @Test(
    "Manual refresh and the Prepare button run after an in-flight open skipped fresh data",
    arguments: [MorningPrepTrigger.manual, .manualPrepare])
  func manualRefreshFollowsOpen(trigger: MorningPrepTrigger) async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let mailCalls = Mutex(0)
    let feedCalls = Mutex(0)
    let offerCalls = Mutex(0)
    let gate = AsyncGate()
    let client = MorningPrepClient(
      lastMailSync: { now.addingTimeInterval(-60) },
      syncMail: { mailCalls.withLock { $0 += 1 }; return 1 },
      lastFeedPoll: { now.addingTimeInterval(-60) },
      pollFeeds: { _, _ in feedCalls.withLock { $0 += 1 }; return (1, 1) },
      processOffers: { _ in
        let call = offerCalls.withLock { value -> Int in value += 1; return value }
        if call == 1 { await gate.pause() }
        return (1, 0)
      })
    let model = MorningPrep(client: client, store: .inMemory(), now: { now })
    let opening = Task { await model.run(.init(trigger: .open)) }
    await gate.waitUntilEntered()
    let manual = Task { await model.run(.init(trigger: trigger)) }
    await Task.yield()
    await gate.release()

    _ = await opening.value
    let result = await manual.value

    #expect(result.trigger == trigger)
    #expect(mailCalls.withLock { $0 } == 1)
    #expect(feedCalls.withLock { $0 } == 1)
    #expect(offerCalls.withLock { $0 } == 2)
  }

  @Test("A failed feed request counts as attempted for the ready rule")
  func attemptedFeedFailuresCanBeReady() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let firstOpen = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 7))!
    let store = MorningPrepRecordStore.inMemory()
    store.recordFirstOpen(at: firstOpen, calendar: calendar)
    var run = MorningPrepRun(trigger: .automation, startedAt: firstOpen.addingTimeInterval(-60))
    run.mail = .synced(1)
    run.feeds = .completed(succeeded: 0, attempted: 5)
    run.summaries = .completed(done: 0, waiting: 0)
    run.endedAt = firstOpen.addingTimeInterval(-30)
    run.state = .finished
    store.save(run, now: firstOpen)
    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 0 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (0, 0) }, processOffers: { _ in (0, 0) })
    let model = MorningPrep(client: client, store: store)

    #expect(model.readyRun(on: store.days[0])?.id == run.id)
  }

  @Test("Unfinished runs stay recorded as interrupted and first open is idempotent")
  func interruptedRunAndFirstOpen() {
    let store = MorningPrepRecordStore.inMemory()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let run = MorningPrepRun(trigger: .automation, startedAt: start)
    store.save(run, now: start)
    let calendar = Calendar(identifier: .gregorian)
    let beforeFour = calendar.date(bySettingHour: 3, minute: 59, second: 0, of: start)!
    store.recordFirstOpen(at: beforeFour, calendar: calendar)
    #expect(store.days.isEmpty)
    let afterFour = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: start)!
    store.recordFirstOpen(at: afterFour, calendar: calendar)
    store.recordFirstOpen(at: afterFour.addingTimeInterval(60), calendar: calendar)
    #expect(store.days.count == 1)
    #expect(store.records.first?.state == .running)

    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 0 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (0, 0) }, processOffers: { _ in (0, 0) })
    let model = MorningPrep(client: client, store: store, now: { start })
    #expect(model.records.first?.state == .interrupted)
  }

  @Test("Ready requires a completed unattended run after four and before first open")
  func readyRule() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 7))!
    let beforeOpen = day.addingTimeInterval(-20 * 60)
    let store = MorningPrepRecordStore.inMemory()
    store.recordFirstOpen(at: day, calendar: calendar)
    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 2 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (3, 3) }, processOffers: { _ in (0, 0) })
    let model = MorningPrep(client: client, store: store, now: { beforeOpen })
    let result = await model.run(.init(trigger: .automation))
    #expect(result.endedAt != nil)
    #expect(result.state == .finished)
    #expect(result.mail == .synced(2))
    #expect(result.feeds == .completed(succeeded: 3, attempted: 3))
    #expect(result.endedAt! < store.days[0].firstOpenAt)
    #expect(model.readyRun(on: store.days[0]) != nil)
  }

  @Test("The next refresh is 5:30 local across midnight and daylight-saving changes")
  func nextRefreshDate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let beforeFallBackDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 5, minute: 31))!
    let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 50))!
    let fallBackNextMorning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 5, minute: 30))!
    let beforeBoundary = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 5, minute: 29))!
    let afterBoundary = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 5, minute: 31))!
    let nextDay = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 5, minute: 30))!
    let springBeforeBoundary = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 5, minute: 31))!
    let springNextDay = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 5, minute: 30))!

    #expect(MorningPrepSchedule.nextRefresh(after: beforeFallBackDay, calendar: calendar) == fallBackNextMorning)
    #expect(MorningPrepSchedule.nextRefresh(after: lateEvening, calendar: calendar) == fallBackNextMorning)
    #expect(MorningPrepSchedule.nextRefresh(after: beforeBoundary, calendar: calendar) ==
      calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 5, minute: 30)))
    #expect(MorningPrepSchedule.nextRefresh(after: afterBoundary, calendar: calendar) == nextDay)
    #expect(MorningPrepSchedule.nextRefresh(after: springBeforeBoundary, calendar: calendar) == springNextDay)
  }

  @Test("A background run reschedules first and reports a refused request")
  func backgroundScheduleFailure() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let testCalendar = calendar
    let scheduledDate = Mutex<Date?>(nil)
    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { throw NSError(domain: "mail", code: 1) },
      lastFeedPoll: { nil }, pollFeeds: { _, _ in (0, 0) }, processOffers: { _ in (0, 0) })
    let scheduler = MorningPrepSchedulerClient { date in
      scheduledDate.withLock { $0 = date }
      throw NSError(domain: "scheduler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Background App Refresh is unavailable"])
    }
    let scheduleStore = MorningPrepScheduleStore.inMemory()
    let model = MorningPrep(
      client: client, scheduler: scheduler, scheduleStore: scheduleStore, store: .inMemory(),
      now: { now }, calendar: { testCalendar })

    _ = await model.run(.init(trigger: .backgroundRefresh))

    #expect(scheduledDate.withLock { $0 } == MorningPrepSchedule.nextRefresh(after: now, calendar: testCalendar))
    #expect(model.scheduleFailure == "Background App Refresh is unavailable")
    let reopened = MorningPrep(client: client, scheduleStore: scheduleStore, store: .inMemory(), now: { now })
    #expect(reopened.scheduleFailure == "Background App Refresh is unavailable")
  }

  @Test("A background refresh stops when today's unattended run is already ready")
  func alreadyReadyBackgroundRefresh() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let testCalendar = calendar
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 7))!
    let store = MorningPrepRecordStore.inMemory()
    var ready = MorningPrepRun(trigger: .automation, startedAt: now.addingTimeInterval(-600))
    ready.mail = .synced(2)
    ready.feeds = .completed(succeeded: 0, attempted: 4)
    ready.summaries = .completed(done: 0, waiting: 0)
    ready.endedAt = now.addingTimeInterval(-540)
    ready.state = .finished
    store.save(ready, now: now)
    store.recordFirstOpen(at: now, calendar: testCalendar)
    let workCalls = Mutex(0)
    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { workCalls.withLock { $0 += 1 }; return 0 },
      lastFeedPoll: { nil },
      pollFeeds: { _, _ in workCalls.withLock { $0 += 1 }; return (1, 1) },
      processOffers: { _ in workCalls.withLock { $0 += 1 }; return (0, 0) })
    let model = MorningPrep(client: client, store: store, now: { now }, calendar: { testCalendar })

    let result = await model.run(.init(trigger: .backgroundRefresh))

    #expect(result.trigger == .backgroundRefresh)
    #expect(result.outcome == .alreadyReady)
    #expect(result.state == .finished)
    #expect(result.endedAt == now)
    #expect(model.records.count == 2)
    #expect(workCalls.withLock { $0 } == 0)
    #expect(model.readyRun(on: model.days[0])?.id == ready.id)
    #expect(model.todayStatus(at: now) == .ready(ready.endedAt!))

    let encodedMarker = try #require(try? JSONEncoder().encode(result))
    var oldRecord = try #require(try? JSONSerialization.jsonObject(with: encodedMarker) as? [String: Any])
    oldRecord.removeValue(forKey: "outcome")
    let oldData = try #require(try? JSONSerialization.data(withJSONObject: oldRecord))
    let decoded = try #require(try? JSONDecoder().decode(MorningPrepRun.self, from: oldData))
    #expect(decoded.outcome == nil)
  }

  @Test("Today status derives every state from today's run records")
  func todayStatusDerivation() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let testCalendar = calendar
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 7))!
    let updateEnd = now.addingTimeInterval(4 * 60)
    let emptyClient = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 2 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (7, 9) }, processOffers: { _ in (0, 0) })

    let emptyStore = MorningPrepRecordStore.inMemory()
    let oldRun = storedRun(
      trigger: .open, startedAt: now.addingTimeInterval(-24 * 60 * 60),
      endedAt: now.addingTimeInterval(-24 * 60 * 60 + 60), mail: .synced(1),
      feeds: .completed(succeeded: 1, attempted: 1))
    emptyStore.save(oldRun, now: now)
    let noRunToday = MorningPrep(client: emptyClient, store: emptyStore, now: { now }, calendar: { testCalendar })
    #expect(noRunToday.todayStatus(at: now) == nil)

    let readyStore = MorningPrepRecordStore.inMemory()
    readyStore.recordFirstOpen(at: now, calendar: testCalendar)
    let ready = storedRun(
      trigger: .automation, startedAt: now.addingTimeInterval(-10 * 60),
      endedAt: now.addingTimeInterval(-8 * 60), mail: .synced(2),
      feeds: .completed(succeeded: 7, attempted: 9))
    readyStore.save(ready, now: now)
    let readyModel = MorningPrep(client: emptyClient, store: readyStore, now: { now }, calendar: { testCalendar })
    #expect(readyModel.todayStatus(at: now) == .ready(ready.endedAt!))

    let updatedStore = MorningPrepRecordStore.inMemory()
    updatedStore.recordFirstOpen(at: now, calendar: testCalendar)
    updatedStore.save(storedRun(
      trigger: .open, startedAt: now, endedAt: updateEnd, mail: .synced(2),
      feeds: .completed(succeeded: 9, attempted: 9)), now: updateEnd)
    let updatedModel = MorningPrep(client: emptyClient, store: updatedStore, now: { updateEnd }, calendar: { testCalendar })
    #expect(updatedModel.todayStatus(at: now) == .updated(updateEnd))

    let interruptedStore = MorningPrepRecordStore.inMemory()
    interruptedStore.save(storedRun(
      trigger: .backgroundRefresh, startedAt: now, endedAt: nil, mail: nil, feeds: nil,
      state: .interrupted), now: now)
    let interruptedModel = MorningPrep(client: emptyClient, store: interruptedStore, now: { now }, calendar: { testCalendar })
    #expect(interruptedModel.todayStatus(at: now) == .problem("Update didn't finish"))

    let unauthorizedStore = MorningPrepRecordStore.inMemory()
    unauthorizedStore.save(storedRun(
      trigger: .open, startedAt: now, endedAt: updateEnd, mail: .notAuthorized,
      feeds: .completed(succeeded: 9, attempted: 9)), now: updateEnd)
    let unauthorizedModel = MorningPrep(client: emptyClient, store: unauthorizedStore, now: { updateEnd }, calendar: { testCalendar })
    #expect(unauthorizedModel.todayStatus(at: now) == .problem("Mail not updated: sign in to Gmail"))

    let failedFeedsStore = MorningPrepRecordStore.inMemory()
    failedFeedsStore.save(storedRun(
      trigger: .open, startedAt: now, endedAt: updateEnd, mail: .synced(2),
      feeds: .completed(succeeded: 7, attempted: 9)), now: updateEnd)
    let failedFeedsModel = MorningPrep(client: emptyClient, store: failedFeedsStore, now: { updateEnd }, calendar: { testCalendar })
    #expect(failedFeedsModel.todayStatus(at: now) == .problem("2 of 9 feeds didn't load"))

    let gate = AsyncGate()
    let runningClient = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 2 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (9, 9) }, processOffers: { _ in await gate.pause(); return (0, 0) })
    let runningModel = MorningPrep(client: runningClient, store: .inMemory(), now: { now }, calendar: { testCalendar })
    let runningTask = Task { await runningModel.run(.init(trigger: .open)) }
    await gate.waitUntilEntered()
    #expect(runningModel.todayStatus(at: now) == .running)
    await gate.release()
    _ = await runningTask.value
  }

  @Test("An already-ready marker never sets Today's line")
  func alreadyReadyMarkerDoesNotSetTodayLine() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let testCalendar = calendar
    let firstOpen = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 6))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 7, minute: 30))!
    let store = MorningPrepRecordStore.inMemory()
    store.recordFirstOpen(at: firstOpen, calendar: testCalendar)
    // The automation finished after first open, so it can't make the day ready, but it stops a later background run.
    let automationEnd = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 6, minute: 52))!
    store.save(MorningPrepRun(
      trigger: .automation, startedAt: automationEnd.addingTimeInterval(-60), endedAt: automationEnd,
      state: .finished, mail: .synced(1), feeds: .completed(succeeded: 3, attempted: 3),
      summaries: .completed(done: 0, waiting: 0)), now: automationEnd)
    let client = MorningPrepClient(
      lastMailSync: { nil }, syncMail: { 0 }, lastFeedPoll: { nil },
      pollFeeds: { _, _ in (0, 0) }, processOffers: { _ in (0, 0) })
    let model = MorningPrep(client: client, store: store, now: { now }, calendar: { testCalendar })

    let marker = await model.run(.init(trigger: .backgroundRefresh))

    #expect(marker.outcome == .alreadyReady)
    #expect(model.todayStatus(at: now) == .updated(automationEnd))
  }

  @Test("Today status text covers ready, running, updated, and problems")
  func todayStatusLines() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let locale = Locale(identifier: "en_US")
    let time = date.formatted(.dateTime.hour().minute().locale(locale))

    #expect(MorningPrepTodayStatus.running.line() == "Catching up…")
    #expect(MorningPrepTodayStatus.ready(date).line(locale: locale) == "Ready at \(time)")
    #expect(MorningPrepTodayStatus.updated(date).line(locale: locale) == "Updated at \(time)")
    #expect(MorningPrepTodayStatus.problem("Mail not updated: sign in to Gmail").line() == "Mail not updated: sign in to Gmail")
  }

  private func storedRun(
    trigger: MorningPrepTrigger, startedAt: Date, endedAt: Date?,
    mail: MorningPrepMailResult?, feeds: MorningPrepFeedsResult?,
    state: MorningPrepRun.State = .finished
  ) -> MorningPrepRun {
    MorningPrepRun(
      trigger: trigger, startedAt: startedAt, endedAt: endedAt,
      state: state, mail: mail, feeds: feeds,
      summaries: endedAt == nil ? nil : .completed(done: 0, waiting: 0))
  }
}

private actor AsyncGate {
  private var entered = false
  private var entryWaiters: [CheckedContinuation<Void, Never>] = []
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var isReleased = false

  func pause() async {
    entered = true
    entryWaiters.forEach { $0.resume() }
    entryWaiters.removeAll()
    if isReleased { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  func waitUntilEntered() async {
    if entered { return }
    await withCheckedContinuation { entryWaiters.append($0) }
  }

  func release() {
    isReleased = true
    waiters.forEach { $0.resume() }
    waiters.removeAll()
  }
}
