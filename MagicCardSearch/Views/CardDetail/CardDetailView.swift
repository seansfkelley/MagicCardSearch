//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

// swiftlint:disable file_length

import ScryfallKit
import SwiftUI

struct CardDetailView: View {
    let card: Card
    var isCurrentlyVisible: Bool = true

    @State private var relatedCardToShow: Card?
    @State private var isLoadingRelatedCard = false
    @State private var rulings: [Card.Ruling] = []
    @State private var isLoadingRulings = false
    @State private var rulingsError: Error?
    @ObservedObject private var listManager = CardListManager.shared
    private let cardSearchService = CardSearchService()
    private let rulingsService = RulingsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                    FlippableCardFaceView(
                        frontFace: faces[0],
                        backFace: faces[1],
                        imageQuality: .large,
                        aspectFit: true
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                } else {
                    CardFaceView(
                        face: card,
                        imageQuality: .large,
                        aspectFit: true,
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                
                if let faces = card.cardFaces {
                    let uniqueFaces = faces.uniqued(by: \.oracleId)
                    let allArtists = faces.compactMap(\.artist)
                        .filter { !$0.isEmpty }
                        .uniqued()
                    
                    ForEach(Array(uniqueFaces.enumerated()), id: \.element.name) { index, face in
                        cardFaceDetailsView(face: face, showArtist: false)
                        
                        if index < uniqueFaces.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                    
                    if !allArtists.isEmpty {
                        Divider()
                            .padding(.horizontal)
                        
                        CardArtistSection(artist: allArtists.joined(separator: ", "))
                    }
                } else {
                    cardFaceDetailsView(face: card)
                }

                Divider()
                    .padding(.horizontal)

                CardLegalitiesSection(card: card)

                Divider()
                    .padding(.horizontal)

                CardSetInfoSection(
                    setCode: card.set,
                    setName: card.setName,
                    collectorNumber: card.collectorNumber,
                    rarity: card.rarity,
                    lang: card.lang
                )

                if let oracleId = card.bestEffortOracleId {
                    Divider()
                        .padding(.horizontal)

                    CardOtherPrintsSection(
                        oracleId: oracleId,
                        currentCardId: card.id
                    )
                }

                if let allParts = card.allParts, !allParts.isEmpty {
                    let otherParts = allParts.filter { $0.id != card.id }
                    if !otherParts.isEmpty {
                        Divider()
                            .padding(.horizontal)

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
                    Divider()
                        .padding(.horizontal)

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

                Divider()
                    .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .padding(.top)
        }
        .task {
            await loadRulings(from: card.rulingsUri)
        }
        .toolbar {
            if isCurrentlyVisible {
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
        .sheet(item: $relatedCardToShow) { relatedCard in
            NavigationStack {
                CardDetailView(card: relatedCard)
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
    
    // swiftlint:disable function_body_length
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

        if let typeLine = face.typeLine, !typeLine.isEmpty {
            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let colorIndicator = face.colorIndicator, !colorIndicator.isEmpty {
                        ColorIndicatorView(colors: colorIndicator)
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
            Divider()
                .padding(.horizontal)

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

        if let power = face.power, let toughness = face.toughness {
            Divider()
                .padding(.horizontal)

            CardPowerToughnessSection(power: power, toughness: toughness)
        }

        if showArtist, let artist = face.artist {
            Divider()
                .padding(.horizontal)

            CardArtistSection(artist: artist)
        }
    }
    // swiftlint:enable function_body_length

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

// MARK: - Card Power/Toughness Section

private struct CardPowerToughnessSection: View {
    let power: String
    let toughness: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(power)/\(toughness)")
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Artist Section

private struct CardArtistSection: View {
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image("artist-nib")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Legalities Section

private struct CardLegalitiesSection: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegalityGridView(card: card)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Set Information Section

private struct CardSetInfoSection: View {
    let setCode: String
    let setName: String
    let collectorNumber: String
    let rarity: Card.Rarity
    let lang: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SetIconView(setCode: setCode)

                VStack(alignment: .leading, spacing: 4) {
                    Text(setName)
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Text(setCode.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("#\(collectorNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(rarity.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(languageDisplay(for: lang))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func languageDisplay(for lang: String) -> String {
        let languages: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ja": "Japanese",
            "ko": "Korean",
            "ru": "Russian",
            "zhs": "Simplified Chinese",
            "zht": "Traditional Chinese",
            "he": "Hebrew",
            "la": "Latin",
            "grc": "Ancient Greek",
            "ar": "Arabic",
            "sa": "Sanskrit",
            "px": "Phyrexian",
        ]
        return languages[lang.lowercased()] ?? lang.capitalized
    }
}

// MARK: - Card Related Parts Section

private struct CardRelatedPartsSection: View {
    let otherParts: [Card.RelatedCard]
    let isLoadingRelatedCard: Bool
    let onPartTapped: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Parts")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ForEach(otherParts.sorted { $0.name < $1.name }) { part in
                Button {
                    onPartTapped(part.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(part.typeLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isLoadingRelatedCard {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if part.id != otherParts.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Rulings Section

private struct CardRulingsSection: View {
    let rulings: [Card.Ruling]
    let isLoading: Bool
    let error: Error?
    let onRetry: () -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack {
                        Text("Loading rulings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else if let error = error {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Failed to load rulings")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else if rulings.isEmpty {
                    Text("No rulings available")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    ForEach(rulings) { ruling in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ruling.comment)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)

                            if let date = ruling.publishedAtAsDate {
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.top, ruling.id == rulings.first?.id ? 4 : 12)
                    }
                }
            }
        } label: {
            HStack {
                Text("Rulings")
                    .font(.headline)
                    .fontWeight(.semibold)

                if !isLoading && error == nil && !rulings.isEmpty {
                    Text("(\(rulings.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .tint(.primary)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Other Prints Section

private struct CardOtherPrintsSection: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var showingPrintsSheet = false

    var body: some View {
        Button {
            showingPrintsSheet = true
        } label: {
            HStack {
                Text("All Prints")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPrintsSheet) {
            CardPrintsListView(oracleId: oracleId, currentCardId: currentCardId)
        }
    }
}

// MARK: - Card Prints List View

private struct CardPrintsListView: View {
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
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
