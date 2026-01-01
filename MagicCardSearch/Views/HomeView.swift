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
    let historyAndPinnedState: HistoryAndPinnedState
    let onSearchSelected: ([SearchFilter]) -> Void
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var selectedCardIndex: Int?
    
    private let featuredList = FeaturedCardsObjectList.shared
    private let featuredCardWidth: CGFloat = 120

    var body: some View {
        List {
            featuredCardsSection()
            recentSearchesSection()
            examplesSection()
        }
        .task {
            if isRunningTests() {
                logger.info("Skipping featured card load in test environment")
            } else {
                FeaturedCardsObjectList.shared.loadNextPage()
            }
        }
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                list: FeaturedCardsObjectList.shared,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates
            )
        }
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    private func featuredCardsSection() -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    switch FeaturedCardsObjectList.shared.value {
                    case .loading(nil, _), .unloaded:
                        ForEach(0..<15, id: \.self) { _ in
                            CardPlaceholderView(name: nil, cornerRadius: 8, withSpinner: true)
                                .frame(width: featuredCardWidth, height: featuredCardWidth / Card.aspectRatio)
                        }
                    case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                        ForEach(Array(results.data.enumerated()), id: \.element.id) { index, card in
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
                                .frame(width: featuredCardWidth)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if index == results.data.count - 3 {
                                    featuredList.loadNextPage()
                                }
                            }
                        }

                        if case .loading = featuredList.value, results.hasMore ?? false {
                            ProgressView()
                                .frame(width: featuredCardWidth, height: featuredCardWidth / Card.aspectRatio)
                        }
                    case .errored(nil, let error):
                        ContentUnavailableView(
                            "Unable to Load Spoilers",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error.description),
                        )
                        .frame(width: featuredCardWidth * 2, height: featuredCardWidth / Card.aspectRatio)
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
                        .basic(false, "date", .greaterThanOrEqual, "today"),
                        .basic(false, "order", .including, SortMode.spoiled.rawValue),
                        .basic(false, "dir", .including, SortDirection.desc.rawValue),
                        .basic(false, "unique", .including, UniqueMode.prints.rawValue),
                    ])
                }) {
                    Text("View All")
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(.horizontal, 0)
        .listSectionMargins(.horizontal, 0)
    }

    @ViewBuilder
    private func recentSearchesSection() -> some View {
        let recentSearches = historyAndPinnedState.getLatestSearches(count: 10)

        if !recentSearches.isEmpty {
            Section {
                ForEach(recentSearches, id: \.lastUsedAt) { entry in
                    Button {
                        onSearchSelected(entry.search)
                    } label: {
                        HStack {
                            Text(entry.search.map { $0.description }.joined(separator: " "))
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
                            historyAndPinnedState.delete(search: entry.search)
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
    }

    @ViewBuilder
    private func examplesSection() -> some View{
        Section {
            ForEach(ExampleSearch.dailyExamples, id: \.title) { example in
                Button {
                    onSearchSelected(example.filters)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(example.filters.map { $0.description }.joined(separator: " "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
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
}
// MARK: - Featured Cards State

@MainActor
@Observable
private class FeaturedCardsObjectList: ScryfallObjectList<Card> {
    private static let scryfall = ScryfallClient(networkLogLevel: .minimal)

    static let shared = FeaturedCardsObjectList { page async throws in
        return try await scryfall.searchCards(
            query: "date>=today",
            unique: .prints,
            order: .spoiled,
            sortDirection: .desc,
            page: page,
        )
    }
}
// MARK: - Example Search


