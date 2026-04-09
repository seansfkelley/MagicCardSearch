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

    /// Throws on task cancellation.
    func waitForSlot() async throws {
        let signpostId = signposter.makeSignpostID()
        let state = signposter.beginInterval("waitForSlot", id: signpostId, "\(self.name ?? "")")
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
            let jitter = Duration.milliseconds(Int.random(in: 5...50))
            let sleepUntil = slots[0].advanced(by: windowDuration + jitter)
            logger.debug("\(self.tag)slot unavailable; sleep=\(now.duration(to: sleepUntil)) jitter=\(jitter)")
            signposter.emitEvent("waitForSlot", id: signpostId, "sleep=\(now.duration(to: sleepUntil)) jitter=\(jitter)")
            do {
                try await Task.sleep(until: sleepUntil, clock: clock)
            } catch let error as CancellationError {
                signposter.emitEvent("waitForSlot", id: signpostId, "cancelled while sleeping")
                throw error
            }
        }
    }

    private var tag: String { name.map { "[\($0)] " } ?? "" }
}

extension RateLimiter where C == ContinuousClock {
    init(_ name: String? = nil, requests: Int, per: Duration) {
        self.init(name, requests: requests, per: per, using: ContinuousClock())
    }
}
