//
//  isRunningTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-21.
//
import Foundation

// I don't understand why Xcode makes it so awkward to detect if you're running tests...
func isRunningTests() -> Bool {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return true
    }
    
    if NSClassFromString("XCTest") != nil {
        return true
    }
    
    return false
}
