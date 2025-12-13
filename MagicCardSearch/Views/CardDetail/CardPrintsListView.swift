//
//  CardPrintsListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//
import ScryfallKit
import SwiftUI

struct CardPrintsListView: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var prints: [Card] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedCardIndex: Int?
    @Environment(\.dismiss) private var dismiss

    private let cardSearchService = CardSearchService()
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

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

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All Prints")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
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
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { SheetIdentifier(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            MinimalCardDetailView(
                cards: prints,
                initialIndex: identifier.index
            )
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
            printsGridView
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
    
    private var printsGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(prints.enumerated()), id: \.element.id) { index, card in
                    CardPrintGridItem(
                        card: card,
                        isCurrentPrint: card.id == currentCardId
                    )
                    .onTapGesture {
                        selectedCardIndex = index
                    }
                }
            }
            .padding()
        }
    }

    private func loadPrints() async {
        isLoading = true
        error = nil

        do {
            prints = try await cardSearchService.searchCardsByOracleId(oracleId)
            print("Loaded \(prints.count) prints for oracle ID: \(oracleId)")
        } catch {
            print("Error loading prints: \(error)")
            self.error = error
        }

        isLoading = false
    }
}

private struct SheetIdentifier: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Card Print Grid Item

private struct CardPrintGridItem: View {
    let card: Card
    let isCurrentPrint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                FlippableCardFaceView(
                    frontFace: faces[0],
                    backFace: faces[1],
                    imageQuality: .normal,
                    aspectFit: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                CardFaceView(
                    face: card,
                    imageQuality: .normal,
                    aspectFit: true,
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    SetIconView(setCode: card.set, size: 14)

                    Text(card.set.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)

                    if let releasedAt = card.releasedAtAsDate {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(releasedAt, format: .dateTime.year().month().day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(card.setName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Minimal Card Detail View

private struct MinimalCardDetailView: View {
    let cards: [Card]
    let initialIndex: Int

    @State private var currentIndex: Int
    @State private var scrollPosition: Int?
    @ObservedObject private var listManager = CardListManager.shared
    @Environment(\.dismiss) private var dismiss

    init(cards: [Card], initialIndex: Int) {
        self.cards = cards
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
        self._scrollPosition = State(initialValue: initialIndex)
    }

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < cards.count else {
            return nil
        }
        return cards[currentIndex]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            ScrollView {
                                VStack(spacing: 0) {
                                    if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                                        FlippableCardFaceView(
                                            frontFace: faces[0],
                                            backFace: faces[1],
                                            imageQuality: .large,
                                            aspectFit: true
                                        )
                                        .padding(.horizontal)
                                        .padding(.top)
                                    } else {
                                        CardFaceView(
                                            face: card,
                                            imageQuality: .large,
                                            aspectFit: true,
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .padding(.horizontal)
                                        .padding(.top)
                                    }
                                    
                                    CardSetInfoSection(
                                        setCode: card.set,
                                        setName: card.setName,
                                        collectorNumber: card.collectorNumber,
                                        rarity: card.rarity,
                                        lang: card.lang
                                    )
                                    
                                    Spacer().frame(height: 40)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(currentCard?.name ?? "")
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
                            listManager.toggleCard(listItem)
                        } label: {
                            Image(
                                systemName: listManager.contains(cardId: card.id)
                                    ? "bookmark.fill" : "bookmark"
                            )
                        }
                    }

                    if let url = URL(string: card.scryfallUri) {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            scrollPosition = initialIndex
        }
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue {
                currentIndex = newValue
            }
        }
    }
}
