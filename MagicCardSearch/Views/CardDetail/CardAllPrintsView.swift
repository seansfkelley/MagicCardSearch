//
//  CardPrintsListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//
import ScryfallKit
import SwiftUI
import NukeUI

struct CardAllPrintsView: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var prints: [Card] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var currentIndex: Int = 0
    @State private var showFilterPopover = false
    @State private var printFilterSettings = PrintFilterSettings()
    @Environment(\.dismiss) private var dismiss

    private let cardSearchService = CardSearchService()
    
    // MARK: - Filter Settings
    
    private var scryfallSearchURL: URL? {
        let baseURL = "https://scryfall.com/search"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: printFilterSettings.toQueryFor(oracleId: oracleId)),
            URLQueryItem(name: "order", value: "released"),
            URLQueryItem(name: "dir", value: "asc"),
        ]
        return components?.url
    }
    
    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < prints.count else {
            return nil
        }
        return prints[currentIndex]
    }

    var body: some View {
        NavigationStack {
            contentView
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
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if let card = currentCard {
                                let listItem = CardListItem(from: card)
                                CardListManager.shared.toggleCard(listItem)
                            }
                        } label: {
                            Image(
                                systemName: currentCard.flatMap { CardListManager.shared.contains(cardId: $0.id) } ?? false
                                    ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .disabled(currentCard == nil)
                    }

                    if let url = scryfallSearchURL {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
                }
        }
        .task {
            await loadPrints()
        }
        .onChange(of: printFilterSettings) {
            Task {
                await loadPrints()
            }
        }
    }
    
    @ViewBuilder private var contentView: some View {
        // Wrap everything in an unconditional VStack so that this view doesn't leave the hierarchy
        // and navigation items and such, namely the filter popover, don't get disappeared.
        VStack {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error: error)
            } else if prints.isEmpty {
                if printFilterSettings.isDefault {
                    emptyView
                } else {
                    filteredEmptyView
                }
            } else {
                CardPrintsDetailView(
                    cards: prints,
                    currentIndex: $currentIndex
                )
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading prints...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Failed to load prints")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                Task {
                    await loadPrints()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Prints Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This card doesn't have any printings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredEmptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 8) {
                Text("No Matching Prints")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Widen your filters to see more results.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Button {
                printFilterSettings.reset()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All Filters")
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPrints() async {
        isLoading = true
        error = nil

        do {
            let searchQuery = printFilterSettings.toQueryFor(oracleId: oracleId)
            
            // Use the raw query search method
            prints = try await cardSearchService.searchByRawQuery(searchQuery)
            
            // Try to maintain the current card if it still exists in the filtered results
            if let index = prints.firstIndex(where: { $0.id == currentCardId }) {
                currentIndex = index
            } else if !prints.isEmpty {
                // If the current card is filtered out, reset to the first card
                currentIndex = 0
            }
            
            print("Loaded \(prints.count) prints for query: \(searchQuery)")
        } catch {
            print("Error loading prints: \(error)")
            self.error = error
        }

        isLoading = false
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
                    screenWidth: geometry.size.width
                )
                
                ThumbnailPreviewStrip(
                    cards: cards,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width
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
        .onChange(of: mainScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated because the calculated partial scroll offset thing makes sure
                // that the thumbnails are moving proportionally to the main view.
                thumbnailScrollPosition.scrollTo(id: newCardId)
            }
        }
        .onChange(of: thumbnailScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated to prevent excessive motion and potential image loads.
                mainScrollPosition.scrollTo(id: newCardId)
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
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards, id: \.id) { card in
                    VStack(spacing: 0) {
                        if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                            FlippableCardFaceView(
                                frontFace: faces[0],
                                backFace: faces[1],
                                imageQuality: .large,
                                isShowingBackFace: Binding(
                                    get: { cardFlipStates[card.id] ?? false },
                                    set: { cardFlipStates[card.id] = $0 }
                                )
                            )
                            .padding(.horizontal)
                        } else {
                            CardFaceView(
                                face: card,
                                imageQuality: .large,
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                        
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
                // Calculate offset based on current card's position in the array
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
    @Binding var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    
    private let thumbnailHeight: CGFloat = 100
    private let thumbnailSpacing: CGFloat = 8
    
    private var thumbnailWidth: CGFloat {
        // Standard Magic card aspect ratio
        thumbnailHeight * 0.716
    }
    
    private var sidePadding: CGFloat {
        (screenWidth - thumbnailWidth) / 2
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: thumbnailSpacing) {
                Color.clear
                    .frame(width: sidePadding - thumbnailSpacing)
                
                ForEach(cards, id: \.id) { card in
                    ThumbnailCardView(card: card, isSelected: card.id == scrollPosition.viewID(type: UUID.self))
                        .frame(height: thumbnailHeight)
                        .id(card.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollPosition.scrollTo(id: card.id)
                            }
                        }
                        // TODO: This works great, except that it reveals that the LazyHStack hasn't
                        // loaded things off screen yet. How to make it load just one more view on
                        // each side?
                        .offset(x: partialScrollOffsetFraction * (thumbnailWidth + thumbnailSpacing))
                }
                
                Color.clear
                    .frame(width: sidePadding - thumbnailSpacing)
            }
            .scrollTargetLayout()
            .padding(.vertical, 12)
        }
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: thumbnailHeight + 16)
    }
}

// MARK: - Thumbnail Card View

private struct ThumbnailCardView: View {
    let card: Card
    let isSelected: Bool
    
    var body: some View {
        Group {
            if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2,
               let imageUri = faces[0].imageUris?.small {
                LazyImage(url: URL(string: imageUri)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.clear
                            .aspectRatio(0.716, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
            } else if let imageUri = card.imageUris?.small {
                LazyImage(url: URL(string: imageUri)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.clear
                            .aspectRatio(0.716, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
            } else {
                Color.clear
                    .aspectRatio(0.716, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .scaleEffect(isSelected ? 1.1 : 1.0)
        // TODO: Enable this but only for the scale effect -- as written, it animates the offset
        // which causes whacko UI jitters.
//        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
