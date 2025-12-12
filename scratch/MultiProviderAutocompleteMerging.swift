//
//  MultiProviderAutocompleteMerging.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//

import Foundation

// MARK: - Provider Protocol

/// Protocol that autocomplete providers must implement to participate in multi-provider merging.
///
/// Different providers have different characteristics:
/// - **History providers**: Start weak with few characters, get stronger as query grows
/// - **Static/enumeration providers**: Strong even with 1 character (e.g., "r" → "rarity:")
/// - **API/search providers**: May require minimum query length, variable quality
///
/// The key insight: providers should expose metadata about their confidence and relevance,
/// not just return scored results.
protocol AutocompleteSuggestionProvider {
    associatedtype SuggestionType
    
    /// The unique identifier for this provider (e.g., "history", "filter-types", "card-names")
    var providerId: String { get }
    
    /// Returns suggestions with provider-specific scores
    func suggestions(for query: String, limit: Int) -> [ScoredSuggestion<SuggestionType>]
    
    /// Returns metadata about how this provider behaves with different query lengths
    var characteristics: ProviderCharacteristics { get }
}

/// Describes how a provider's effectiveness changes with query length
struct ProviderCharacteristics {
    /// Minimum query length for meaningful results (0 = works with empty query)
    let minimumQueryLength: Int
    
    /// How much to trust this provider at different query lengths
    /// This is a multiplier applied to the provider's scores
    let confidenceCurve: ConfidenceCurve
    
    /// The typical score range this provider returns
    /// Used for normalization across providers
    let scoreRange: ClosedRange<Double>
    
    /// Priority tier: higher tier providers get precedence in tie-breaking
    /// Useful for favoring certain types of suggestions (e.g., exact matches over fuzzy)
    let priorityTier: Int
    
    enum ConfidenceCurve {
        /// Confidence increases with query length (typical for history/fuzzy search)
        case increasing
        
        /// Confidence is constant regardless of query length (typical for enumerations)
        case constant(Double)
        
        /// Confidence follows a custom function of query length
        case custom((Int) -> Double)
        
        func confidence(forQueryLength length: Int) -> Double {
            switch self {
            case .increasing:
                // Sigmoid-like curve: starts low, increases rapidly, plateaus
                // At length 1: ~0.3, at length 3: ~0.7, at length 5+: ~0.95
                let normalized = Double(length) / 5.0
                return 1.0 / (1.0 + exp(-3.0 * (normalized - 0.5)))
                
            case .constant(let value):
                return value
                
            case .custom(let function):
                return function(length)
            }
        }
    }
}

/// A suggestion with its provider-specific score and metadata
struct ScoredSuggestion<T> {
    let suggestion: T
    let score: Double
    let providerId: String
    
    /// Optional: additional context for debugging or display
    let metadata: [String: String]?
    
    init(suggestion: T, score: Double, providerId: String, metadata: [String: String]? = nil) {
        self.suggestion = suggestion
        self.score = score
        self.providerId = providerId
        self.metadata = metadata
    }
}

// MARK: - Algorithm 1: Weighted Round-Robin Merging

/// Merges suggestions by interleaving results from multiple providers based on their confidence.
///
/// **Strategy**:
/// - Each provider gets a "budget" of slots based on its confidence at the current query length
/// - Providers take turns filling slots, weighted by their budget
/// - Within each provider's results, items are ordered by their normalized scores
///
/// **Example**: With 10 total slots and 3 providers with confidence [0.7, 0.2, 0.1]:
/// - Provider A gets ~7 slots (70%)
/// - Provider B gets ~2 slots (20%)
/// - Provider C gets ~1 slot (10%)
///
/// **Advantages**:
/// - Simple to understand and implement
/// - Guarantees representation from each confident provider
/// - Prevents one provider from dominating
///
/// **Disadvantages**:
/// - May include lower-quality results from less confident providers
/// - Fixed slot allocation doesn't adapt to actual result quality
struct WeightedRoundRobinMerger {
    
    func merge<T>(
        results: [(provider: any AutocompleteSuggestionProvider, suggestions: [ScoredSuggestion<T>])],
        queryLength: Int,
        limit: Int
    ) -> [MergedSuggestion<T>] {
        // Calculate confidence weights for each provider
        let weights = results.map { result in
            let confidence = result.provider.characteristics.confidenceCurve.confidence(forQueryLength: queryLength)
            let meetsMinimum = queryLength >= result.provider.characteristics.minimumQueryLength
            return meetsMinimum ? confidence : 0.0
        }
        
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return [] }
        
        // Normalize weights to sum to 1.0
        let normalizedWeights = weights.map { $0 / totalWeight }
        
        // Calculate slot budgets for each provider
        var budgets = normalizedWeights.map { $0 * Double(limit) }
        
        // Normalize scores within each provider
        var normalizedResults: [[(suggestion: ScoredSuggestion<T>, normalizedScore: Double)]] = []
        for (index, result) in results.enumerated() {
            let scoreRange = result.provider.characteristics.scoreRange
            let normalized = result.suggestions.map { suggestion in
                let normalizedScore = (suggestion.score - scoreRange.lowerBound) / 
                                     (scoreRange.upperBound - scoreRange.lowerBound)
                return (suggestion, normalizedScore * weights[index])
            }
            normalizedResults.append(normalized)
        }
        
        // Round-robin merge with weighted budgets
        var merged: [MergedSuggestion<T>] = []
        var indices = Array(repeating: 0, count: results.count)
        
        while merged.count < limit {
            var addedThisRound = false
            
            // Try to add one item from each provider that has budget remaining
            for providerIndex in 0..<results.count {
                guard merged.count < limit else { break }
                guard budgets[providerIndex] >= 0.5 else { continue } // Need at least half a slot
                guard indices[providerIndex] < normalizedResults[providerIndex].count else { continue }
                
                let item = normalizedResults[providerIndex][indices[providerIndex]]
                merged.append(MergedSuggestion(
                    suggestion: item.suggestion.suggestion,
                    finalScore: item.normalizedScore,
                    providerId: item.suggestion.providerId,
                    providerRank: indices[providerIndex],
                    metadata: item.suggestion.metadata
                ))
                
                indices[providerIndex] += 1
                budgets[providerIndex] -= 1.0
                addedThisRound = true
            }
            
            // If no provider could contribute, we're done
            if !addedThisRound {
                break
            }
        }
        
        return merged
    }
}

// MARK: - Algorithm 2: Score-Based Merging with Provider Boosting

/// Merges suggestions by globally ranking all results, but applying provider-specific boosts.
///
/// **Strategy**:
/// - Normalize all scores to a common range [0, 1]
/// - Apply confidence multiplier based on query length
/// - Apply priority tier bonuses
/// - Sort globally by adjusted scores
///
/// **Score formula**:
/// ```
/// adjusted_score = normalized_score × confidence(query_length) × tier_multiplier
/// ```
///
/// **Advantages**:
/// - Always shows the "best" results according to combined criteria
/// - Natural quality threshold (poor results from any provider rank low)
/// - Simple mental model: higher scores win
///
/// **Disadvantages**:
/// - One highly confident provider can completely dominate results
/// - May show zero results from some providers even if they have relevant suggestions
struct ScoreBasedMerger {
    /// Multiplier applied for each priority tier above 0
    let tierBonusMultiplier: Double
    
    init(tierBonusMultiplier: Double = 1.5) {
        self.tierBonusMultiplier = tierBonusMultiplier
    }
    
    func merge<T>(
        results: [(provider: any AutocompleteSuggestionProvider, suggestions: [ScoredSuggestion<T>])],
        queryLength: Int,
        limit: Int
    ) -> [MergedSuggestion<T>] {
        var allSuggestions: [MergedSuggestion<T>] = []
        
        for result in results {
            let provider = result.provider
            let characteristics = provider.characteristics
            
            // Skip if query is too short for this provider
            guard queryLength >= characteristics.minimumQueryLength else { continue }
            
            // Calculate provider confidence at this query length
            let confidence = characteristics.confidenceCurve.confidence(forQueryLength: queryLength)
            
            // Calculate tier bonus (exponential: tier 0 = 1.0x, tier 1 = 1.5x, tier 2 = 2.25x, etc.)
            let tierBonus = pow(tierBonusMultiplier, Double(characteristics.priorityTier))
            
            // Normalize and boost each suggestion
            let scoreRange = characteristics.scoreRange
            for (rank, suggestion) in result.suggestions.enumerated() {
                // Normalize score to [0, 1]
                let normalizedScore = (suggestion.score - scoreRange.lowerBound) / 
                                     (scoreRange.upperBound - scoreRange.lowerBound)
                
                // Apply confidence and tier multipliers
                let adjustedScore = normalizedScore * confidence * tierBonus
                
                allSuggestions.append(MergedSuggestion(
                    suggestion: suggestion.suggestion,
                    finalScore: adjustedScore,
                    providerId: suggestion.providerId,
                    providerRank: rank,
                    metadata: suggestion.metadata
                ))
            }
        }
        
        // Sort by adjusted score (descending) and take top N
        return Array(allSuggestions.sorted { $0.finalScore > $1.finalScore }.prefix(limit))
    }
}

// MARK: - Algorithm 3: Category-Based Merging with Dynamic Allocation

/// Merges suggestions by grouping providers into categories and dynamically allocating slots.
///
/// **Strategy**:
/// - Providers are organized into categories (e.g., "exact-matches", "history", "suggestions")
/// - Each category gets a slot range (min-max) based on query length and confidence
/// - Within each category, select the best results
/// - Fill remaining slots with overflow from the highest-quality category
///
/// **Example configuration**:
/// ```
/// Query length 1-2:
///   - Exact matches: 3-5 slots
///   - Filter types: 2-4 slots
///   - History: 0-1 slots
///
/// Query length 3+:
///   - Exact matches: 2-3 slots
///   - Filter types: 1-2 slots
///   - History: 2-5 slots
/// ```
///
/// **Advantages**:
/// - Explicit control over result composition
/// - Can ensure specific types of results are always present
/// - Adapts naturally to query length
///
/// **Disadvantages**:
/// - More configuration required
/// - Category definitions may not fit all use cases
/// - Can feel "artificial" if category boundaries are visible to users
struct CategoryBasedMerger {
    
    struct CategoryConfig {
        let categoryId: String
        let providerIds: Set<String>
        let slotAllocation: (Int) -> ClosedRange<Int>  // Function of query length
    }
    
    let categories: [CategoryConfig]
    
    func merge<T>(
        results: [(provider: any AutocompleteSuggestionProvider, suggestions: [ScoredSuggestion<T>])],
        queryLength: Int,
        limit: Int
    ) -> [MergedSuggestion<T>] {
        // Group results by category
        var categorizedResults: [String: [(provider: any AutocompleteSuggestionProvider, suggestions: [ScoredSuggestion<T>])]] = [:]
        
        for result in results {
            for category in categories {
                if category.providerIds.contains(result.provider.providerId) {
                    categorizedResults[category.categoryId, default: []].append(result)
                    break
                }
            }
        }
        
        // Allocate slots to each category
        var categorySlots: [String: Int] = [:]
        var totalMinimumSlots = 0
        
        for category in categories {
            let range = category.slotAllocation(queryLength)
            categorySlots[category.categoryId] = range.lowerBound
            totalMinimumSlots += range.lowerBound
        }
        
        // Distribute remaining slots proportionally to category maximums
        var remainingSlots = limit - totalMinimumSlots
        while remainingSlots > 0 {
            var bestCategory: String?
            var bestNeed: Double = 0
            
            for category in categories {
                let currentSlots = categorySlots[category.categoryId] ?? 0
                let range = category.slotAllocation(queryLength)
                let maxSlots = range.upperBound
                
                if currentSlots < maxSlots {
                    // Calculate "need" as (max - current) / max
                    let need = Double(maxSlots - currentSlots) / Double(maxSlots)
                    if need > bestNeed {
                        bestNeed = need
                        bestCategory = category.categoryId
                    }
                }
            }
            
            guard let category = bestCategory else { break }
            categorySlots[category, default: 0] += 1
            remainingSlots -= 1
        }
        
        // Fill slots for each category
        var merged: [MergedSuggestion<T>] = []
        
        for category in categories {
            let slots = categorySlots[category.categoryId] ?? 0
            guard slots > 0 else { continue }
            guard let categoryResults = categorizedResults[category.categoryId] else { continue }
            
            // Merge results within this category using score-based approach
            let categoryMerger = ScoreBasedMerger()
            let categoryMerged = categoryMerger.merge(
                results: categoryResults,
                queryLength: queryLength,
                limit: slots
            )
            
            merged.append(contentsOf: categoryMerged)
        }
        
        return Array(merged.prefix(limit))
    }
}

// MARK: - Merged Result Type

/// The final merged suggestion with metadata about its origin and scoring
struct MergedSuggestion<T> {
    let suggestion: T
    let finalScore: Double
    let providerId: String
    let providerRank: Int  // Original rank within the provider's results
    let metadata: [String: String]?
}

// MARK: - Example Provider Implementations

/// Example: History-based provider with increasing confidence
struct HistoryProvider: AutocompleteSuggestionProvider {
    let providerId = "history"
    
    let characteristics = ProviderCharacteristics(
        minimumQueryLength: 0,
        confidenceCurve: .increasing,  // Weak with 1 char, strong with 3+
        scoreRange: 0...100,
        priorityTier: 0  // Base priority
    )
    
    func suggestions(for query: String, limit: Int) -> [ScoredSuggestion<String>] {
        // Mock implementation
        return [
            ScoredSuggestion(suggestion: "color:red", score: 85, providerId: providerId),
            ScoredSuggestion(suggestion: "color:blue", score: 72, providerId: providerId),
            ScoredSuggestion(suggestion: "colorless", score: 45, providerId: providerId),
        ]
    }
}

/// Example: Filter type provider with constant high confidence
struct FilterTypeProvider: AutocompleteSuggestionProvider {
    let providerId = "filter-types"
    
    let characteristics = ProviderCharacteristics(
        minimumQueryLength: 1,  // Needs at least one character
        confidenceCurve: .constant(0.95),  // Always highly confident
        scoreRange: 0...100,
        priorityTier: 1  // Higher priority than history
    )
    
    func suggestions(for query: String, limit: Int) -> [ScoredSuggestion<String>] {
        // Mock implementation - these should be high-quality even with 1 char
        return [
            ScoredSuggestion(suggestion: "color:", score: 95, providerId: providerId),
            ScoredSuggestion(suggestion: "commander:", score: 88, providerId: providerId),
        ]
    }
}

/// Example: Enumeration values provider
struct EnumerationProvider: AutocompleteSuggestionProvider {
    let providerId = "enumerations"
    
    let characteristics = ProviderCharacteristics(
        minimumQueryLength: 0,  // Can show all options with empty query
        confidenceCurve: .constant(0.90),
        scoreRange: 0...100,
        priorityTier: 2  // Highest priority - exact matches
    )
    
    func suggestions(for query: String, limit: Int) -> [ScoredSuggestion<String>] {
        // Mock implementation - prefix matches get high scores
        return [
            ScoredSuggestion(suggestion: "mythic", score: 100, providerId: providerId),
            ScoredSuggestion(suggestion: "rare", score: 98, providerId: providerId),
        ]
    }
}

// MARK: - Test Harness

struct MultiProviderMergingTests {
    static func runTests() {
        print("=== Multi-Provider Autocomplete Merging Tests ===\n")
        
        // Create providers
        let historyProvider = HistoryProvider()
        let filterTypeProvider = FilterTypeProvider()
        let enumerationProvider = EnumerationProvider()
        
        // Test Case 1: Short query (1 character)
        print("--- Test Case 1: Query = 'c' (1 character) ---")
        testMerging(
            query: "c",
            providers: [historyProvider, filterTypeProvider, enumerationProvider]
        )
        
        // Test Case 2: Medium query (3 characters)
        print("\n--- Test Case 2: Query = 'col' (3 characters) ---")
        testMerging(
            query: "col",
            providers: [historyProvider, filterTypeProvider, enumerationProvider]
        )
        
        // Test Case 3: Long query (5+ characters)
        print("\n--- Test Case 3: Query = 'color' (5 characters) ---")
        testMerging(
            query: "color",
            providers: [historyProvider, filterTypeProvider, enumerationProvider]
        )
    }
    
    private static func testMerging(
        query: String,
        providers: [any AutocompleteSuggestionProvider]
    ) {
        let limit = 5
        
        // Gather results from all providers
        let results: [(provider: any AutocompleteSuggestionProvider, suggestions: [ScoredSuggestion<String>])] = []
//            providers.map { provider in
//                (provider, provider.suggestions(for: query, limit: limit))
//            }
        
        // Test Algorithm 1: Weighted Round-Robin
        print("\nAlgorithm 1: Weighted Round-Robin")
        let roundRobinMerger = WeightedRoundRobinMerger()
        let roundRobinResults = roundRobinMerger.merge(
            results: results,
            queryLength: query.count,
            limit: limit
        )
        printResults(roundRobinResults)
        
        // Test Algorithm 2: Score-Based
        print("\nAlgorithm 2: Score-Based with Provider Boosting")
        let scoreMerger = ScoreBasedMerger()
        let scoreResults = scoreMerger.merge(
            results: results,
            queryLength: query.count,
            limit: limit
        )
        printResults(scoreResults)
        
        // Test Algorithm 3: Category-Based
        print("\nAlgorithm 3: Category-Based Dynamic Allocation")
        let categoryMerger = CategoryBasedMerger(categories: [
            CategoryBasedMerger.CategoryConfig(
                categoryId: "exact",
                providerIds: ["enumerations"],
                slotAllocation: { queryLength in
                    queryLength <= 2 ? (2...3) : (1...2)
                }
            ),
            CategoryBasedMerger.CategoryConfig(
                categoryId: "filters",
                providerIds: ["filter-types"],
                slotAllocation: { queryLength in
                    queryLength <= 2 ? (2...3) : (1...2)
                }
            ),
            CategoryBasedMerger.CategoryConfig(
                categoryId: "history",
                providerIds: ["history"],
                slotAllocation: { queryLength in
                    queryLength <= 2 ? (0...1) : (2...4)
                }
            ),
        ])
        let categoryResults = categoryMerger.merge(
            results: results,
            queryLength: query.count,
            limit: limit
        )
        printResults(categoryResults)
    }
    
    private static func printResults(_ results: [MergedSuggestion<String>]) {
        for (index, result) in results.enumerated() {
            print("  \(index + 1). \(result.suggestion)")
            print("     Score: \(String(format: "%.3f", result.finalScore)), Provider: \(result.providerId) (rank \(result.providerRank))")
        }
    }
}

// MARK: - Implementation Notes

/*
 ## Key Insights for Multi-Provider Merging:
 
 ### 1. The Core Problem
 Different providers have different "sweet spots":
 - **Static providers** (filter types, enumerations): Great with 1-2 characters
 - **History providers**: Need 3+ characters to be meaningful
 - **API providers**: May need minimum query length, have variable latency
 
 ### 2. What Providers Must Expose
 To merge effectively, providers should provide:
 
 ✅ **Confidence curve**: How trustworthy are results at different query lengths?
 ✅ **Score range**: What's the typical min/max score for normalization?
 ✅ **Minimum query length**: When should this provider activate?
 ✅ **Priority tier**: For tie-breaking between similar scores
 
 ### 3. Algorithm Selection Guide
 
 **Use Weighted Round-Robin when**:
 - You want guaranteed diversity in results
 - No single provider should dominate
 - Users expect to see multiple types of suggestions
 - Example: Email autocomplete (contacts + history + suggestions)
 
 **Use Score-Based when**:
 - Quality is paramount
 - You trust your scoring and normalization
 - Users expect the "best" results regardless of source
 - Example: Search engines, code completion
 
 **Use Category-Based when**:
 - You have distinct suggestion types with clear roles
 - You want explicit control over result composition
 - Different categories serve different user needs
 - Example: IDE autocomplete (keywords, variables, methods, snippets)
 
 ### 4. Reconciling Static vs. History Providers
 
 The key insight: **confidence should scale with query length differently**:
 
 ```
 Query length:    1    2    3    4    5+
 Filter types:   95%  95%  95%  95%  95%  (constant high)
 Enumerations:   90%  90%  90%  90%  90%  (constant high)
 History:        30%  50%  75%  90%  95%  (increasing)
 API search:     0%   0%   60%  80%  90%  (late start, then increasing)
 ```
 
 This means:
 - With 1 character: filter types dominate (0.95 vs 0.30)
 - With 5 characters: all providers are competitive
 - History results improve as query becomes more specific
 
 ### 5. Performance Considerations
 
 - **Lazy evaluation**: Don't call all providers immediately
 - **Debouncing**: Wait for user to pause typing before querying expensive providers
 - **Caching**: Cache provider results, especially for static data
 - **Async**: Call providers concurrently, show results as they arrive
 - **Minimum score threshold**: Filter out low-scoring results before merging
 
 ### 6. UI Considerations
 
 - **Visual grouping**: Consider showing provider labels ("Recent", "Filters", etc.)
 - **Progressive disclosure**: Show top category results first, others on demand
 - **Scoring transparency**: Show why a result ranked high (debug mode)
 
 ## Integration with Existing AutocompleteProvider
 
 Your current `AutocompleteProvider` could be refactored:
 
 1. Split into multiple providers:
    - `HistoryProvider` (existing history logic)
    - `FilterTypeProvider` (existing getFilterTypeSuggestions)
    - `EnumerationProvider` (existing getEnumerationSuggestion)
 
 2. Each implements the `AutocompleteSuggestionProvider` protocol
 
 3. A `CompositeAutocompleteProvider` uses one of these merging algorithms
 
 4. The view stays the same, just calls the composite provider
 */

