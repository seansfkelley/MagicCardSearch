//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct CardDetailView: View {
    let card: CardResult
    var isCurrentlyVisible: Bool = true

    @State private var relatedCardToShow: CardResult?
    @State private var isLoadingRelatedCard = false
    @ObservedObject private var listManager = CardListManager.shared
    private let cardSearchService = CardSearchService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch card {
                case .regular(let regularCard):
                    cardFaceView(
                        face: CardFace(from: regularCard),
                        fullCardName: regularCard.name
                    )
                case .transforming(let transformingCard):
                    cardFaceView(
                        face: transformingCard.frontFace,
                        fullCardName: transformingCard.name
                    )
                    
                    Spacer().frame(height: 24)
                    
                    cardFaceView(
                        face: transformingCard.backFace,
                        fullCardName: transformingCard.name
                    )
                }

                if let legalities = card.legalities, !legalities.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    CardLegalitiesSection(
                        legalities: legalities,
                        isGameChanger: card.gameChanger ?? false
                    )
                }

                // Set Information Section
                if card.setCode != nil || card.setName != nil || card.collectorNumber != nil || card.rarity != nil || card.lang != nil {
                    Divider()
                        .padding(.horizontal)

                    CardSetInfoSection(
                        setCode: card.setCode,
                        setName: card.setName,
                        collectorNumber: card.collectorNumber,
                        rarity: card.rarity,
                        lang: card.lang
                    )
                }

                if let allParts = card.allParts, !allParts.isEmpty {
                    Divider()
                        .padding(.horizontal)
                    
                    CardRelatedPartsSection(
                        allParts: allParts,
                        isLoadingRelatedCard: isLoadingRelatedCard,
                        onPartTapped: { partId in
                            Task {
                                await loadRelatedCard(id: partId)
                            }
                        }
                    )
                }
            }
            .background(Color(.systemBackground))
            .padding(.top)
        }
        .toolbar {
            if isCurrentlyVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let listItem = CardListItem(from: card)
                        listManager.toggleCard(listItem)
                    } label: {
                        Image(systemName: listManager.contains(cardId: card.id) ? "star.fill" : "star")
                    }
                }
                
                if let scryfallUri = card.scryfallUri,
                   let url = URL(string: scryfallUri) {
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

    // MARK: - Card Face View
    
    private func cardFaceView(face: CardFace, fullCardName: String) -> some View {
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

    private func loadRelatedCard(id: String) async {
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
}

// MARK: - CardFace Extension

extension CardFace {
    /// Create a CardFace from a RegularCard
    init(from card: RegularCard) {
        self.name = card.name
        self.smallImageUrl = card.smallImageUrl
        self.normalImageUrl = card.normalImageUrl
        self.largeImageUrl = card.largeImageUrl
        self.manaCost = card.manaCost
        self.typeLine = card.typeLine
        self.oracleText = card.oracleText
        self.flavorText = card.flavorText
        self.power = card.power
        self.toughness = card.toughness
        self.artist = card.artist
        self.colors = card.colors
        self.colorIndicator = card.colorIndicator
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
    let legalities: [String: String]
    let isGameChanger: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegalityGridView(legalities: legalities, isGameChanger: isGameChanger)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Set Information Section

private struct CardSetInfoSection: View {
    let setCode: String?
    let setName: String?
    let collectorNumber: String?
    let rarity: String?
    let lang: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let setName = setName {
                HStack(spacing: 12) {
                    if let setCode = setCode {
                        SetIconView(setCode: setCode)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 8) {
                            if let setCode = setCode {
                                Text(setCode.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let collectorNumber = collectorNumber {
                                Text("#\(collectorNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let rarity = rarity {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text(rarity.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if let lang = lang {
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
            "px": "Phyrexian"
        ]
        return languages[lang.lowercased()] ?? lang.capitalized
    }
}

// MARK: - Card Related Parts Section

private struct CardRelatedPartsSection: View {
    let allParts: [RelatedPart]
    let isLoadingRelatedCard: Bool
    let onPartTapped: (String) -> Void

    var body: some View {
        List {
            Section("Related Parts") {
                ForEach(allParts) { part in
                    Button {
                        onPartTapped(part.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(part.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if let typeLine = part.typeLine {
                                    Text(typeLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        // TODO: wtf. There has got to be a way to tell the list to just be its own
        // natural height.
        .frame(height: CGFloat(allParts.count) * 60 + 60)
    }
}

// MARK: - Card Face Image Section

private struct CardFaceImageSection: View {
    let face: CardFace
    let fullCardName: String

    var body: some View {
        Group {
            if let imageUrl = face.largeImageUrl, let url = URL(string: imageUrl) {
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
    let face: CardFace
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
    let face: CardFace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(face.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let manaCost = face.manaCost, !manaCost.isEmpty {
                    ManaCostView(manaCost, size: 20)
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
    let face: CardFace
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
    let face: CardFace

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
