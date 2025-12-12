//
//  TimeWindowedScoring.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
//  Time-windowed autocomplete scoring with lazy aging and forgetting.
//

import Foundation

// MARK: - Time-Windowed Counts

/// Counts in overlapping time buckets (1d ⊂ 3d ⊂ 7d ⊂ 14d ⊂ 30d ⊂ 90d ⊂ 365d).
/// After 365 days, entries are forgotten (all counts become 0).
/// referenceDate tracks when counts were last accurate for lazy aging.
struct TimeBucketedCounts: Codable {
    let last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, last365Days: Int
    let referenceDate: Date
    
    /// Create a new empty count set
    static func new() -> TimeBucketedCounts {
        TimeBucketedCounts(0, 0, 0, 0, 0, 0, 0, Date())
    }
    
    /// Age counts by shifting buckets based on elapsed time.
    /// Conservative: assumes all uses in a bucket happened at the oldest time.
    /// Buckets are inclusive (30d contains 7d), so we preserve the larger bucket.
    /// After 365 days, all counts become 0 (forgotten).
    func aged(to now: Date = Date()) -> TimeBucketedCounts {
        let days = abs(now.timeIntervalSince(referenceDate)) / 86400
        guard days >= 1 else { return self }
        
        switch days {
        case 365...: return .init(0, 0, 0, 0, 0, 0, 0, now)  // Forgotten
        case 90..<365: return .init(0, 0, 0, 0, 0, 0, last90Days, now)
        case 30..<90: return .init(0, 0, 0, 0, 0, last30Days, last90Days, now)
        case 14..<30: return .init(0, 0, 0, 0, last14Days, last30Days, last90Days, now)
        case 7..<14: return .init(0, 0, 0, last7Days, last14Days, last30Days, last90Days, now)
        case 3..<7: return .init(0, 0, last3Days, last7Days, last14Days, last30Days, last90Days, now)
        case 1..<3: return .init(0, last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, now)
        default: return self
        }
    }
    
    /// Record a new use: age existing counts, then increment all buckets
    func recordingUse(at date: Date = Date()) -> TimeBucketedCounts {
        let aged = self.aged(to: date)
        return TimeBucketedCounts(
            aged.last1Day + 1,
            aged.last3Days + 1,
            aged.last7Days + 1,
            aged.last14Days + 1,
            aged.last30Days + 1,
            aged.last90Days + 1,
            aged.last365Days + 1,
            date
        )
    }
    
    /// Returns true if all counts are 0 (forgotten)
    var isForgotten: Bool {
        last365Days == 0
    }
    
    private init(_ d1: Int, _ d3: Int, _ d7: Int, _ d14: Int, _ d30: Int, _ d90: Int, _ d365: Int, _ ref: Date) {
        (last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, last365Days, referenceDate) = 
            (d1, d3, d7, d14, d30, d90, d365, ref)
    }
}

// MARK: - Scoring

/// Scores entries by weighting recent usage much higher than old usage.
/// Weights decay exponentially: 1d gets full weight, 365d gets almost nothing.
struct TimeWindowedScorer {
    private let weights = (d1: 1.0, d3: 0.85, d7: 0.7, d14: 0.5, d30: 0.3, d90: 0.15, d365: 0.05)
    
    /// Calculate effective count by weighting uses in different time windows
    func effectiveCount(from counts: TimeBucketedCounts, at date: Date = Date()) -> Double {
        // Age the counts first
        let c = counts.aged(to: date)
        
        // Convert inclusive buckets to exclusive
        let exclusive = (
            d1: c.last1Day,
            d3: c.last3Days - c.last1Day,
            d7: c.last7Days - c.last3Days,
            d14: c.last14Days - c.last7Days,
            d30: c.last30Days - c.last14Days,
            d90: c.last90Days - c.last30Days,
            d365: c.last365Days - c.last90Days
        )
        
        return Double(exclusive.d1) * weights.d1 +
               Double(exclusive.d3) * weights.d3 +
               Double(exclusive.d7) * weights.d7 +
               Double(exclusive.d14) * weights.d14 +
               Double(exclusive.d30) * weights.d30 +
               Double(exclusive.d90) * weights.d90 +
               Double(exclusive.d365) * weights.d365
    }
}
