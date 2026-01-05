import Logging
import ScryfallKit
import SwiftUI

private let logger = Logger(label: "CardDetailView")

protocol CardDetailDisplayable {
    var name: String { get }
    var typeLine: String? { get }
    var oracleText: String? { get }
    var flavorText: String? { get }
    var colorIndicator: [Card.Color]? { get }
    var power: String? { get }
    var toughness: String? { get }
    var loyalty: String? { get }
    var defense: String? { get }
    var artist: String? { get }
    var imageUris: Card.ImageUris? { get }

    // Properties that have differing types in ScryfallKit so need another name.
    var displayableManaCost: String { get }
}

// MARK: - Card.Face Conformance

extension Card.Face: CardDetailDisplayable {
    var displayableManaCost: String {
        return manaCost
    }
}

// MARK: - Card Conformance

extension Card: CardDetailDisplayable {
    var displayableManaCost: String {
        return manaCost ?? ""
    }
}

struct CardDetailView: View {
    let card: Card
    @Binding var isFlipped: Bool

    @State private var relatedCardToShow: Card?
    @State private var isLoadingRelatedCard = false
    @State private var rulingsResult: LoadableResult<[Card.Ruling], Error> = .unloaded
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
                    // Some double-faced cards are just alternate arts on both sides!
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

                Divider().padding(.horizontal)
                CardTagsSection(setCode: card.set, collectorNumber: card.collectorNumber)

                if let allParts = card.allParts {
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

                if CardPricesSection.hasPrices(card: card) {
                    Divider().padding(.horizontal)
                    CardPricesSection(prices: card.prices, purchaseUris: card.purchaseUris)
                }

                if case .unloaded = rulingsResult {
                    // nop
                } else if case .loading(let value, _) = rulingsResult, value?.isEmpty ?? true {
                    // HACK: We use the empty array in a loading state to indicate that this is a
                    // retry, which we DO want to render the view for.
                } else if case .loaded(let value, _) = rulingsResult, value.isEmpty {
                    // nop
                } else {
                    Divider().padding(.horizontal)

                    CardRulingsSection(rulings: rulingsResult) {
                        Task {
                            await loadRulings(from: card.rulingsUri, isRetry: true)
                        }
                    }
                }
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
    
    @ViewBuilder
    private func cardFaceDetailsView(face: CardDetailDisplayable, showArtist: Bool = true) -> some View {
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
                    FlavorTextView(flavorText)
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

    private func loadRelatedCard(id: UUID) async {
        print("Loading related card...")

        isLoadingRelatedCard = true
        defer { isLoadingRelatedCard = false }

        do {
            let card = try await cardSearchService.fetchCard(byScryfallId: id)
            relatedCardToShow = card
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            print("Error loading related card: \(error)")
        }
    }

    private func loadRulings(from urlString: String, isRetry: Bool = false) async {
        rulingsResult = isRetry ? .loading([], nil) : .loading(nil, nil)

        do {
            let fetchedRulings = try await rulingsService.fetchRulings(
                from: urlString,
                oracleId: card.oracleId
            )
            rulingsResult = rulingsResult.asLoaded(fetchedRulings)
        } catch {
            rulingsResult = rulingsResult.asErrored(error)
            logger.error("error loading rulings", metadata: [
                "cardId": "\(card.id)",
                "cardName": "\(card.name)",
                "error": "\(error)",
            ])
        }
    }
}
