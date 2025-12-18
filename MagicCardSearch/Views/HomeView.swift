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
    
    private static var featuredCardsCache: LoadableResult<SearchResults, SearchErrorState> = .unloaded
    
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
                            switch Self.featuredCardsCache {
                            case .loading(nil, _), .unloaded:
                                ForEach(0..<15, id: \.self) { _ in
                                    ProgressView()
                                        .frame(width: 120, height: 168)
                                }
                            case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                                ForEach(results.cards.prefix(15), id: \.id) { card in
                                    CardResultCell(
                                        card: card,
                                        isFlipped: Binding(
                                            get: { cardFlipStates[card.id] ?? false },
                                            set: { cardFlipStates[card.id] = $0 }
                                        )
                                    )
                                    .frame(width: 120)
                                }
                                
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " "))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        
                                        Text(RelativeDateTimeFormatter().localizedString(for: entry.lastUsedDate, relativeTo: Date()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        searchHistoryTracker.delete(filters: entry.filters)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(min(10, searchHistoryTracker.completeSearchEntries.count)) * 70)
                        .scrollDisabled(true)
                    }
                }
            }
            .padding(.vertical)
        }
        .task {
            await loadFeaturedCards()
        }
    }
    
    private func loadFeaturedCards() async {
        guard case .unloaded = Self.featuredCardsCache else {
            return
        }
        
        Self.featuredCardsCache = .loading(nil, nil)
        
        do {
            let filters: [SearchFilter] = [.basic(.keyValue("set", .including, "ecl"))]
            let result = try await CardSearchService().search(filters: filters, config: .defaultConfig)
            let searchResults = SearchResults(
                totalCount: result.totalCount,
                cards: result.cards,
                warnings: result.warnings,
                nextPageUrl: result.nextPageURL
            )
            Self.featuredCardsCache = .loaded(searchResults, nil)
        } catch {
            print("Failed to load featured cards: \(error)")
            Self.featuredCardsCache = .errored(nil, SearchErrorState(from: error))
        }
    }
}
