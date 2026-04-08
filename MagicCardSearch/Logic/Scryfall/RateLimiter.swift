actor RateLimiter {
    private let maxRequests: Int
    private let windowDuration: Duration
    private var log: [ContinuousClock.Instant] = []

    init(maxRequests: Int, windowDuration: Duration = .seconds(1)) {
        self.maxRequests = maxRequests
        self.windowDuration = windowDuration
    }

    func waitForSlot() async throws {
        while true {
            let now = ContinuousClock.now
            log.removeAll { now - $0 >= windowDuration }

            if log.count < maxRequests {
                log.append(now)
                return
            }

            // Sleep until the oldest entry exits the window, plus a small margin
            // for ContinuousClock precision. The loop re-evaluates after waking,
            // which correctly handles concurrent waiters that also woke up.
            let sleepUntil = log[0] + windowDuration + .milliseconds(1)
            try await Task.sleep(until: sleepUntil, clock: .continuous)
        }
    }
}
