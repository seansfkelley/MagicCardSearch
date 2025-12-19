//
//  DiskCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import Logging

private let logger = Logger(label: "DiskCache")

/// Configuration for disk caching behavior.
final class DiskCache<Key: Hashable & Sendable, Value: Codable & Sendable>: Cache, @unchecked Sendable {
    let cacheURL: URL
    let expiration: Expiration
    let nonce: String?
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.magicardsearch.diskcache", attributes: .concurrent)
    private let inFlightTracker: InFlightRequestTracker<Key, Value>
    
    init?(name: String, expiration: Expiration, nonce: String? = nil, fileManager: FileManager = .default) {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        self.fileManager = fileManager
        self.expiration = expiration
        self.nonce = nonce
        self.cacheURL = cachesURL.appendingPathComponent(name, isDirectory: true)
        self.inFlightTracker = InFlightRequestTracker(label: "DiskCache.\(name)")
        
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        
        if let nonce {
            logger.debug("DiskCache initialized with nonce", metadata: ["nonce": "\(nonce)"])
        }
    }
    
    // MARK: - Cache Protocol Conformance
    
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheURL,
                    includingPropertiesForKeys: nil
                )
                
                logger.debug("Clearing all cache entries", metadata: ["count": "\(contents.count)"])
                
                for fileURL in contents {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            } catch {
                logger.error("Failed to clear disk cache", metadata: ["error": "\(error)"])
            }
        }
        
        Task {
            await inFlightTracker.cancelAll()
        }
    }
    
    // MARK: - Get Methods with Request Coalescing
    
    /// Retrieves the value for the given key, or executes the provided closure if not found.
    /// Ensures only one fetch operation is in progress per key.
    func get(forKey key: Key, orFetch fetchValue: @Sendable () throws -> Value) throws -> Value {
        // Check cache first
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let fetchedValue = try fetchValue()
        self[key] = fetchedValue
        return fetchedValue
    }
    
    /// Async version: Retrieves the value for the given key, or executes the provided async closure if not found.
    /// Ensures only one fetch operation is in progress per key.
    func get(forKey key: Key, orFetch fetchValue: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let value = try await inFlightTracker.getOrFetch(forKey: key) {
            try await fetchValue()
        }
        
        self[key] = value
        return value
    }
    
    subscript(key: Key) -> Value? {
        get {
            let fileURL = self.fileURL(for: key)
            guard let (value, expirationDate, cachedNonce): (Value, Date?, String?) = read(from: fileURL) else {
                logger.debug("Cache miss", metadata: ["key": "\(key)"])
                return nil
            }
            
            if self.nonce != cachedNonce {
                logger.debug("Cache nonce mismatch, invalidating entry", metadata: [
                    "key": "\(key)",
                    "currentNonce": "\(self.nonce ?? "nil")",
                    "cachedNonce": "\(cachedNonce ?? "nil")",
                ])
                removeItem(at: fileURL)
                return nil
            }
            
            if let expirationDate, Date() > expirationDate {
                logger.debug("Cache expired", metadata: [
                    "key": "\(key)",
                    "expirationDate": "\(expirationDate)",
                ])
                removeItem(at: fileURL)
                return nil
            }
            
            logger.debug("Cache hit", metadata: ["key": "\(key)"])
            return value
        }
        set {
            let fileURL = self.fileURL(for: key)
            if let value = newValue {
                logger.debug("Cache set", metadata: ["key": "\(key)"])
                let expirationDate = expiration.expirationDate()
                write(value, to: fileURL, expirationDate: expirationDate, nonce: self.nonce)
            } else {
                logger.debug("Cache remove", metadata: ["key": "\(key)"])
                removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fileURL(for key: Key) -> URL {
        let fileName = String(describing: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "cache"
        return cacheURL.appendingPathComponent(fileName)
    }
    
    private func write(_ value: Value, to fileURL: URL, expirationDate: Date?, nonce: String?) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            do {
                let wrapper = CacheEntryWrapper(value: value, expirationDate: expirationDate, nonce: nonce)
                let data = try JSONEncoder().encode(wrapper)
                try data.write(to: fileURL)
            } catch {
                logger.error("Failed to write cache entry to disk", metadata: [
                    "fileURL": "\(fileURL.path)",
                    "error": "\(error)",
                ])
            }
        }
    }
    
    private func read(from fileURL: URL) -> (value: Value, expirationDate: Date?, nonce: String?)? {
        return queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else {
                logger.debug("Failed to read data from file", metadata: ["fileURL": "\(fileURL.path)"])
                return nil
            }
            
            do {
                let wrapper = try JSONDecoder().decode(CacheEntryWrapper<Value>.self, from: data)
                return (wrapper.value, wrapper.expirationDate, wrapper.nonce)
            } catch {
                logger.warning("Failed to decode cache entry, removing corrupted file", metadata: [
                    "fileURL": "\(fileURL.path)",
                    "dataSize": "\(data.count)",
                    "error": "\(type(of: error))",  // Use type(of:) to avoid logging potentially corrupt data
                ])
                // Remove the corrupted file
                try? self.fileManager.removeItem(at: fileURL)
                return nil
            }
        }
    }
    
    private func removeItem(at fileURL: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
}

private struct CacheEntryWrapper<T: Codable>: Codable {
    let value: T
    let expirationDate: Date?
    let nonce: String?
}
