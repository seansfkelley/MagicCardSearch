import OSLog

private let defaultLogger = Logger(subsystem: "MagicCardSearch", category: "timed")

func timed<T>(
    _ name: String,
    using logger: Logger? = nil,
    warnThreshold: Duration? = nil,
    _ work: () throws -> T
) rethrows -> T {
    let start = ContinuousClock.now
    let result = try work()
    let duration = ContinuousClock.now - start
    let log = logger ?? defaultLogger
    if let warnThreshold, duration > warnThreshold {
        log.warning("completed slow operation=\(name) with duration=\(duration) above threshold=\(warnThreshold)")
    } else {
        log.debug("completed operation=\(name) with duration=\(duration)")
    }
    return result
}
