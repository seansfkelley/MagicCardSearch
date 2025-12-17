//
//  MagicCardSearchApp.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI
import Logging

@main
struct MagicCardSearchApp: App {
    init() {
        // Configure logging to show debug level logs
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug  // Set to .debug to see all debug logs
            return handler
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
