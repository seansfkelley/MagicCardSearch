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
                        switch featuredState.current {
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
                            
                            if case .loading = featuredState.current, results.nextPageUrl != nil {
                                ProgressView()
                                    .frame(width: featuredWidth, height: featuredWidth / Card.aspectRatio)
                            }
                        case .errored(nil, let error):
                            ContentUnavailableView(
                                "Unable to Load Spoilers",
                                systemImage: "exclamationmark.triangle",
                                description: Text(error.description),
                            )
                            .frame(width: featuredWidth * 2, height: featuredWidth / Card.aspectRatio)
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
                            SearchFilter.basic(false, "date", .greaterThanOrEqual, "today"),
                            SearchFilter.basic(false, "order", .including, SortMode.spoiled.rawValue),
                            SearchFilter.basic(false, "dir", .including, SortDirection.desc.rawValue),
                            SearchFilter.basic(false, "unique", .including, UniqueMode.prints.rawValue),
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
                    ForEach(searchHistoryTracker.completeSearchEntries.prefix(10), id: \.lastUsedDate) { entry in
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
                                searchHistoryTracker.deleteSearch(with: entry.filters)
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
                ForEach(ExampleSearch.dailyExamples, id: \.title) { example in
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
        guard case .unloaded = featuredState.current else {
            return
        }
        
        featuredState.current = .loading(nil, nil)
        
        let searchService = CardSearchService()
        
        do {
            let searchResults = try await searchService.search(
                filters: [
                    SearchFilter.basic(false, "date", .greaterThanOrEqual, "today"),
                ],
                config: SearchConfiguration(
                    uniqueMode: .prints,
                    sortField: .spoiled,
                    sortOrder: .descending
                ),
            )
            featuredState.current = .loaded(searchResults, nil)
        } catch {
            print("Search error: \(error)")
            featuredState.current = .errored(featuredState.current.latestValue, SearchErrorState(from: error))
        }
    }
}
// MARK: - Featured Cards State

@MainActor
@Observable
private class FeaturedCardsState: ScryfallSearchResultsList {
    static let shared = FeaturedCardsState()
}
// MARK: - Example Search

struct ExampleSearch: Hashable {
    let title: String
    let filters: [SearchFilter]
    
    private static let examples: [ExampleSearch] = [
        .init(title: "Modern-Legal U/R Pingers", filters: [
            .basic(false, "color", .lessThanOrEqual, "ur"),
            .basic(false, "function", .including, "pinger"),
            .basic(false, "format", .including, "modern"),
        ]),
        .init(title: "Biggest Dragons", filters: [
            .basic(false, "type", .including, "dragon"),
            .basic(false, "order", .including, "power"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "Most Devoted Green Permanents", filters: [
            .basic(false, "devotion", .greaterThanOrEqual, "gggg"),
            .basic(false, "order", .including, "manavalue"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "All Non-basic-land Textless Cards", filters: [
            .basic(false, "is", .including, "textless"),
            .basic(true, "type", .including, "basic"),
        ]),
        .init(title: "Five-color Artifacts", filters: [
            .basic(false, "type", .including, "artifact"),
            .basic(false, "id", .equal, "5"),
        ]),
        .init(title: "Real Cards with Funny Rulings", filters: [
            .basic(false, "function", .including, "fun-ruling"),
            .basic(true, "is", .including, "funny"),
        ]),
        .init(title: "Future Sight Frames", filters: [
            .basic(false, "frame", .including, "future"),
        ]),
        .init(title: "Cheap, Top-heavy Red Creatures", filters: [
            .basic(false, "power", .greaterThan, "toughness"),
            .basic(false, "color", .equal, "red"),
            .basic(false, "manavalue", .lessThanOrEqual, "2"),
        ]),
        .init(title: "White Self-sacrifice", filters: [
            .basic(false, "color", .including, "white"),
            .regex(false, "oracle", .including, "^sacrifice ~"),
        ]),
        .init(title: "Most Expensive 1-Drops in Standard", filters: [
            .basic(false, "manavalue", .equal, "1"),
            .basic(false, "format", .including, "standard"),
            .basic(false, "order", .including, "usd"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "Best Boros Combat Tricks", filters: [
            .basic(false, "color", .lessThanOrEqual, "boros"),
            .basic(false, "function", .including, "combat-trick"),
            .basic(false, "order", .including, "edhrec"),
            .basic(false, "dir", .including, "asc"),
        ]),
        .init(title: "Best Orzhov Commanders", filters: [
            .basic(false, "id", .equal, "orzhov"),
            .basic(false, "type", .including, "legendary"),
            .basic(false, "type", .including, "creature"),
            .basic(false, "format", .including, "commander"),
            .basic(false, "order", .including, "edhrec"),
            .basic(false, "dir", .including, "asc"),
        ]),
        .init(title: "Muraganda Petroglyphs Creatures", filters: [
            .basic(false, "type", .including, "creature"),
            .basic(false, "is", .including, "vanilla"),
            .basic(true, "is", .including, "token"),
        ]),
        .init(title: "Morphling and Friends", filters: [
            .regex(false, "name", .including, "^[^\\s]+ling$"),
            .basic(false, "type", .including, "shapeshifter"),
        ]),
        .init(title: "Stained Glass", filters: [
            .basic(false, "art", .including, "stained-glass"),
        ]),
        .init(title: "Green Can Do Anything", filters: [
            .basic(false, "color", .including, "green"),
            .basic(false, "function", .including, "color-break"),
        ]),
        .init(title: "Dog Tongues", filters: [
            .basic(false, "art", .including, "dog"),
            .basic(false, "art", .including, "tongue-sticking-out"),
        ]),
        .init(title: "Most Color-committed Cards", filters: [
            .basic(false, "color", .equal, "1"),
            .basic(true, "mana", .including, "{1}"),
            .basic(true, "is", .including, "hybrid"),
            .basic(false, "manavalue", .greaterThanOrEqual, "4"),
        ]),
    ]
    
    private static func dailySeed() -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (components.year ?? 0) * 97 + (components.month ?? 0) * 31 + (components.day ?? 0)
    }
    
    static var dailyExamples: [ExampleSearch] {
        // Swift doesn't have seedable RNGs in the standard library, so just bang together a one-off
        // calculation for our purposes. This is so it doesn't change every. single. time. it renders.
        let seed = dailySeed()

        var chosenExamples: [ExampleSearch] = []
        for i in [7, 37, 89] {
            for j in 0..<examples.count {
                let example = examples[(seed * i + j) % examples.count]
                if !chosenExamples.contains(example) {
                    chosenExamples.append(example)
                    break
                }
            }
        }
        return chosenExamples
    }
}
