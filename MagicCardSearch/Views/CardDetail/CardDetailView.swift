//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

// swiftlint:disable file_length

import SwiftUI
import ScryfallKit

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
                if let (front, back) = card.bothFaces {
                    cardFaceView(
                        face: front,
                        fullCardName: card.name
                    )
                
                    Spacer().frame(height: 24)
                
                    cardFaceView(
                        face: back,
                        fullCardName: card.name
                    )
                } else {
                    singleFacedCardView
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

                Divider()
                    .padding(.horizontal)

                CardOtherPrintsSection(
                    oracleId: card.oracleId,
                    currentCardId: card.id
                )

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
                        Image(systemName: listManager.contains(cardId: card.id) ? "bookmark.fill" : "bookmark")
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
    
    // MARK: - Single-Faced Card View
    
    @ViewBuilder private var singleFacedCardView: some View {
        // Image Section
        if let imageUrl = card.primaryImageUris?.normal, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(height: 400)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                case .failure:
                    imagePlaceholder
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(card.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let manaCost = card.manaCost, !manaCost.isEmpty {
                    ManaCostView(manaCost, size: 20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        
        if let typeLine = card.typeLine {
            Divider()
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let colorIndicator = card.colorIndicator, !colorIndicator.isEmpty {
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
        
        // Oracle/Flavor Text
        Divider()
            .padding(.horizontal)
        
        VStack(alignment: .leading, spacing: 12) {
            if let oracleText = card.oracleText, !oracleText.isEmpty {
                OracleTextView(oracleText)
            }

            if let flavorText = card.flavorText, !flavorText.isEmpty {
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
        
        if let power = card.power, let toughness = card.toughness {
            Divider()
                .padding(.horizontal)
            
            CardPowerToughnessSection(power: power, toughness: toughness)
        }
        
        if let artist = card.artist {
            Divider()
                .padding(.horizontal)
            
            CardArtistSection(artist: artist)
        }
    }
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 400)
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text(card.name)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
            .padding(.horizontal)
    }

    // MARK: - Card Face View
    
    private func cardFaceView(face: Card.Face, fullCardName: String) -> some View {
        VStack(spacing: 0) {
            CardFaceImageSection(
                face: face,
                fullCardName: fullCardName
            )
            
            CardFaceHeaderSection(face: face)
            
            if let typeLine = face.typeLine, !typeLine.isEmpty {
                Divider()
                    .padding(.horizontal)
                
                CardFaceTypeLineSection(face: face, typeLine: typeLine)
            }
            
            if face.oracleText != nil || face.flavorText != nil {
                Divider()
                    .padding(.horizontal)
                
                CardFaceTextSection(face: face)
            }
            
            if let power = face.power, let toughness = face.toughness {
                Divider()
                    .padding(.horizontal)
                
                CardPowerToughnessSection(power: power, toughness: toughness)
            }
            
            if let artist = face.artist {
                Divider()
                    .padding(.horizontal)
                
                CardArtistSection(artist: artist)
            }
        }
    }

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
            rulings = try await rulingsService.fetchRulings(from: urlString, oracleId: card.oracleId)
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

// MARK: - Card Face Image Section

private struct CardFaceImageSection: View {
    let face: Card.Face
    let fullCardName: String

    var body: some View {
        Group {
            if let imageUrl = face.imageUris?.large, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .contextMenu {
                                ShareLink(item: url, preview: SharePreview(face.name, image: image))
                                
                                Button {
                                    if let uiImage = ImageRenderer(content: image).uiImage {
                                        UIPasteboard.general.image = uiImage
                                    }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    case .failure:
                        CardFaceImagePlaceholder(face: face, cardName: fullCardName)
                    @unknown default:
                        CardFaceImagePlaceholder(face: face, cardName: fullCardName)
                    }
                }
            } else {
                CardFaceImagePlaceholder(face: face, cardName: fullCardName)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}

// MARK: - Card Face Image Placeholder

private struct CardFaceImagePlaceholder: View {
    let face: Card.Face
    let cardName: String

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text(face.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
    }
}

// MARK: - Card Face Header Section

private struct CardFaceHeaderSection: View {
    let face: Card.Face

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(face.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !face.manaCost.isEmpty {
                    ManaCostView(face.manaCost, size: 20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Face Type Line Section

private struct CardFaceTypeLineSection: View {
    let face: Card.Face
    let typeLine: String

    var body: some View {
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
}

// MARK: - Card Face Text Section

private struct CardFaceTextSection: View {
    let face: Card.Face

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let oracleText = face.oracleText, !oracleText.isEmpty {
                OracleTextView(oracleText)
            }

            if let flavorText = face.flavorText, !flavorText.isEmpty {
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

            if face.oracleText == nil && face.flavorText == nil {
                Text("No text")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
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
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading prints...")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
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
                } else if prints.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(prints.enumerated()), id: \.element.id) { index, card in
                                CardPrintGridItem(card: card, isCurrentPrint: card.id == currentCardId)
                                    .onTapGesture {
                                        selectedCardIndex = index
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
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
            // Card Image
            Group {
                if let imageUrl = card.primaryImageUris?.normal, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(0.7, contentMode: .fit)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            imagePlaceholder
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
            }
            
            // Set Info
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
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
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
                            MinimalCardDetailContent(card: card)
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
                            Image(systemName: listManager.contains(cardId: card.id) ? "bookmark.fill" : "bookmark")
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

// MARK: - Minimal Card Detail Content

private struct MinimalCardDetailContent: View {
    let card: Card
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Large image with context menu
                if let imageUrl = card.primaryImageUris?.large, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 500)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                                .contextMenu {
                                    ShareLink(item: url, preview: SharePreview(card.name, image: image))
                                    
                                    Button {
                                        if let uiImage = ImageRenderer(content: image).uiImage {
                                            UIPasteboard.general.image = uiImage
                                        }
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }
                        case .failure:
                            cardImagePlaceholder
                        @unknown default:
                            cardImagePlaceholder
                        }
                    }
                } else {
                    cardImagePlaceholder
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SetIconView(setCode: card.set)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.setName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 8) {
                                Text(card.set.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("#\(card.collectorNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(card.rarity.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if let releasedAt = card.releasedAtAsDate {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(releasedAt, format: .dateTime.year().month().day())
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
                
                Spacer().frame(height: 40)
            }
            .padding(.top)
        }
    }
    
    private var cardImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 500)
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text(card.name)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
            .padding(.horizontal)
    }
}
