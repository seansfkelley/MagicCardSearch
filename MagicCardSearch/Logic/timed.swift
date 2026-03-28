import OSLog

private let defaultLogger = Logger(subsystem: "MagicCardSearch", category: "timed")

func timed<T>(
    _ name: String,
    using logger: Logger? = nil,
    warnThreshold: Duration? = nil,
    _ work: () throws -> T
) rethrows -> T {
    let log = logger ?? defaultLogger
    let start = ContinuousClock.now
    do {
        let result = try work()
        let duration = ContinuousClock.now - start
        if let warnThreshold, duration > warnThreshold {
            log.warning("completed slow operation=\(name) with duration=\(duration) above threshold=\(warnThreshold)")
        } else {
            log.debug("completed operation=\(name) with duration=\(duration)")
        }
        return result
    } catch {
        let duration = ContinuousClock.now - start
        if error is CancellationError {
            if let warnThreshold, duration > warnThreshold {
                log.warning("cancelled slow operation=\(name) with duration=\(duration) above threshold=\(warnThreshold)")
            } else {
                log.debug("cancelled operation=\(name) with duration=\(duration)")
            }
        } else {
            if let warnThreshold, duration > warnThreshold {
                log.warning("failed slow operation=\(name) with duration=\(duration) above threshold=\(warnThreshold)")
            } else {
                log.debug("failed operation=\(name) with duration=\(duration)")
            }
        }
        // Don't log the error itself; we assume someone higher up will handle that.
        throw error
    }
}
