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
                    Text("Featured")
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
                                            .basic(.keyValue("set", .including, "ecl"))
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
                        
                        List {
                            ForEach(Array(searchHistoryTracker.completeSearchEntries.prefix(10).enumerated()), id: \.element.lastUsedDate) { _, entry in
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
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        searchHistoryTracker.delete(filters: entry.filters)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowSeparator(.visible)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(min(10, searchHistoryTracker.completeSearchEntries.count)) * 70)
                        .scrollDisabled(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Searches")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(ExampleSearch.examples.enumerated()), id: \.element.title) { index, example in
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
                                
                                if index < ExampleSearch.examples.count - 1 {
                                    Divider()
                                        .padding(.leading)
                                }
                            }
                        }
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
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
        
        do {
            let filters: [SearchFilter] = [.basic(.keyValue("set", .including, "ecl"))]
            let result = try await CardSearchService().search(filters: filters, config: .defaultConfig)
            let searchResults = SearchResults(
                totalCount: result.totalCount,
                cards: result.cards,
                warnings: result.warnings,
                nextPageUrl: result.nextPageURL
            )
            featuredState.results = .loaded(searchResults, nil)
        } catch {
            print("Failed to load featured cards: \(error)")
            featuredState.results = .errored(nil, SearchErrorState(from: error))
        }
    }
}
// MARK: - Featured Cards State

@MainActor
@Observable
class FeaturedCardsState: SearchResultsState {
    static let shared = FeaturedCardsState()
    
    override private init(results: LoadableResult<SearchResults, SearchErrorState> = .unloaded) {
        super.init(results: results)
    }
}
// MARK: - Example Search

struct ExampleSearch {
    let title: String
    let filters: [SearchFilter]
    
    static let examples: [ExampleSearch] = [
        ExampleSearch(title: "All Modern-Legal U/R Pingers", filters: [
            .basic(.keyValue("color", .lessThanOrEqual, "ur")),
            .basic(.keyValue("function", .including, "pinger")),
            .basic(.keyValue("format", .including, "modern")),
        ]),
        ExampleSearch(title: "Most Expensive 1-Drops in Standard", filters: [
            .basic(.keyValue("manavalue", .equal, "1")),
            .basic(.keyValue("format", .including, "standard")),
            .basic(.keyValue("order", .including, "usd")),
            .basic(.keyValue("dir", .including, "desc")),
        ]),
        ExampleSearch(title: "Best Orzhov Commanders", filters: [
            .basic(.keyValue("id", .equal, "orzhov")),
            .basic(.keyValue("type", .including, "legendary")),
            .basic(.keyValue("type", .including, "creature")),
            .basic(.keyValue("format", .including, "commander")),
            .basic(.keyValue("order", .including, "edhrec")),
            .basic(.keyValue("dir", .including, "desc")),
        ]),
    ]
}
