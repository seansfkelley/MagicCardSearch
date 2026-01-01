//
//  CardPrintsListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//
import ScryfallKit
import SwiftUI
import SwiftData
import NukeUI

struct CardAllPrintsView: View {
    let oracleId: String
    let initialCardId: UUID

    @State private var objectList: ScryfallObjectList<Card> = .empty()
    @State private var currentIndex: Int = 0
    @State private var showFilterPopover = false
    @State private var printFilterSettings = PrintFilterSettings()
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [BookmarkedCard]

    // MARK: - Filter Settings
    
    private var scryfallSearchUrl: URL? {
        let baseURL = "https://scryfall.com/search"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: printFilterSettings.toQueryFor(oracleId: oracleId)),
            URLQueryItem(name: "order", value: "released"),
            URLQueryItem(name: "dir", value: "asc"),
        ]
        return components?.url
    }
    
    private var currentPrints: [Card] {
        objectList.value.latestValue?.data ?? []
    }
    
    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < currentPrints.count else {
            return nil
        }
        return currentPrints[currentIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if case .unloaded = objectList.value {
                    EmptyView()
                } else if let objectListData = objectList.value.latestValue {
                    let cards = objectListData.data
                    if cards.isEmpty {
                        if printFilterSettings.isDefault {
                            ContentUnavailableView(
                                "No Prints Found",
                                systemImage: "rectangle.on.rectangle.slash",
                                description: Text("This card doesn't have any printings?")
                            )
                        } else {
                            ContentUnavailableView {
                                Label("No Matching Prints", systemImage: "sparkle.magnifyingglass")
                            } description: {
                                Text("Widen your filters to see more results.")
                            } actions: {
                                Button {
                                    printFilterSettings.reset()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset All Filters")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                        }
                    } else {
                        CardPrintsDetailView(
                            cards: cards,
                            currentIndex: $currentIndex
                        )
                    }
                } else if let error = objectList.value.latestError {
                    ContentUnavailableView {
                        Label("Failed to load prints", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await reloadAllPrints()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if case .loading = objectList.value {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                            Text("Loading prints...")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Color(white: 0, opacity: 0.4))
                    .allowsHitTesting(false)
                }
            }
            // TODO: Should there be a title? It looks naked up there but a title is pretty useless.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterPopover.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .badge(!printFilterSettings.isDefault ? " " : nil)
                    .badgeProminence(.decreased)
                    .popover(isPresented: $showFilterPopover) {
                        FilterPopoverView(filterSettings: $printFilterSettings)
                            .presentationCompactAdaptation(.popover)
                    }
                }
                
                if let currentCard, let bookmark = bookmarks.first(where: { $0.id == currentCard.id }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            modelContext.delete(bookmark)
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                    }
                } else if let currentCard {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            modelContext.insert(BookmarkedCard(from: currentCard))
                        } label: {
                            Image(systemName: "bookmark")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: {
                            Image(systemName: "bookmark")
                        }
                        .disabled(true)
                    }
                }

                if let url = scryfallSearchUrl {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url)
                    }
                }
            }
        }
        .task {
            await reloadAllPrints()
        }
        .onChange(of: printFilterSettings) {
            Task {
                await reloadAllPrints()
            }
        }
    }

    private func reloadAllPrints() async {
        let searchQuery = printFilterSettings.toQueryFor(oracleId: oracleId)
        let targetCardId = if case .unloaded = objectList.value {
            initialCardId
        } else {
            currentPrints[safe: currentIndex]?.id
        }

        let client = ScryfallClient(networkLogLevel: .minimal)
        objectList = ScryfallObjectList { page in
            try await client.searchCards(
                query: searchQuery,
                page: page,
            )
        }
        
        await objectList.loadAllRemainingPages().value
        
        if let targetCardId,
           let index = currentPrints.firstIndex(where: { $0.id == targetCardId }) {
            currentIndex = index
        } else if !currentPrints.isEmpty {
            currentIndex = 0
        }
    }
}

// MARK: - Card Prints Detail View

private struct CardPrintsDetailView: View {
    let cards: [Card]
    @Binding var currentIndex: Int
    
    // It seems that these cannot share a position object, so we bridge between the two and,
    // unfortunately, also the currentIndex binding from the parent.
    @State private var mainScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var thumbnailScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var partialScrollOffsetFraction: CGFloat = 0
    @State private var isFlipped: Bool = false

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                PagingCardImageView(
                    cards: cards,
                    scrollPosition: $mainScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: $isFlipped
                )
                
                ThumbnailPreviewStrip(
                    cards: cards,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: isFlipped
                )
                
                Spacer()
                
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let currentCard {
                mainScrollPosition.scrollTo(id: currentCard.id)
                thumbnailScrollPosition.scrollTo(id: currentCard.id)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            if let cardId = cards[safe: newIndex]?.id {
                if mainScrollPosition.viewID(type: UUID.self) != cardId {
                    mainScrollPosition.scrollTo(id: cardId)
                }
                if thumbnailScrollPosition.viewID(type: UUID.self) != cardId {
                    thumbnailScrollPosition.scrollTo(id: cardId)
                }
            }
        }
        .onChange(of: mainScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated because the calculated partial scroll offset thing makes sure
                // that the thumbnails are moving proportionally to the main view.
                if thumbnailScrollPosition.viewID(type: UUID.self) != newCardId {
                    thumbnailScrollPosition.scrollTo(id: newCardId)
                }
            }
        }
        .onChange(of: thumbnailScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated to prevent excessive motion and potential image loads.
                if mainScrollPosition.viewID(type: UUID.self) != newCardId {
                    mainScrollPosition.scrollTo(id: newCardId)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Paging Card Image View

private struct PagingCardImageView: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    @Binding var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    @Binding var isFlipped: Bool

    @State private var scrollPhase: ScrollPhase = .idle
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards, id: \.id) { card in
                    VStack(spacing: 0) {
                        CardView(
                            card: card,
                            quality: .large,
                            isFlipped: $isFlipped,
                            cornerRadius: 16,
                        )
                        .padding(.horizontal)
                        
                        CardSetInfoSection(
                            setCode: card.set,
                            setName: card.setName,
                            collectorNumber: card.collectorNumber,
                            rarity: card.rarity,
                            lang: card.lang,
                            releasedAtAsDate: card.releasedAtAsDate,
                        )
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                    .frame(width: screenWidth)
                    .id(card.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                guard let currentId = scrollPosition.viewID(type: UUID.self),
                      let currentIdx = cards.firstIndex(where: { $0.id == currentId }) else {
                    return 0
                }
                return (CGFloat(currentIdx) * geometry.containerSize.width - geometry.contentOffset.x) / geometry.containerSize.width
            },
            action: { _, new in
                partialScrollOffsetFraction = new
            })
    }
}

// MARK: - Thumbnail Preview Strip

private struct ThumbnailPreviewStrip: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    var isFlipped: Bool
    
    private let thumbnailHeight: CGFloat = 100
    private let thumbnailSpacing: CGFloat = 8
    
    private var thumbnailWidth: CGFloat {
        thumbnailHeight * Card.aspectRatio
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: thumbnailSpacing) {
                ForEach(cards, id: \.id) { card in
                    CardView(
                        card: card,
                        quality: .small,
                        isFlipped: .constant(isFlipped),
                        cornerRadius: 4,
                        showFlipButton: false
                    )
                    .scaleEffect(card.id == scrollPosition.viewID(type: UUID.self) ? 1.1 : 1.0)
                    // TODO: Enable this but only for the scale effect -- as written, it seems to animate the
                    // padding or otherwise cause whacko UI jitters.
                    // .animation(.easeInOut(duration: 0.2), value: isSelected)
                    //
                    // Setting width here is crucial for the initial positioning; before the
                    // images have loaded, the LazyHStack doesn't know where to scroll to in
                    // order to show the initially-selected card. This should also help with
                    // pop-in of images on slow connections.
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .id(card.id)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollPosition.scrollTo(id: card.id)
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.leading, partialScrollOffsetFraction * (thumbnailWidth + thumbnailSpacing))
            .padding(.vertical, 12)
        }
        .contentMargins(.horizontal, (screenWidth - thumbnailWidth) / 2, for: .scrollContent)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: thumbnailHeight + 16)
    }
}
