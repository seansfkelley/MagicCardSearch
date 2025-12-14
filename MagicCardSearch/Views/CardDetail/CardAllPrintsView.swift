//
//  CardPrintsListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//
import ScryfallKit
import SwiftUI

struct CardAllPrintsView: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var prints: [Card] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let cardSearchService = CardSearchService()

    private var scryfallSearchURL: URL? {
        let baseURL = "https://scryfall.com/search"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: "oracleid:\(oracleId)"),
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
                .navigationTitle(currentCard?.name ?? "All Prints")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    
                    if let card = currentCard {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                let listItem = CardListItem(from: card)
                                CardListManager.shared.toggleCard(listItem)
                            } label: {
                                Image(
                                    systemName: CardListManager.shared.contains(cardId: card.id)
                                        ? "bookmark.fill" : "bookmark"
                                )
                            }
                        }
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
    }
    
    @ViewBuilder private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = error {
            errorView(error: error)
        } else if prints.isEmpty {
            emptyView
        } else {
            CardPrintsDetailView(
                cards: prints,
                currentIndex: $currentIndex
            )
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

    private func loadPrints() async {
        isLoading = true
        error = nil

        do {
            prints = try await cardSearchService.searchCardsByOracleId(oracleId)
            if let index = prints.firstIndex(where: { $0.id == currentCardId }) {
                currentIndex = index
            }
            print("Loaded \(prints.count) prints for oracle ID: \(oracleId)")
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
    
    @State private var mainScrollPosition: Int?
    @State private var thumbnailScrollPosition: Int?
    @State private var partialScrollOffsetFraction: CGFloat = 0
    
    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < cards.count else {
            return nil
        }
        return cards[currentIndex]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            VStack(spacing: 0) {
                                if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                                    FlippableCardFaceView(
                                        frontFace: faces[0],
                                        backFace: faces[1],
                                        imageQuality: .large,
                                        aspectFit: true
                                    )
                                    .padding(.horizontal)
                                } else {
                                    CardFaceView(
                                        face: card,
                                        imageQuality: .large,
                                        aspectFit: true
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .padding(.horizontal)
                                }
                                
                                CardSetInfoSection(
                                    setCode: card.set,
                                    setName: card.setName,
                                    collectorNumber: card.collectorNumber,
                                    rarity: card.rarity,
                                    lang: card.lang
                                )
                                .padding(.horizontal)
                                .padding(.vertical)
                            }
                            .frame(width: geometry.size.width)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $mainScrollPosition, anchor: .center)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        (CGFloat(mainScrollPosition ?? 0) * geometry.containerSize.width - geometry.contentOffset.x) / geometry.containerSize.width
                    },
                    action: { _, new in
                        print(new)
                        partialScrollOffsetFraction = new
                    })
                .onChange(of: mainScrollPosition) { _, newValue in
                    if let newValue, newValue != currentIndex {
                        currentIndex = newValue
                        thumbnailScrollPosition = newValue
                    }
                }
                
                ThumbnailPreviewStrip(
                    cards: cards,
                    currentIndex: $currentIndex,
                    mainScrollPosition: $mainScrollPosition,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width
                )
            }
        }
        .onAppear {
            mainScrollPosition = currentIndex
            thumbnailScrollPosition = currentIndex
        }
    }
}

// MARK: - Thumbnail Preview Strip

private struct ThumbnailPreviewStrip: View {
    let cards: [Card]
    @Binding var currentIndex: Int
    @Binding var mainScrollPosition: Int?
    @Binding var scrollPosition: Int?
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
                
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    ThumbnailCardView(card: card, isSelected: index == currentIndex)
                        .frame(height: thumbnailHeight)
                        .id(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollPosition = index
                                mainScrollPosition = index
                                currentIndex = index
                            }
                        }
                }
                
                Color.clear
                    .frame(width: sidePadding - thumbnailSpacing)
            }
            // FIXME: Should be able to show the thumbnail bar scrolling as the main view is being
            // pushed around.
//            .offset(x: partialScrollOffsetFraction * thumbnailWidth, y: 0)
            .scrollTargetLayout()
            .padding(.vertical, 12)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // FIXME: This really feels like this should be .viewAligned(anchor: .center) but that
        // creates wonky behavior. .viewAligned's default anchor of .leading does, indeed, snap to
        // the leading edge, so I'm not sure why .center would not work.
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: thumbnailHeight + 16)
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue, newValue != currentIndex {
                currentIndex = newValue
                mainScrollPosition = newValue
            }
        }
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
                AsyncImage(url: URL(string: imageUri)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.clear
                        .aspectRatio(0.716, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                }
            } else if let imageUri = card.imageUris?.small {
                AsyncImage(url: URL(string: imageUri)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.clear
                        .aspectRatio(0.716, contentMode: .fit)
                        .overlay {
                            ProgressView()
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
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
