import Foundation

extension MorningPrep {
  func start(
    _ request: MorningPrepRequest, following joinedID: UUID? = nil
  ) async -> MorningPrepRun {
    let id = UUID()
    let task = Task { await self.execute(request) }
    activeTask = task
    activeTrigger = request.trigger
    activeID = id
    if let joinedID {
      followUpTasks[joinedID] = task
      if followUpTasks.count > 32, let oldestID = followUpTasks.keys.first {
        followUpTasks.removeValue(forKey: oldestID)
      }
    }
    isRunning = true
    let result = await task.value
    if activeID == id {
      activeTask = nil
      activeTrigger = nil
      activeID = nil
      isRunning = false
      records = store.records
      days = store.days
    }
    return result
  }

  func execute(_ request: MorningPrepRequest) async -> MorningPrepRun {
    let client = self.client
    let started = now()
    let budget = request.timeBudget ?? (request.trigger.isUnattended ? Self.unattendedBudget : nil)
    let deadline = budget.map { monotonicNow().advanced(by: $0) }
    var run = MorningPrepRun(trigger: request.trigger, startedAt: started)
    store.save(run, now: started)

    func outOfTime() -> Bool { deadline.map { monotonicNow() >= $0 } ?? false }
    func persist() { store.save(run, now: now()) }

    do {
      let last = try await client.lastMailSync()
      let shouldSync = !request.trigger.skipsFreshData || GmailAutoSyncPolicy.shouldSync(
        lastSyncedAt: last, lastAttemptAt: nil, now: now(), isSyncing: false)
      if !shouldSync {
        run.mail = .skippedFresh
      } else if outOfTime() {
        run.mail = .outOfTime
      } else {
        do {
          let count = try await withTimeBudget(until: deadline, now: monotonicNow) { try await client.syncMail() }
          run.mail = .synced(count)
        }
        catch MorningPrepAuthorizationError.notAuthorized { run.mail = .notAuthorized }
        catch is MorningPrepTimeBudgetExpired { run.mail = .outOfTime }
        catch { run.mail = outOfTime() ? .outOfTime : .failed(error.localizedDescription) }
      }
    } catch { run.mail = .failed(error.localizedDescription) }
    persist()
    if request.trigger.appliesPolicies { await client.applyPolicies() }

    do {
      let last = try await client.lastFeedPoll()
      if request.trigger.skipsFreshData, let last, now().timeIntervalSince(last) < Self.feedsFreshness {
        run.feeds = .skippedFresh
      } else if outOfTime() {
        run.feeds = .outOfTime
      } else {
        let values = try await withTimeBudget(until: deadline, now: monotonicNow) {
          await client.pollFeeds(4, .seconds(10))
        }
        run.feeds = .completed(succeeded: values.succeeded, attempted: values.attempted)
      }
    } catch is MorningPrepTimeBudgetExpired { run.feeds = .outOfTime }
    catch { run.feeds = .completed(succeeded: 0, attempted: 0) }
    persist()

    if request.trigger.skipsFreshData, hasFreshSummary(now: now()) {
      run.summaries = .skipped
    } else if outOfTime() { run.summaries = .outOfTime }
    else {
      do {
        let values = try await withTimeBudget(until: deadline, now: monotonicNow) { await client.processOffers(10) }
        run.summaries = .completed(done: values.done, waiting: values.waiting)
      } catch is MorningPrepTimeBudgetExpired {
        run.summaries = .outOfTime
      } catch {
        run.summaries = .completed(done: 0, waiting: 0)
      }
    }
    run.endedAt = now()
    run.state = .finished
    persist()
    return run
  }

  private func hasFreshSummary(now: Date) -> Bool {
    store.records.contains { run in
      guard run.state == .finished, let endedAt = run.endedAt,
        now.timeIntervalSince(endedAt) >= 0,
        now.timeIntervalSince(endedAt) < 30 * 60,
        case let .completed(done, _)? = run.summaries
      else { return false }
      return done > 0
    }
  }
}

private struct MorningPrepTimeBudgetExpired: Error {}

private func withTimeBudget<T: Sendable>(
  until deadline: ContinuousClock.Instant?, now: @escaping @Sendable () -> ContinuousClock.Instant,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  guard let deadline else { return try await operation() }
  let duration = now().duration(to: deadline)
  guard duration > .zero else { throw MorningPrepTimeBudgetExpired() }
  return try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await operation() }
    group.addTask {
      try await Task.sleep(for: duration)
      throw MorningPrepTimeBudgetExpired()
    }
    guard let result = try await group.next() else { throw MorningPrepTimeBudgetExpired() }
    group.cancelAll()
    return result
  }
}
