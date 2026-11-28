import Foundation

extension MorningPrep {
  public func scheduleNextRefresh() async {
    guard let date = MorningPrepSchedule.nextRefresh(after: now(), calendar: calendar()) else {
      setScheduleFailure("Could not calculate the next refresh time.")
      return
    }
    do {
      try await scheduler.schedule(date)
      setScheduleFailure(nil)
    } catch {
      setScheduleFailure(error.localizedDescription)
    }
  }

  private func setScheduleFailure(_ failure: String?) {
    scheduleFailure = failure
    scheduleStore.saveFailure(failure)
  }

  public func todayStatus(at date: Date? = nil) -> MorningPrepTodayStatus? {
    let date = date ?? now()
    if isRunning { return .running }
    let localCalendar = calendar()
    let todayRuns = records.filter { localCalendar.isDate($0.startedAt, inSameDayAs: date) }
      .sorted { $0.startedAt > $1.startedAt }
    guard let latest = todayRuns.first else { return nil }
    if latest.state == .interrupted { return .problem("Update didn't finish") }
    if let day = days.first(where: { localCalendar.isDate($0.firstOpenAt, inSameDayAs: date) }),
      let ready = readyRun(on: day) {
      return .ready(ready.endedAt ?? latest.endedAt ?? date)
    }
    if let problem = problemLine(for: latest) { return .problem(problem) }
    guard let endedAt = latest.endedAt else { return .problem("Update didn't finish") }
    return .updated(endedAt)
  }

  func readyUnattendedRun(at date: Date) -> MorningPrepRun? {
    let localCalendar = calendar()
    guard let fourAM = localCalendar.date(bySettingHour: 4, minute: 0, second: 0, of: date) else {
      return nil
    }
    return records.first { run in
      guard run.trigger.isUnattended, run.state == .finished,
        let endedAt = run.endedAt, endedAt >= fourAM,
        localCalendar.isDate(endedAt, inSameDayAs: date),
        run.mail == .skippedFresh || isSynced(run.mail),
        case .completed(_, _)? = run.feeds
      else { return false }
      return true
    }
  }

  private func isSynced(_ result: MorningPrepMailResult?) -> Bool {
    if case .synced = result { return true }
    return false
  }

  private func problemLine(for run: MorningPrepRun) -> String? {
    switch run.mail {
    case .notAuthorized:
      return "Mail not updated: sign in to Gmail"
    case let .failed(message):
      return "Mail not updated: \(message)"
    case .outOfTime:
      return "Mail not updated: out of time"
    default:
      break
    }
    switch run.feeds {
    case let .completed(succeeded, attempted) where succeeded < attempted:
      let failed = attempted - succeeded
      return "\(failed) of \(attempted) feeds didn't load"
    case .outOfTime:
      return "Feeds not updated: out of time"
    default:
      return nil
    }
  }
}
