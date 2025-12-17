//
//  InFlightRequestTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation
import Logging

/// A thread-safe tracker for in-flight asynchronous requests that prevents duplicate fetches.
/// This class ensures that only one fetch operation is in progress for a given key at a time.
actor InFlightRequestTracker<Key: Hashable & Sendable, Value: Sendable> {
    private var inFlightRequests: [Key: Task<Value, Error>] = [:]
    private let logger: Logger
    
    init(label: String) {
        self.logger = Logger(label: "\(label).InFlightTracker")
    }
    
    /// Executes a fetch operation, coalescing duplicate requests for the same key.
    ///
    /// If there's already a fetch in progress for the given key, this method waits for
    /// that existing operation to complete rather than starting a new one.
    ///
    /// - Parameters:
    ///   - key: The key to track
    ///   - fetchValue: The closure to execute if no fetch is in progress
    /// - Returns: The fetched value
    /// - Throws: Any error thrown by the fetch closure
    func getOrFetch(forKey key: Key, fetch fetchValue: @escaping @Sendable () async throws -> Value) async throws -> Value {
        // Check if there's already an in-flight request for this key
        if let existingTask = inFlightRequests[key] {
            logger.debug("Waiting for existing request", metadata: ["key": "\(key)"])
            return try await existingTask.value
        }
        
        // Create a new task for this request
        let task = Task<Value, Error> { [logger = self.logger, key] in
            let value = try await fetchValue()
            logger.debug("Fetch completed", metadata: ["key": "\(key)"])
            return value
        }
        
        inFlightRequests[key] = task
        logger.debug("Starting new fetch", metadata: ["key": "\(key)"])
        
        // Wait for completion and clean up
        do {
            let value = try await task.value
            inFlightRequests.removeValue(forKey: key)
            return value
        } catch {
            inFlightRequests.removeValue(forKey: key)
            logger.error("Fetch failed", metadata: ["key": "\(key)", "error": "\(error)"])
            throw error
        }
    }
    
    /// Cancels all in-flight requests and clears the tracker.
    func cancelAll() {
        let tasks = inFlightRequests.values
        inFlightRequests.removeAll()
        
        for task in tasks {
            task.cancel()
        }
        
        logger.debug("Cancelled all in-flight requests")
    }
}
