import Clocks
import Testing
@testable import MagicCardSearch

@Suite(.timeLimit(.minutes(1)))
struct UtilityTests {
    // withTimeout fires when the async operation never completes.
    @Test func testWithTimeout() async throws {
        do {
            try await withTimeout(.milliseconds(100)) {
                try await Task.sleep(for: .seconds(1))
            }
            Issue.record("Expected TestTimedOut but withTimeout returned normally")
        } catch is TestTimedOut {
            // correct
        }
    }
}
