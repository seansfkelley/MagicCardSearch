//
//  SearchResultsGridView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI
import ScryfallKit

struct SearchResultsGridView: View {
    @Binding var results: LoadableResult<SearchResults, SearchErrorState>
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            if case .unloaded = results {
                ContentUnavailableView(
                    "Start Your Search",
                    systemImage: "text.magnifyingglass",
                    description: Text("Tap the search bar below and start typing to add filters")
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
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting your search filters")
                )
            } else if let searchResults = results.latestValue, !searchResults.cards.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        Text("\(searchResults.totalCount) \(searchResults.totalCount == 1 ? "result" : "results")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(searchResults.cards.enumerated()), id: \.element.id) { index, card in
                                CardResultCell(
                                    card: card,
                                    isFlipped: Binding(
                                        get: { cardFlipStates[card.id] ?? false },
                                        set: { cardFlipStates[card.id] = $0 }
                                    )
                                )
                                .onTapGesture {
                                    selectedCardIndex = index
                                }
                                .onAppear {
                                    if index == searchResults.cards.count - 4 {
                                        loadNextPageIfNeeded()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        if searchResults.nextPageUrl != nil || results.isLoadingNextPage || results.nextPageError != nil {
                            paginationStatusView
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                        }
                    }
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
                get: { selectedCardIndex.map { SheetIdentifier(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                cards: results.latestValue?.cards ?? [],
                initialIndex: identifier.index,
                totalCount: results.latestValue?.totalCount ?? 0,
                hasMorePages: results.latestValue?.nextPageUrl != nil,
                isLoadingNextPage: results.isLoadingNextPage,
                nextPageError: results.nextPageError,
                cardFlipStates: $cardFlipStates,
                onNearEnd: {
                    loadNextPageIfNeeded()
                },
                onRetryNextPage: {
                    retryNextPage()
                }
            )
        }
    }

    private func loadNextPageIfNeeded() {
        guard case .loaded(let searchResults, _) = results,
              let nextUrl = searchResults.nextPageUrl else {
            return
        }

        print("Loading next page \(nextUrl)")

        results = .loading(searchResults, nil)

        Task {
            do {
                let searchResult = try await service.fetchNextPage(from: nextUrl)
                let updatedResults = SearchResults(
                    totalCount: searchResults.totalCount,
                    cards: searchResults.cards + searchResult.cards,
                    warnings: searchResults.warnings,
                    nextPageUrl: searchResult.nextPageURL,
                )
                results = .loaded(updatedResults, nil)
            } catch {
                print("Error loading next page: \(error)")
                results = .errored(searchResults, SearchErrorState(from: error))
            }
        }
    }

    private func retryNextPage() {
        // Clear the error and retry
        if case .errored(let value, _) = results, let searchResults = value {
            results = .loaded(searchResults, nil)
            loadNextPageIfNeeded()
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
                        retryNextPage()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }
}

// MARK: - Sheet Identifier

private struct SheetIdentifier: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Card Result Cell

struct CardResultCell: View {
    let card: Card
    @Binding var isFlipped: Bool

    var body: some View {
        Group {
            if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                FlippableCardFaceView(
                    frontFace: faces[0],
                    backFace: faces[1],
                    imageQuality: .small,
                    isShowingBackFace: $isFlipped
                )
            } else {
                CardFaceView(
                    face: card,
                    imageQuality: .small
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var results: LoadableResult<SearchResults, SearchErrorState> = .unloaded

        var body: some View {
            SearchResultsGridView(
                results: $results
            )
        }
    }

    return PreviewWrapper()
}
