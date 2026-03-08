import OSLog

private let defaultLogger = Logger(subsystem: "MagicCardSearch", category: "timed")

func timed<T>(_ name: String, using logger: Logger? = nil, _ work: () throws -> T) rethrows -> T {
    let start = ContinuousClock.now
    let result = try work()
    (logger ?? defaultLogger).debug("completed operation=\(name) in duration=\(ContinuousClock.now - start)")
    return result
}
