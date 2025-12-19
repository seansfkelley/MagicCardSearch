//
//  HomeView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import SwiftUI
import ScryfallKit

struct HomeView: View {
    let searchHistoryTracker: SearchHistoryTracker
    let onSearchSelected: ([SearchFilter]) -> Void
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var selectedCardIndex: Int?
    
    private let featuredState = FeaturedCardsState.shared
    private let featuredCardLimit = 15
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Spoilers")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            switch featuredState.results {
                            case .loading(nil, _), .unloaded:
                                ForEach(0..<featuredCardLimit, id: \.self) { _ in
                                    ProgressView()
                                        .frame(width: 120, height: 168)
                                }
                            case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                                ForEach(Array(results.cards.prefix(featuredCardLimit).enumerated()), id: \.element.id) { index, card in
                                    Button {
                                        selectedCardIndex = index
                                    } label: {
                                        CardView(
                                            card: card,
                                            quality: .small,
                                            isFlipped: Binding(
                                                get: { cardFlipStates[card.id] ?? false },
                                                set: { cardFlipStates[card.id] = $0 }
                                            ),
                                            cornerRadius: 8,
                                        )
                                        .frame(width: 120)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if results.totalCount > featuredCardLimit {
                                    Button {
                                        onSearchSelected([
                                            .basic(.keyValue("date", .greaterThanOrEqual, "today")),
                                            .basic(.keyValue("order", .including, SortMode.spoiled.rawValue)),
                                            .basic(.keyValue("dir", .including, SortDirection.desc.rawValue)),
                                            .basic(.keyValue("unique", .including, UniqueMode.prints.rawValue)),
                                        ])
                                    } label: {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.accentColor, lineWidth: 2)
                                            .frame(width: 120, height: 168)
                                            .overlay {
                                                VStack(spacing: 8) {
                                                    Image(systemName: "arrow.right.circle.fill")
                                                        .font(.largeTitle)
                                                        .foregroundColor(.accentColor)
                                                    Text("View All")
                                                        .font(.subheadline)
                                                        .bold()
                                                        .foregroundColor(.accentColor)
                                                }
                                            }
                                    }
                                }
                            case .errored(nil, _):
                                EmptyView()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if !searchHistoryTracker.completeSearchEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Searches")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(searchHistoryTracker.completeSearchEntries.prefix(10).enumerated()), id: \.element.lastUsedDate) { index, entry in
                                Button {
                                    onSearchSelected(entry.filters)
                                } label: {
                                    HStack {
                                        Text(entry.filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " "))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        searchHistoryTracker.delete(filters: entry.filters)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                
                                if index < min(searchHistoryTracker.completeSearchEntries.count, 10) {
                                    Divider()
                                        .padding(.leading)
                                }
                            }
                        }
                        .background(Color(uiColor: .systemBackground))
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need Inspiration?")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(ExampleSearch.dailyExamples.enumerated()), id: \.element.title) { index, example in
                            Button {
                                onSearchSelected(example.filters)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(example.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(example.filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            
                            if index < ExampleSearch.dailyExamples.count - 1 {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .padding(.vertical)
        }
        .task {
            await loadFeaturedCards()
        }
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                state: featuredState,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates
            )
        }
    }
    
    private func loadFeaturedCards() async {
        guard case .unloaded = featuredState.results else {
            return
        }
        
        featuredState.results = .loading(nil, nil)
        
        let searchService = CardSearchService()
        
        do {
            let searchResult = try await searchService.search(
                filters: [
                    .basic(.keyValue("date", .greaterThanOrEqual, "today")),
                ],
                config: SearchConfiguration(
                    uniqueMode: .prints,
                    sortField: .spoiled,
                    sortOrder: .descending
                ),
            )
            let searchResults = SearchResults(
                totalCount: searchResult.totalCount,
                cards: searchResult.cards,
                warnings: searchResult.warnings,
                nextPageUrl: searchResult.nextPageURL,
            )

            featuredState.results = .loaded(searchResults, nil)
        } catch {
            print("Search error: \(error)")
            featuredState.results = .errored(featuredState.results.latestValue, SearchErrorState(from: error))
        }
    }
}
// MARK: - Featured Cards State

@MainActor
@Observable
private class FeaturedCardsState: SearchResultsState {
    static let shared = FeaturedCardsState()
}
// MARK: - Example Search

struct ExampleSearch {
    let title: String
    let filters: [SearchFilter]
    
    private static let small: [ExampleSearch] = [
        .init(title: "All Modern-Legal U/R Pingers", filters: [
            .basic(.keyValue("color", .lessThanOrEqual, "ur")),
            .basic(.keyValue("function", .including, "pinger")),
            .basic(.keyValue("format", .including, "modern")),
        ]),
    ]
    
    private static let medium: [ExampleSearch] = [
        .init(title: "Most Expensive 1-Drops in Standard", filters: [
            .basic(.keyValue("manavalue", .equal, "1")),
            .basic(.keyValue("format", .including, "standard")),
            .basic(.keyValue("order", .including, "usd")),
            .basic(.keyValue("dir", .including, "desc")),
        ]),
    ]
    
    private static let large: [ExampleSearch] = [
        .init(title: "Best Orzhov Commanders", filters: [
            .basic(.keyValue("id", .equal, "orzhov")),
            .basic(.keyValue("type", .including, "legendary")),
            .basic(.keyValue("type", .including, "creature")),
            .basic(.keyValue("format", .including, "commander")),
            .basic(.keyValue("order", .including, "edhrec")),
            .basic(.keyValue("dir", .including, "desc")),
        ]),
    ]
    
    private static func dailySeed() -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }
    
    static var dailyExamples: [ExampleSearch] {
        let seed = dailySeed()
        // Swift doesn't have seedable RNGs in the standard library, so just bang together a one-off
        // calculation for our purposes.
        return [
            small[seed.hashValue % small.count],
            medium[(seed * 31).hashValue % medium.count],
            large[(seed * 97).hashValue % large.count],
        ]
    }
}
