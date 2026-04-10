import OSLog
import ScryfallKit
import SwiftUI

private let logger = Logger(subsystem: "MagicCardSearch", category: "CardDetailView")

protocol CardDetailDisplayable {
    var name: String { get }
    var flavorName: String? { get }
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
    struct Placeholder: View {
        let name: String?
        let cornerRadius: CGFloat
        let decoration: CardView.Placeholder.Decoration

        init(name: String?, cornerRadius: CGFloat, with decoration: CardView.Placeholder.Decoration = .none) {
            self.name = name
            self.cornerRadius = cornerRadius
            self.decoration = decoration
        }

        var body: some View {
            VStack(spacing: 0) {
                CardView.Placeholder(name: name, cornerRadius: cornerRadius, with: decoration)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top)
        }
    }

    let card: Card
    @Binding var isShowingBackFace: Bool
    var searchState: Binding<SearchState>?
    let fetchCardService: FetchCardService

    @State private var relatedCardToShow: Card?
    @State private var isLoadingRelatedCard = false

    init(card: Card, isShowingBackFace: Binding<Bool>, searchState: Binding<SearchState>? = nil, fetchCardService: FetchCardService? = nil) {
        self.card = card
        self._isShowingBackFace = isShowingBackFace
        self.searchState = searchState
        self.fetchCardService = fetchCardService ?? CachingScryfallService.shared
    }

    var body: some View {
        ScrollView {
            // This is lazy ONLY because it prevents the rulings section from being loaded until it
            // is (near) visible, which seems like all upside and helps avoid getting rate-limited
            // by Scryfall.
            LazyVStack(spacing: 0) {
                CardView(
                    card: card,
                    quality: .large,
                    cornerRadius: 16,
                    isShowingBackFace: $isShowingBackFace,
                    enableTransforms: .all,
                    enableCopyActions: true,
                    enableZoomGestures: .tapAndPinch,
                )
                .padding(.horizontal)
                .padding(.bottom, 24)
                
                if let faces = card.cardFaces {
                    let allArtists = faces.compactMap(\.artist)
                        .filter { !$0.isEmpty }
                        .uniqued()

                    // Faces don't have a single field that is guaranteed to differentiate them from
                    // other faces. Particularly bad cases are those that are just alternate arts:
                    // https://api.scryfall.com/cards/4d227cd3-ebfe-4dd3-929a-4f8ff7c8981e
                    //
                    // Hence why we use the index. We don't attempt to unique the text box to only
                    // show one in this case, since they often (always?) have at least different
                    // flavor text, so the text box is actually different.
                    ForEach(Array(faces.enumerated()), id: \.offset) { index, face in
                        cardFaceDetailsView(face: face)
                        
                        if index < faces.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                    
                    if !allArtists.isEmpty {
                        Divider().padding(.horizontal)
                        ArtistCardSection(artist: allArtists.joined(separator: ", "))
                    }
                } else {
                    cardFaceDetailsView(face: card)

                    if let artist = card.artist, !artist.isEmpty {
                        Divider().padding(.horizontal)
                        ArtistCardSection(artist: artist)
                    }
                }

                Divider().padding(.horizontal)
                SetMetadataCardSection(
                    setCode: card.set,
                    setName: card.setName,
                    collectorNumber: card.collectorNumber,
                    rarity: card.rarity,
                    lang: card.lang,
                    releasedAtAsDate: card.releasedAtAsDate,
                )

                if card.setType != .token {
                    Divider().padding(.horizontal)
                    LegalitiesCardSection(card: card)
                }

                if let oracleId = card.bestEffortOracleId {
                    Divider().padding(.horizontal)
                    AllPrintsCardSection(
                        oracleId: oracleId,
                        currentCardId: card.id
                    )
                }

                Divider().padding(.horizontal)
                ScryfallTagsCardSection(
                    setCode: card.set,
                    collectorNumber: card.collectorNumber,
                    searchState: searchState,
                )

                if let allParts = card.allParts {
                    // Scryfall only provides `id` and `name`. `id` is the Scryfall ID which is way
                    // more specific than the oracle ID, which would be our preferred deduplication,
                    // that is, each printing (?) gets its own Scryfall ID.
                    let otherParts = allParts.filter { $0.name != card.name }
                    if !otherParts.isEmpty {
                        Divider().padding(.horizontal)

                        RelatedPartsCardSection(
                            otherParts: otherParts.sorted { $0.name < $1.name },
                            isLoadingRelatedCard: isLoadingRelatedCard
                        ) { partId in
                            Task {
                                await loadRelatedCard(id: partId)
                            }
                        }
                    }
                }

                PricesCardSection(prices: card.prices, purchaseUris: card.purchaseUris) {
                    Divider().padding(.horizontal)
                }

                RulingsCardSection(scryfallId: card.id) {
                    Divider().padding(.horizontal)
                }
            }
            .background(Color(.systemBackground))
            .padding(.top)
        }
        .sheet(item: $relatedCardToShow) { relatedCard in
            NavigationStack {
                CardDetailView(
                    card: relatedCard,
                    isShowingBackFace: $isShowingBackFace,
                    searchState: searchState,
                )
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
    private func cardFaceDetailsView(face: CardDetailDisplayable) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(face.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if !face.displayableManaCost.isEmpty {
                    ManaCostView(face.displayableManaCost, size: 20)
                }
            }

            if let flavorName = face.flavorName {
                Text(flavorName)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .italic()
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
                        .textSelection(.enabled)
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
                    SymbolizedTextView(oracleText)
                }

                if !flavorText.isEmpty {
                    FlavorTextView(flavorText)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }

        if let power = face.power, let toughness = face.toughness, !power.isEmpty || !toughness.isEmpty {
            Divider().padding(.horizontal)
            StatLineCardSection(value: "\(power.asVulgarFraction)/\(toughness.asVulgarFraction)")
                .textSelection(.enabled)
        }
        
        if let loyalty = face.loyalty, !loyalty.isEmpty {
            Divider().padding(.horizontal)
            StatLineCardSection(value: loyalty, label: "Loyalty")
                .textSelection(.enabled)
        }
        
        if let defense = face.defense, !defense.isEmpty {
            Divider().padding(.horizontal)
            StatLineCardSection(value: defense, label: "Defense")
                .textSelection(.enabled)
        }
    }

    private func loadRelatedCard(id: UUID) async {
        print("Loading related card...")

        isLoadingRelatedCard = true
        defer { isLoadingRelatedCard = false }

        do {
            let card = try await fetchCardService.fetchCard(byScryfallId: id)
            relatedCardToShow = card
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            print("Error loading related card: \(error)")
        }
    }
}

#Preview("Lightning Bolt") {
    @Previewable @State var card: Card?
    @Previewable @State var isShowingBackFace = false
    let id = UUID(uuidString: "f29ba16f-c8fb-42fe-aabf-87089cb214a7")!

    if let card {
        NavigationStack {
            CardDetailView(card: card, isShowingBackFace: $isShowingBackFace)
                .navigationTitle(card.name)
                .navigationBarTitleDisplayMode(.inline)
        }
        .environment(ScryfallCatalogs())
    } else {
        ProgressView()
            .task {
                card = try? await CachingScryfallService.shared.fetchCard(byScryfallId: id)
            }
    }
}

#Preview("Placeholder") {
    CardDetailView.Placeholder(name: "Lightning Bolt", cornerRadius: 16, with: .spinner)
}
