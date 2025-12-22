//
//  SearchResultsGridView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI
import ScryfallKit

struct SearchResultsGridView: View {
    let state: ScryfallSearchResultsList
    
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    
    private let spacing: CGFloat = 4
    
    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]
    
    private var results: LoadableResult<SearchResults, SearchErrorState> {
        state.current
    }

    var body: some View {
        ZStack {
            // TODO: Clean this up.
            if case .unloaded = results {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "circle.slash",
                )
            } else if case .errored(let searchResults, let error) = results, searchResults?.cards.isEmpty ?? true {
                ContentUnavailableView {
                    Label(error.title, systemImage: error.iconName)
                } description: {
                    Text(error.description)
                }
            } else if case .errored(nil, let error) = results {
                ContentUnavailableView {
                    Label(error.title, systemImage: error.iconName)
                } description: {
                    Text(error.description)
                }
            } else if case .loaded(let searchResults, _) = results, searchResults.cards.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "circle.slash",
                )
            } else if let searchResults = results.latestValue, !searchResults.cards.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        Text("\(searchResults.totalCount) \(searchResults.totalCount == 1 ? "result" : "results")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)

                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(Array(searchResults.cards.enumerated()), id: \.element.id) { index, card in
                                CardView(
                                    card: card,
                                    quality: .normal,
                                    isFlipped: Binding(
                                        get: { cardFlipStates[card.id] ?? false },
                                        set: { cardFlipStates[card.id] = $0 }
                                    ),
                                    cornerRadius: 8,
                                )
                                .onTapGesture {
                                    selectedCardIndex = index
                                }
                                .onAppear {
                                    if index == searchResults.cards.count - 4 {
                                        state.loadNextPageIfNeeded()
                                    }
                                }
                                .padding(.horizontal, spacing / 2)
                            }
                        }

                        if searchResults.nextPageUrl != nil || results.isLoadingNextPage || results.nextPageError != nil {
                            paginationStatusView
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.horizontal, spacing / 2)
                }
            }

            if results.isInitiallyLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: results.isInitiallyLoading)
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                state: state,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates
            )
        }
    }

    @ViewBuilder private var paginationStatusView: some View {
        VStack(spacing: 16) {
            if results.isLoadingNextPage {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading more results...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let error = results.nextPageError {
                VStack(spacing: 16) {
                    Image(systemName: error.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Text(error.title)
                            .font(.headline)
                        Text(error.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Retry") {
                        state.retryNextPage()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        let state = ScryfallSearchResultsList()

        var body: some View {
            SearchResultsGridView(state: state)
        }
    }

    return PreviewWrapper()
}
