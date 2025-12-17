//
//  DiskCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

/// Configuration for disk caching behavior.
final class DiskCache<Key: Hashable & Sendable, Value: Codable & Sendable>: Cache, @unchecked Sendable {
    let cacheURL: URL
    let expiration: Expiration
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.magicardsearch.diskcache", attributes: .concurrent)
    
    init?(expiration: Expiration, fileManager: FileManager = .default) {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        self.fileManager = fileManager
        self.expiration = expiration
        self.cacheURL = cachesURL.appendingPathComponent("DiskCache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }
    
    init?(name: String, expiration: Expiration, fileManager: FileManager = .default) {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        self.fileManager = fileManager
        self.expiration = expiration
        self.cacheURL = cachesURL.appendingPathComponent(name, isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
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
                
                for fileURL in contents {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            } catch {
                print("Failed to clear disk cache: \(error)")
            }
        }
    }
    
    subscript(key: Key) -> Value? {
        get {
            let fileURL = self.fileURL(for: key)
            guard let (value, expirationDate): (Value, Date?) = read(from: fileURL) else {
                return nil
            }
            
            if let expirationDate, Date() > expirationDate {
                removeItem(at: fileURL)
                return nil
            }
            
            return value
        }
        set {
            let fileURL = self.fileURL(for: key)
            if let value = newValue {
                let expirationDate = expiration.expirationDate()
                write(value, to: fileURL, expirationDate: expirationDate)
            } else {
                removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fileURL(for key: Key) -> URL {
        let fileName = String(describing: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "cache"
        return cacheURL.appendingPathComponent(fileName)
    }
    
    private func write(_ value: Value, to fileURL: URL, expirationDate: Date?) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            do {
                let wrapper = CacheEntryWrapper(value: value, expirationDate: expirationDate)
                let data = try JSONEncoder().encode(wrapper)
                try data.write(to: fileURL)
            } catch {
                print("Failed to write cache entry to disk: \(error)")
            }
        }
    }
    
    private func read(from fileURL: URL) -> (value: Value, expirationDate: Date?)? {
        return queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let wrapper = try? JSONDecoder().decode(CacheEntryWrapper<Value>.self, from: data) else {
                return nil
            }
            return (wrapper.value, wrapper.expirationDate)
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
}
