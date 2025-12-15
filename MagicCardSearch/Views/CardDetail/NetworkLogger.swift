//
//  NetworkLogger.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-14.
//

import Foundation
import OSLog

// MARK: - Network Request Span

/// Lifecycle-managed network request logger with automatic cleanup
actor NetworkRequestSpan {
    private let name: String
    private let category: String
    private let logger: Logger
    private let signposter: OSSignposter
    private let state: OSSignpostIntervalState
    private let startTime: Date
    private var isEnded = false
    
    nonisolated static func begin(
        _ name: String,
        category: String = "network",
        fromCache: Bool = false
    ) async -> NetworkRequestSpan? {
        let logger = Logger(subsystem: "com.magicccardsearch.app", category: category)
        
        if fromCache {
            logger.info("From cache: \(name, privacy: .public)")
            return nil
        }
        
        logger.info("Starting \(name, privacy: .public)")
        
        let signposter = OSSignposter(logger: logger)
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        
        return await NetworkRequestSpan(
            name: name,
            category: category,
            logger: logger,
            signposter: signposter,
            state: state,
            startTime: Date()
        )
    }
    
    private init(
        name: String,
        category: String,
        logger: Logger,
        signposter: OSSignposter,
        state: OSSignpostIntervalState,
        startTime: Date
    ) {
        self.name = name
        self.category = category
        self.logger = logger
        self.signposter = signposter
        self.state = state
        self.startTime = startTime
    }
    
    func end(metadata: [String: Any] = [:]) {
        guard !isEnded else { return }
        isEnded = true
        
        let duration = Date().timeIntervalSince(startTime)
        var metaString = ""
        if !metadata.isEmpty {
            metaString = " " + metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        }
        
        logger.info("Complete: \(self.name, privacy: .public)\(metaString, privacy: .public) [\(String(format: "%.1fms", duration * 1000), privacy: .public)]")
        signposter.endInterval(name, state)
    }
    
    func fail(error: Error) {
        guard !isEnded else { return }
        isEnded = true
        
        let duration = Date().timeIntervalSince(startTime)
        logger.error("Failed: \(self.name, privacy: .public) - \(error.localizedDescription, privacy: .public) [\(String(format: "%.1fms", duration * 1000), privacy: .public)]")
        signposter.endInterval(name, state)
    }
    
    deinit {
        guard !isEnded else { return }
        // Auto-complete if not explicitly ended
        logger.warning("Auto-ended: \(self.name, privacy: .public)")
        signposter.endInterval(name, state)
    }
}

// MARK: - Convenience Function

/// Wraps an async throwing function with automatic network logging
func withNetworkLogging<T>(
    _ name: String,
    category: String = "network",
    fromCache: Bool = false,
    metadata: @escaping (T) -> [String: Any] = { _ in [:] },
    operation: () async throws -> T
) async rethrows -> T {
    let span = await NetworkRequestSpan.begin(name, category: category, fromCache: fromCache)
    
    do {
        let result = try await operation()
        await span?.end(metadata: metadata(result))
        return result
    } catch {
        await span?.fail(error: error)
        throw error
    }
}
