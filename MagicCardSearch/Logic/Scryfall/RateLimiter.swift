actor RateLimiter<C: Clock> where C.Duration == Duration {
    private let maxRequests: Int
    private let windowDuration: Duration
    private let clock: C
    private var log: [C.Instant] = []

    init(maxRequests: Int, windowDuration: Duration = .seconds(1), clock: C) {
        self.maxRequests = maxRequests
        self.windowDuration = windowDuration
        self.clock = clock
    }

    func waitForSlot() async throws {
        while true {
            let now = clock.now
            log.removeAll { $0.duration(to: now) >= windowDuration }

            if log.count < maxRequests {
                log.append(now)
                return
            }

            // Sleep until the oldest entry exits the window, plus a small margin
            // for ContinuousClock precision. The loop re-evaluates after waking,
            // which correctly handles concurrent waiters that also woke up.
            let sleepUntil = log[0].advanced(by: windowDuration + .milliseconds(5))
            try await Task.sleep(until: sleepUntil, clock: clock)
        }
    }
}

extension RateLimiter where C == ContinuousClock {
    init(maxRequests: Int, windowDuration: Duration = .seconds(1)) {
        self.init(maxRequests: maxRequests, windowDuration: windowDuration, clock: ContinuousClock())
    }
}

