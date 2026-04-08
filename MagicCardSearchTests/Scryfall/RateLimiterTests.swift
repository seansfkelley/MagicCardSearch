import Clocks
import Testing
@testable import MagicCardSearch

@Suite
struct RateLimiterTests {
    // Returns immediately for each request as long as the log has room.
    @Test func immediateUnderLimit() async throws {
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 3, windowDuration: .seconds(1), clock: clock)
            try await limiter.waitForSlot()
            try await limiter.waitForSlot()
            try await limiter.waitForSlot()
        }
    }

    // withTimeout itself fires when the window is full and the clock never advances.
    @Test func blocksForeverIfTasksNeverComplete() async throws {
        do {
            try await withTimeout(.milliseconds(100)) {
                let clock = TestClock<Duration>()
                let limiter = RateLimiter(maxRequests: 1, windowDuration: .seconds(60), clock: clock)
                try await limiter.waitForSlot()  // fill the window
                try await limiter.waitForSlot()  // blocks forever; clock never advanced so the slot never opens up
            }
            Issue.record("Expected TestTimedOut but withTimeout returned normally")
        } catch is TestTimedOut {
            // correct
        }
    }

    // Once maxRequests slots are consumed, the next caller waits until the
    // oldest entry leaves the window.
    @Test func blocksWhenWindowFull() async throws {
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 2, windowDuration: .seconds(1), clock: clock)
            try await limiter.waitForSlot()
            try await limiter.waitForSlot()
            async let waiting = limiter.waitForSlot()
            await clock.advance(by: .seconds(2))
            try await waiting
        }
    }

    // After the window renews, a second wave of requests can proceed—and then
    // must again wait for a second renewal before a third wave.
    @Test func windowRenews() async throws {
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 1, windowDuration: .seconds(1), clock: clock)
            try await limiter.waitForSlot()  // slot consumed at t=0

            async let second = limiter.waitForSlot()
            await clock.advance(by: .seconds(2))  // t=2s; slot at t=0 expires
            try await second  // second slot added at t=2s

            async let third = limiter.waitForSlot()
            await clock.advance(by: .seconds(2))  // t=4s; slot at t=2s expires
            try await third
        }
    }

    // When log entries are spread across the window, the next slot opens as soon as the
    // *oldest* entry expires—not when all of them do. This catches an implementation
    // that incorrectly sleeps until log.last expires instead of log.first.
    @Test func wakesOnOldestEntryExpiry() async throws {
        // First prove that this test setup works as expected: if we don't advance enough before
        // claiming more slots, it hangs forever. This proves that the specific timings in the real
        // test below do matter.
        do {
            try await withTimeout(.milliseconds(100)) {
                let clock = TestClock<Duration>()
                let limiter = RateLimiter(maxRequests: 2, windowDuration: .seconds(1), clock: clock)

                try await limiter.waitForSlot()
                await clock.advance(by: .milliseconds(500))
                try await limiter.waitForSlot()

                async let third = limiter.waitForSlot()
                await clock.advance(by: .milliseconds(400)) // t=900ms; oldest entry not yet expired
                try await third // hangs
            }
            Issue.record("Expected TestTimedOut but withTimeout returned normally")
        } catch is TestTimedOut {
            // correct
        }

        // Now advance just past the oldest entry's expiry (t~1000ms). The third call
        // should unblock at t=1100ms even though the t=500ms entry doesn't expire
        // until t~1500ms.
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 2, windowDuration: .seconds(1), clock: clock)

            try await limiter.waitForSlot()
            await clock.advance(by: .milliseconds(500))
            try await limiter.waitForSlot()

            async let third = limiter.waitForSlot()
            await clock.advance(by: .milliseconds(600)) // t=1100ms; oldest entry expires
            try await third
        }
    }

    // Cancelling a queued task propagates CancellationError to the caller.
    @Test func cancellationPropagates() async throws {
        // First prove that this test setup works as expected: if the window is not blocked, the
        // task completes before cancellation would be relevant/propagate.
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 1, windowDuration: .seconds(1), clock: clock)

            let waiter = Task { try await limiter.waitForSlot() }
            await Task.yield()  // give waiter a chance to reach Task.sleep
            waiter.cancel()

            // This should NOT throw a CancellationError.
            try await waiter.value
        }

        // Now run the real test.
        try await withTimeout(.milliseconds(100)) {
            let clock = TestClock<Duration>()
            let limiter = RateLimiter(maxRequests: 1, windowDuration: .seconds(1), clock: clock)
            try await limiter.waitForSlot()  // fill the window

            let waiter = Task { try await limiter.waitForSlot() }
            await Task.yield()  // give waiter a chance to reach Task.sleep
            waiter.cancel()

            do {
                try await waiter.value
                Issue.record("Expected CancellationError but task succeeded")
            } catch is CancellationError {
                // correct
            }
        }
    }
}
