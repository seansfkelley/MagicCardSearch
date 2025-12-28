//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import ScryfallKit
import SwiftUI

struct CardDetailView: View {
    let card: Card
    @Binding var isFlipped: Bool

    @State private var relatedCardToShow: Card?
    @State private var isLoadingRelatedCard = false
    @State private var rulings: [Card.Ruling] = []
    @State private var isLoadingRulings = false
    @State private var rulingsError: Error?
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    private let cardSearchService = CardSearchService()
    private let rulingsService = RulingsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CardView(
                    card: card,
                    quality: .large,
                    isFlipped: $isFlipped,
                    cornerRadius: 16,
                )
                .padding(.horizontal)
                .padding(.bottom, 24)
                
                if let faces = card.cardFaces {
                    // Some double-faced cards are just alternate arts on both sides!i
                    let uniqueFaces = faces.uniqued(by: \.name)
                    let allArtists = faces.compactMap(\.artist)
                        .filter { !$0.isEmpty }
                        .uniqued()
                    
                    ForEach(Array(uniqueFaces.enumerated()), id: \.element.name) { index, face in
                        cardFaceDetailsView(face: face, showArtist: false)
                        
                        if index < uniqueFaces.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                    
                    if !allArtists.isEmpty {
                        Divider().padding(.horizontal)
                        CardArtistSection(artist: allArtists.joined(separator: ", "))
                    }
                } else {
                    cardFaceDetailsView(face: card)
                }
                
                if card.setType != .token {
                    Divider().padding(.horizontal)
                    CardLegalitiesSection(card: card)
                }

                Divider().padding(.horizontal)
                CardSetInfoSection(
                    setCode: card.set,
                    setName: card.setName,
                    collectorNumber: card.collectorNumber,
                    rarity: card.rarity,
                    lang: card.lang,
                    releasedAtAsDate: card.releasedAtAsDate,
                )

                if let oracleId = card.bestEffortOracleId {
                    Divider().padding(.horizontal)
                    CardAllPrintsSection(
                        oracleId: oracleId,
                        currentCardId: card.id
                    )
                }
                
                if CardPricesSection.hasPrices(card: card) {
                    Divider().padding(.horizontal)
                    CardPricesSection(prices: card.prices, purchaseUris: card.purchaseUris)
                }

                if let allParts = card.allParts, !allParts.isEmpty {
                    // Use name, because Scryfall does not report oracle ID, which we would prefer
                    // to use to remove references to myself.
                    let otherParts = allParts.filter { $0.name != card.name }
                    if !otherParts.isEmpty {
                        Divider().padding(.horizontal)

                        CardRelatedPartsSection(
                            otherParts: otherParts,
                            isLoadingRelatedCard: isLoadingRelatedCard
                        ) { partId in
                            Task {
                                await loadRelatedCard(id: partId)
                            }
                        }
                    }
                }

                if isLoadingRulings || rulingsError != nil || !rulings.isEmpty {
                    Divider().padding(.horizontal)

                    CardRulingsSection(
                        rulings: rulings,
                        isLoading: isLoadingRulings,
                        error: rulingsError
                    ) {
                        Task {
                            await loadRulings(from: card.rulingsUri)
                        }
                    }
                }

                Divider().padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .padding(.top)
        }
        .task {
            await loadRulings(from: card.rulingsUri)
        }
        .sheet(item: $relatedCardToShow) { relatedCard in
            NavigationStack {
                CardDetailView(card: relatedCard, isFlipped: $isFlipped)
                    .navigationTitle(relatedCard.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                relatedCardToShow = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Card Face Details View
    
    // swiftlint:disable function_body_length cyclomatic_complexity
    @ViewBuilder
    private func cardFaceDetailsView(face: CardFaceDisplayable, showArtist: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(face.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !face.displayableManaCost.isEmpty {
                    ManaCostView(face.displayableManaCost, size: 20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

        // The "Card" typeline happens on art cards.
        if let typeLine = face.typeLine, !typeLine.isEmpty && typeLine != "Card" {
            Divider().padding(.horizontal)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let colorIndicator = face.colorIndicator, !colorIndicator.isEmpty {
                        ColorIndicatorView(colors: colorIndicator, size: 20)
                    }

                    Text(typeLine)
                        .font(.body)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        let oracleText = face.oracleText ?? ""
        let flavorText = face.flavorText ?? ""
        
        if !oracleText.isEmpty || !flavorText.isEmpty {
            Divider().padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                if !oracleText.isEmpty {
                    OracleTextView(oracleText)
                }

                if !flavorText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(flavorText.components(separatedBy: "\n"), id: \.self) { line in
                            if !line.isEmpty {
                                Text(line)
                                    .font(.system(.body, design: .serif))
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let power = face.power, let toughness = face.toughness, !power.isEmpty || !toughness.isEmpty {
            Divider().padding(.horizontal)
            CardStatSection(value: "\(power)/\(toughness)")
        }
        
        if let loyalty = face.loyalty, !loyalty.isEmpty {
            Divider().padding(.horizontal)
            CardStatSection(value: loyalty, label: "Loyalty")
        }
        
        if let defense = face.defense, !defense.isEmpty {
            Divider().padding(.horizontal)
            CardStatSection(value: defense, label: "Defense")
        }

        if showArtist, let artist = face.artist, !artist.isEmpty {
            Divider().padding(.horizontal)
            CardArtistSection(artist: artist)
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    private func loadRelatedCard(id: UUID) async {
        print("Loading related card...")

        isLoadingRelatedCard = true
        defer { isLoadingRelatedCard = false }

        do {
            let card = try await cardSearchService.fetchCard(byId: id)
            relatedCardToShow = card
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            print("Error loading related card: \(error)")
        }
    }

    private func loadRulings(from urlString: String) async {
        isLoadingRulings = true
        rulingsError = nil
        defer { isLoadingRulings = false }

        do {
            rulings = try await rulingsService.fetchRulings(
                from: urlString,
                oracleId: card.oracleId
            )
        } catch {
            rulingsError = error
            print("Error loading rulings: \(error)")
        }
    }
}
