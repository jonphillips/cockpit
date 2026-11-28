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

  @Test("Manual refresh runs after an in-flight open skipped fresh data")
  func manualRefreshFollowsOpen() async {
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
    let manual = Task { await model.run(.init(trigger: .manual)) }
    await Task.yield()
    await gate.release()

    _ = await opening.value
    let result = await manual.value

    #expect(result.trigger == .manual)
    #expect(mailCalls.withLock { $0 } == 1)
    #expect(feedCalls.withLock { $0 } == 1)
    #expect(offerCalls.withLock { $0 } == 2)
  }

  @Test("A failed feed set cannot satisfy the ready rule")
  func allFeedsFailIsNotReady() async {
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

    #expect(model.readyRun(on: store.days[0]) == nil)
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
