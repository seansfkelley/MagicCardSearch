//
//  MagicCardSearchApp.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//
import SwiftUI
import SQLiteData
import Logging

@main
struct MagicCardSearchApp: App {
    @State private var bookmarkedCardsStore = BookmarkedCardsStore()
    @State private var historyAndPinnedStore = HistoryAndPinnedStore()

    init() {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }

        LoggingSystem.bootstrap { label in
            var handler = CompactLogHandler(label: label)
            handler.logLevel = .info
            return handler
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bookmarkedCardsStore)
                .environment(historyAndPinnedStore)
                .task {
                    await ScryfallCatalogs.initialize()
                }
        }
    }
}

struct CompactLogHandler: LogHandler {
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    
    private let label: String
    
    init(label: String) {
        self.label = label
    }
    
    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge metadata
        var effectiveMetadata = self.metadata
        if let provided = metadataProvider?.get() {
            effectiveMetadata.merge(provided) { _, new in new }
        }
        if let explicit = explicitMetadata {
            effectiveMetadata.merge(explicit) { _, new in new }
        }
        
        // Format metadata
        let metadataString = effectiveMetadata.isEmpty ? "" : " " + effectiveMetadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        
        // Format: timestamp level label: metadata message
        let output = "\(timestamp()) \(level.rawValue) \(label):\(metadataString) \(message)"
        print(output)
    }
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
