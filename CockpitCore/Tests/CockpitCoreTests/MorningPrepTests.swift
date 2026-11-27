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

  @Test("An unattended budget cancels the current step and records later steps as out of time")
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

    #expect(run.mail == .outOfTime)
    #expect(run.feeds == .outOfTime)
    #expect(run.summaries == .outOfTime)
    #expect(feedCalls.withLock { $0 } == 0)
    #expect(summaryCalls.withLock { $0 } == 0)
  }

  @Test("Concurrent callers share one operation, and cancelling a waiter leaves it running")
  func singleFlightAndCancelledWaiter() async {
    let mailCalls = Mutex(0)
    let policyCalls = Mutex(0)
    let gate = AsyncGate()
    let client = MorningPrepClient(
      lastMailSync: { nil },
      syncMail: {
        mailCalls.withLock { $0 += 1 }
        await gate.pause()
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
    waiter.cancel()
    await gate.release()
    _ = await first.value
    _ = await waiter.value

    #expect(mailCalls.withLock { $0 } == 1)
    #expect(policyCalls.withLock { $0 } == 1)
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
