//
//  HomeView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import SwiftUI
import ScryfallKit
import Logging

private let logger = Logger(label: "HomeView")

private struct PlainStyling: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .textCase(.none)
            .foregroundStyle(.primary)
            .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
    }
}

private extension View {
    func plainStyling() -> some View {
        modifier(PlainStyling())
    }
}

struct HomeView: View {
    let searchHistoryTracker: SearchHistoryTracker
    let onSearchSelected: ([SearchFilter]) -> Void
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var selectedCardIndex: Int?
    
    private let featuredState = FeaturedCardsState.shared
    private let featuredWidth: CGFloat = 120
    
    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        switch featuredState.results {
                        case .loading(nil, _), .unloaded:
                            ForEach(0..<15, id: \.self) { _ in
                                CardPlaceholderView(name: nil, cornerRadius: 8, withSpinner: true)
                                    .frame(width: featuredWidth, height: featuredWidth / Card.aspectRatio)
                            }
                        case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                            ForEach(Array(results.cards.enumerated()), id: \.element.id) { index, card in
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
                                    .frame(width: featuredWidth)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if index == results.cards.count - 3 {
                                        featuredState.loadNextPageIfNeeded()
                                    }
                                }
                            }
                            
                            if case .loading = featuredState.results, results.nextPageUrl != nil {
                                ProgressView()
                                    .frame(width: featuredWidth, height: featuredWidth / Card.aspectRatio)
                            }
                        case .errored(nil, _):
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                }
            } header: {
                HStack {
                    Text("Recent Spoilers")
                    
                    Spacer()
                    
                    Button(action: {
                        onSearchSelected([
                            .init(.keyValue("date", .greaterThanOrEqual, "today")),
                            .init(.keyValue("order", .including, SortMode.spoiled.rawValue)),
                            .init(.keyValue("dir", .including, SortDirection.desc.rawValue)),
                            .init(.keyValue("unique", .including, UniqueMode.prints.rawValue)),
                        ])
                    }) {
                        Text("View All")
                    }
                }
                .padding(.horizontal)
            }
            .listRowInsets(.horizontal, 0)
            .listSectionMargins(.horizontal, 0)
            
            if !searchHistoryTracker.completeSearchEntries.isEmpty {
                Section {
                    ForEach(Array(searchHistoryTracker.completeSearchEntries.prefix(10).enumerated()), id: \.element.lastUsedDate) { _, entry in
                        Button {
                            onSearchSelected(entry.filters)
                        } label: {
                            HStack {
                                Text(entry.filters.map { $0.description }.joined(separator: " "))
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer()
                            }
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
                    }
                } header: {
                    Text("Recent Searches")
                        .padding(.horizontal)
                }
                .listRowInsets(.horizontal, 0)
                .listSectionMargins(.horizontal, 0)
            }
            
            Section {
                ForEach(Array(ExampleSearch.dailyExamples.enumerated()), id: \.element.title) { _, example in
                    Button {
                        onSearchSelected(example.filters)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(example.filters.map { $0.description }.joined(separator: " "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Need Inspiration?")
                    .padding(.horizontal)
            }
            .listRowInsets(.horizontal, 0)
            .listSectionMargins(.horizontal, 0)
        }
        .task {
            if isRunningTests() {
                logger.info("Skipping featured card load in test environment")
            } else {
                await loadFeaturedCards()
            }
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
                    .init(.keyValue("date", .greaterThanOrEqual, "today")),
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
            .init(.keyValue("color", .lessThanOrEqual, "ur")),
            .init(.keyValue("function", .including, "pinger")),
            .init(.keyValue("format", .including, "modern")),
        ]),
    ]
    
    private static let medium: [ExampleSearch] = [
        .init(title: "Most Expensive 1-Drops in Standard", filters: [
            .init(.keyValue("manavalue", .equal, "1")),
            .init(.keyValue("format", .including, "standard")),
            .init(.keyValue("order", .including, "usd")),
            .init(.keyValue("dir", .including, "desc")),
        ]),
    ]
    
    private static let large: [ExampleSearch] = [
        .init(title: "Best Orzhov Commanders", filters: [
            .init(.keyValue("id", .equal, "orzhov")),
            .init(.keyValue("type", .including, "legendary")),
            .init(.keyValue("type", .including, "creature")),
            .init(.keyValue("format", .including, "commander")),
            .init(.keyValue("order", .including, "edhrec")),
            .init(.keyValue("dir", .including, "desc")),
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
