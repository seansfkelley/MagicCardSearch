//
//  AutocompleteScoringExperiments.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//

import Foundation

/// Mock data structure for testing autocomplete scoring algorithms
struct AutocompleteEntry {
    let text: String
    let lastUsed: Date
    let useCount: Int
}

// MARK: - Algorithm 1: Weighted Score with Time Decay

/// A balanced approach using weighted factors with exponential time decay.
///
/// This algorithm combines multiple factors into a single score:
/// - **Position bonus**: Prefix matches score higher than substring matches
/// - **Length penalty**: Shorter matches score higher (more specific)
/// - **Recency score**: Uses exponential decay (half-life approach)
/// - **Frequency score**: Logarithmic scaling to prevent domination by high counts
///
/// **Tuning parameters**:
/// - `prefixBonus`: Multiplier for prefix matches (default: 100)
/// - `substringBase`: Base score for non-prefix matches (default: 50)
/// - `halfLifeDays`: Days for recency to decay by half (default: 30)
/// - `frequencyWeight`: How much to weight usage count (default: 0.3)
struct WeightedScoreAlgorithm {
    let prefixBonus: Double
    let substringBase: Double
    let halfLifeDays: Double
    let frequencyWeight: Double
    
    init(
        prefixBonus: Double = 100,
        substringBase: Double = 50,
        halfLifeDays: Double = 30,
        frequencyWeight: Double = 0.3
    ) {
        self.prefixBonus = prefixBonus
        self.substringBase = substringBase
        self.halfLifeDays = halfLifeDays
        self.frequencyWeight = frequencyWeight
    }
    
    func score(entry: AutocompleteEntry, searchTerm: String, now: Date = Date()) -> Double? {
        guard let matchRange = entry.text.range(of: searchTerm, options: .caseInsensitive) else {
            return nil
        }
        
        // Position score: prefix matches get full bonus, others get base score
        let isPrefix = matchRange.lowerBound == entry.text.startIndex
        let positionScore = isPrefix ? prefixBonus : substringBase
        
        // Length penalty: shorter strings are more specific
        // Use inverse of length difference as a factor
        let lengthDifference = Double(entry.text.count - searchTerm.count)
        let lengthPenalty = 1.0 / (1.0 + lengthDifference / 10.0)
        
        // Recency score: exponential decay with configurable half-life
        let daysSinceUse = abs(now.timeIntervalSince(entry.lastUsed)) / (60 * 60 * 24)
        let recencyScore = pow(0.5, daysSinceUse / halfLifeDays)
        
        // Frequency score: logarithmic to prevent very high counts from dominating
        // Add 1 to avoid log(0)
        let frequencyScore = log(Double(entry.useCount + 1)) + 1
        
        // Combine scores
        let finalScore = positionScore * lengthPenalty * recencyScore * (1 + frequencyWeight * frequencyScore)
        
        return finalScore
    }
    
    func search(
        _ searchTerm: String,
        in entries: [AutocompleteEntry],
        limit: Int = 10,
        now: Date = Date()
    ) -> [(entry: AutocompleteEntry, score: Double)] {
        let scored = entries.compactMap { entry -> (AutocompleteEntry, Double)? in
            guard let score = score(entry: entry, searchTerm: searchTerm, now: now) else {
                return nil
            }
            return (entry, score)
        }
        
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(limit))
    }
}

// MARK: - Algorithm 2: Mozilla Firefox's Frecency Score

/// Implementation inspired by Mozilla Firefox's "frecency" algorithm.
///
/// Firefox combines frequency and recency using a bucketed time decay system.
/// Items are placed in time buckets, and each bucket has a different weight.
///
/// **Time buckets**:
/// - Last 4 days: 100% weight
/// - Last 14 days: 70% weight
/// - Last 31 days: 50% weight
/// - Last 90 days: 30% weight
/// - Older: 10% weight
///
/// The score also considers match position with significant bonuses for prefix matches.
struct FrecencyAlgorithm {
    enum TimeBucket {
        case last4Days
        case last14Days
        case last31Days
        case last90Days
        case older
        
        var weight: Double {
            switch self {
            case .last4Days: return 100
            case .last14Days: return 70
            case .last31Days: return 50
            case .last90Days: return 30
            case .older: return 10
            }
        }
        
        static func bucket(for daysSince: Double) -> TimeBucket {
            if daysSince < 4 { return .last4Days }
            if daysSince < 14 { return .last14Days }
            if daysSince < 31 { return .last31Days }
            if daysSince < 90 { return .last90Days }
            return .older
        }
    }
    
    /// Bonus points based on where the match occurs
    enum MatchBonus {
        case prefix        // Match at start: highest bonus
        case wordBoundary  // Match at word boundary: medium bonus
        case anywhere      // Match anywhere: base score
        
        var points: Double {
            switch self {
            case .prefix: return 200
            case .wordBoundary: return 150
            case .anywhere: return 100
            }
        }
    }
    
    func score(entry: AutocompleteEntry, searchTerm: String, now: Date = Date()) -> Double? {
        guard let matchRange = entry.text.range(of: searchTerm, options: .caseInsensitive) else {
            return nil
        }
        
        // Determine match bonus
        let matchBonus: MatchBonus
        if matchRange.lowerBound == entry.text.startIndex {
            matchBonus = .prefix
        } else {
            // Check if match is at a word boundary
            let precedingIndex = entry.text.index(before: matchRange.lowerBound)
            let precedingChar = entry.text[precedingIndex]
            matchBonus = precedingChar.isWhitespace || precedingChar == "-" || precedingChar == "_"
                ? .wordBoundary
                : .anywhere
        }
        
        // Calculate days since last use
        let daysSinceUse = abs(now.timeIntervalSince(entry.lastUsed)) / (60 * 60 * 24)
        let bucket = TimeBucket.bucket(for: daysSinceUse)
        
        // Frecency formula: (use count × time weight × match bonus) / 100
        let frecency = (Double(entry.useCount) * bucket.weight * matchBonus.points) / 100.0
        
        return frecency
    }
    
    func search(
        _ searchTerm: String,
        in entries: [AutocompleteEntry],
        limit: Int = 10,
        now: Date = Date()
    ) -> [(entry: AutocompleteEntry, score: Double)] {
        let scored = entries.compactMap { entry -> (AutocompleteEntry, Double)? in
            guard let score = score(entry: entry, searchTerm: searchTerm, now: now) else {
                return nil
            }
            return (entry, score)
        }
        
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(limit))
    }
}

// MARK: - Algorithm 3: Simple Ranking with Count Aging

/// A simpler approach that periodically ages the use count based on time elapsed.
///
/// This algorithm uses a straightforward scoring system but includes a mechanism
/// to gradually reduce the weight of old frequently-used entries.
///
/// **Scoring factors**:
/// - Position: Prefix matches get 2× multiplier
/// - Length: Shorter matches score higher
/// - Aged count: Use count is reduced by time elapsed
///
/// **Count aging**: The use count is "aged" by dividing by (1 + months_elapsed/12).
/// This means counts older than a year are effectively halved, preventing
/// old popular items from dominating indefinitely.
struct AgedCountAlgorithm {
    let prefixMultiplier: Double
    let agingFactor: Double  // How quickly counts decay (higher = faster decay)
    
    init(prefixMultiplier: Double = 2.0, agingFactor: Double = 1.0) {
        self.prefixMultiplier = prefixMultiplier
        self.agingFactor = agingFactor
    }
    
    /// Calculate an "aged" use count that decreases with time
    private func agedCount(originalCount: Int, lastUsed: Date, now: Date) -> Double {
        let monthsSinceUse = abs(now.timeIntervalSince(lastUsed)) / (60 * 60 * 24 * 30)
        
        // Aging formula: count / (1 + (months / 12) * agingFactor)
        // This means after 12 months with agingFactor=1.0, count is halved
        // After 24 months, it's divided by 3, etc.
        let ageReduction = 1.0 + (monthsSinceUse / 12.0) * agingFactor
        return Double(originalCount) / ageReduction
    }
    
    func score(entry: AutocompleteEntry, searchTerm: String, now: Date = Date()) -> Double? {
        guard let matchRange = entry.text.range(of: searchTerm, options: .caseInsensitive) else {
            return nil
        }
        
        // Position score
        let isPrefix = matchRange.lowerBound == entry.text.startIndex
        let positionMultiplier = isPrefix ? prefixMultiplier : 1.0
        
        // Length score: prefer shorter (more specific) matches
        // Score is inversely proportional to extra characters beyond the search term
        let extraChars = entry.text.count - searchTerm.count
        let lengthScore = 100.0 / (1.0 + Double(extraChars) / 5.0)
        
        // Aged count score
        let aged = agedCount(originalCount: entry.useCount, lastUsed: entry.lastUsed, now: now)
        
        // Final score: length × position × aged_count
        return lengthScore * positionMultiplier * aged
    }
    
    func search(
        _ searchTerm: String,
        in entries: [AutocompleteEntry],
        limit: Int = 10,
        now: Date = Date()
    ) -> [(entry: AutocompleteEntry, score: Double)] {
        let scored = entries.compactMap { entry -> (AutocompleteEntry, Double)? in
            guard let score = score(entry: entry, searchTerm: searchTerm, now: now) else {
                return nil
            }
            return (entry, score)
        }
        
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(limit))
    }
}

// MARK: - Test Data and Comparison

/// Test harness for comparing algorithms
struct AlgorithmComparison {
    static func generateTestData() -> [AutocompleteEntry] {
        let now = Date()
        
        return [
            // Recent, low count
            AutocompleteEntry(
                text: "color:red",
                lastUsed: now.addingTimeInterval(-2 * 24 * 60 * 60), // 2 days ago
                useCount: 3
            ),
            
            // Very old, high count (should be down-weighted)
            AutocompleteEntry(
                text: "color:blue",
                lastUsed: now.addingTimeInterval(-200 * 24 * 60 * 60), // 200 days ago
                useCount: 50
            ),
            
            // Moderate recency and count
            AutocompleteEntry(
                text: "color:green",
                lastUsed: now.addingTimeInterval(-15 * 24 * 60 * 60), // 15 days ago
                useCount: 10
            ),
            
            // Prefix match but longer
            AutocompleteEntry(
                text: "colorless",
                lastUsed: now.addingTimeInterval(-5 * 24 * 60 * 60), // 5 days ago
                useCount: 5
            ),
            
            // Substring match, recent
            AutocompleteEntry(
                text: "multicolor",
                lastUsed: now.addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
                useCount: 7
            ),
            
            // Very recent but low count
            AutocompleteEntry(
                text: "color:black",
                lastUsed: now.addingTimeInterval(-60 * 60), // 1 hour ago
                useCount: 1
            ),
            
            // Old but moderate count
            AutocompleteEntry(
                text: "color:white",
                lastUsed: now.addingTimeInterval(-60 * 24 * 60 * 60), // 60 days ago
                useCount: 15
            ),
        ]
    }
    
    static func runComparison() {
        let entries = generateTestData()
        let searchTerm = "color"
        
        print("=== Autocomplete Scoring Algorithm Comparison ===")
        print("Search term: '\(searchTerm)'")
        print("Test data: \(entries.count) entries\n")
        
        // Algorithm 1: Weighted Score
        print("--- Algorithm 1: Weighted Score with Time Decay ---")
        let weightedAlg = WeightedScoreAlgorithm()
        let weightedResults = weightedAlg.search(searchTerm, in: entries, limit: 5)
        for (index, result) in weightedResults.enumerated() {
            print("\(index + 1). \(result.entry.text) (score: \(String(format: "%.2f", result.score)))")
            print("   Used \(result.entry.useCount)x, last: \(formatDate(result.entry.lastUsed))")
        }
        
        print("\n--- Algorithm 2: Frecency (Firefox-inspired) ---")
        let frecencyAlg = FrecencyAlgorithm()
        let frecencyResults = frecencyAlg.search(searchTerm, in: entries, limit: 5)
        for (index, result) in frecencyResults.enumerated() {
            print("\(index + 1). \(result.entry.text) (score: \(String(format: "%.2f", result.score)))")
            print("   Used \(result.entry.useCount)x, last: \(formatDate(result.entry.lastUsed))")
        }
        
        print("\n--- Algorithm 3: Aged Count ---")
        let agedAlg = AgedCountAlgorithm()
        let agedResults = agedAlg.search(searchTerm, in: entries, limit: 5)
        for (index, result) in agedResults.enumerated() {
            print("\(index + 1). \(result.entry.text) (score: \(String(format: "%.2f", result.score)))")
            print("   Used \(result.entry.useCount)x, last: \(formatDate(result.entry.lastUsed))")
        }
        
        print("\n=== Analysis ===")
        print("• Weighted Score: Balances all factors smoothly with exponential decay")
        print("• Frecency: Uses bucketed time decay, heavily favors recent items")
        print("• Aged Count: Simplest approach, good for gradually expiring old favorites")
    }
    
    private static func formatDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / (60 * 60 * 24))
        
        if days == 0 {
            let hours = Int(interval / (60 * 60))
            return "\(hours)h ago"
        } else {
            return "\(days)d ago"
        }
    }
}

// MARK: - Notes on Existing Libraries

/*
 ## Existing Autocomplete/Fuzzy Search Libraries:
 
 ### 1. Fuse.swift
 - Port of Fuse.js fuzzy search library
 - Bitap algorithm for approximate string matching
 - Configurable threshold, distance, location scoring
 - Good for typo tolerance but adds complexity
 
 ### 2. SwiftFuzzyMatch
 - Levenshtein distance-based matching
 - Handles typos and misspellings
 - Can be slower on large datasets
 
 ### 3. Core Spotlight / NSUserActivity
 - Apple's built-in search indexing
 - Handles search ranking automatically
 - Integrates with system-wide search
 - Best for exposing app content to Spotlight
 
 ### 4. Roll-your-own with NSLinguisticTagger
 - Use Apple's natural language APIs
 - Can tokenize and analyze text
 - Overkill for simple autocomplete
 
 ## Recommendation:
 For your use case (substring matching with frequency/recency),
 the custom algorithms above are likely better than fuzzy search libraries.
 They're simpler, faster, and give you full control over scoring.
 
 If you need typo tolerance later, consider Fuse.swift or implementing
 a simple edit-distance check as a preprocessing step.
 */

