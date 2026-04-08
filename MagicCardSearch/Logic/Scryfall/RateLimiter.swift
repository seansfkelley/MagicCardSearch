import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "RateLimiter")
private let signposter = OSSignposter(logger: logger)

actor RateLimiter<C: Clock> where C.Duration == Duration {
    let name: String?
    private let maxRequests: Int
    private let windowDuration: Duration
    private let clock: C
    private var slots: [C.Instant] = []

    init(_ name: String? = nil, requests maxRequests: Int, per windowDuration: Duration, using clock: C) {
        self.name = name
        self.maxRequests = maxRequests
        self.windowDuration = windowDuration
        self.clock = clock
    }

    func waitForSlot() async throws {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("waitForSlot", id: signpostID, "\(self.tag)slots \(self.slots.count)/\(self.maxRequests)")
        defer { signposter.endInterval("waitForSlot", state) }

        while true {
            let now = clock.now
            slots.removeAll { $0.duration(to: now) >= windowDuration }

            if slots.count < maxRequests {
                logger.debug("\(self.tag)slot available")
                slots.append(now)
                return
            }

            // Sleep until the oldest entry exits the window, plus a small margin
            // for ContinuousClock precision. The loop re-evaluates after waking,
            // which correctly handles concurrent waiters that also woke up.
            let sleepUntil = slots[0].advanced(by: windowDuration + .milliseconds(5))
            logger.debug("\(self.tag)slot unavailable; sleeping for \(now.duration(to: sleepUntil))")
            try await Task.sleep(until: sleepUntil, clock: clock)
        }
    }

    private var tag: String { name.map { "[\($0)] " } ?? "" }
}

extension RateLimiter where C == ContinuousClock {
    init(_ name: String? = nil, requests: Int, per: Duration) {
        self.init(name, requests: requests, per: per, using: ContinuousClock())
    }
}
