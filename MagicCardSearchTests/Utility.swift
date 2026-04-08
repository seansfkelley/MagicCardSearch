struct TestTimedOut: Error {}

/// Runs `operation` and fails if it takes longer than `duration` real time.
/// Uses ContinuousClock for the deadline, so a frozen TestClock in the
/// operation will not prevent the timeout from firing.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TestTimedOut()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

func stringIndexRange(_ from: Int, _ to: Int) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: from)
        ..<
        String.Index.init(encodedOffset: to)
}

func stringIndexRange(_ range: Range<Int>) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: range.lowerBound)
        ..<
        String.Index.init(encodedOffset: range.upperBound)
}
