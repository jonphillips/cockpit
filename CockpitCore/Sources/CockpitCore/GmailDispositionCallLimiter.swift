actor GmailDispositionCallLimiter {
  private let limit: Int
  private var activeCalls = 0
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(limit: Int) { self.limit = limit }

  func perform(_ operation: @escaping @Sendable () async throws -> Void) async throws {
    await acquire()
    guard !Task.isCancelled else {
      release()
      throw CancellationError()
    }
    do {
      try await operation()
      release()
    } catch {
      release()
      throw error
    }
  }

  private func acquire() async {
    if activeCalls < limit {
      activeCalls += 1
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty {
      activeCalls -= 1
    } else {
      waiters.removeFirst().resume()
    }
  }
}

extension GmailDispositionClient {
  func limited(by limiter: GmailDispositionCallLimiter) -> Self {
    let archive = archive
    let trash = trash
    let reAddInbox = reAddInbox
    let untrash = untrash
    return Self(
      archive: { id in try await limiter.perform { try await archive(id) } },
      trash: { id in try await limiter.perform { try await trash(id) } },
      reAddInbox: { id in try await limiter.perform { try await reAddInbox(id) } },
      untrash: { id in try await limiter.perform { try await untrash(id) } })
  }
}
