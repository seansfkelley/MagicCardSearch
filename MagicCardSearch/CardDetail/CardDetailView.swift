//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct CardDetailView: View {
    let card: CardResult

    @State private var relatedCardToShow: CardResult?
    @State private var isLoadingRelatedCard = false
    private let cardSearchService = CardSearchService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch card {
                case .regular:
                    regularCardView
                case .transforming(let transformingCard):
                    transformingCardView(transformingCard)
                }
            }
            .padding(.top)
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

    // MARK: - Regular Card View

    private var regularCardView: some View {
        VStack(spacing: 0) {
            CardImageSection(card: card)

            CardHeaderSection(card: card)

            if let typeLine = card.typeLine, !typeLine.isEmpty {
                Divider()
                    .padding(.horizontal)

                CardTypeLineSection(card: card, typeLine: typeLine)
            }

            Divider()
                .padding(.horizontal)

            CardTextSection(card: card)

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

            if let legalities = card.legalities, !legalities.isEmpty {
                Divider()
                    .padding(.horizontal)

                CardLegalitiesSection(
                    legalities: legalities,
                    isGameChanger: card.gameChanger ?? false
                )
            }

            if let allParts = card.allParts, !allParts.isEmpty {
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
    }

    // MARK: - Transforming Card View

    private func transformingCardView(_ transformingCard: TransformingCard) -> some View {
        VStack(spacing: 0) {
            CardFaceImageSection(
                face: transformingCard.frontFace,
                cardName: transformingCard.name,
                label: "Front"
            )

            CardFaceHeaderSection(face: transformingCard.frontFace)

            if let typeLine = transformingCard.frontFace.typeLine, !typeLine.isEmpty {
                Divider()
                    .padding(.horizontal)

                CardFaceTypeLineSection(face: transformingCard.frontFace, typeLine: typeLine)
            }

            Divider()
                .padding(.horizontal)

            CardFaceTextSection(face: transformingCard.frontFace)

            if let power = transformingCard.frontFace.power,
                let toughness = transformingCard.frontFace.toughness
            {
                Divider()
                    .padding(.horizontal)

                CardPowerToughnessSection(power: power, toughness: toughness)
            }

            if let artist = transformingCard.frontFace.artist {
                Divider()
                    .padding(.horizontal)

                CardArtistSection(artist: artist)
            }

            Spacer().frame(height: 24)

            CardFaceImageSection(
                face: transformingCard.backFace,
                cardName: transformingCard.name,
                label: "Back"
            )

            CardFaceHeaderSection(face: transformingCard.backFace)

            if let typeLine = transformingCard.backFace.typeLine, !typeLine.isEmpty {
                Divider()
                    .padding(.horizontal)

                CardFaceTypeLineSection(face: transformingCard.backFace, typeLine: typeLine)
            }

            Divider()
                .padding(.horizontal)

            CardFaceTextSection(face: transformingCard.backFace)

            if let power = transformingCard.backFace.power,
                let toughness = transformingCard.backFace.toughness
            {
                Divider()
                    .padding(.horizontal)

                CardPowerToughnessSection(power: power, toughness: toughness)
            }

            if let artist = transformingCard.backFace.artist {
                Divider()
                    .padding(.horizontal)

                CardArtistSection(artist: artist)
            }

            // Legalities (shared for the whole card)
            if let legalities = transformingCard.legalities, !legalities.isEmpty {
                Divider()
                    .padding(.horizontal)

                CardLegalitiesSection(
                    legalities: legalities,
                    isGameChanger: transformingCard.gameChanger ?? false
                )
            }

            if let allParts = transformingCard.allParts, !allParts.isEmpty {
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

// MARK: - Card Image Section

private struct CardImageSection: View {
    let card: CardResult

    var body: some View {
        Group {
            if let imageUrl = card.largeImageUrl, let url = URL(string: imageUrl) {
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
                                ShareLink(item: url, preview: SharePreview(card.name, image: image))
                                
                                Button {
                                    // Copy the rendered image to pasteboard
                                    if let uiImage = ImageRenderer(content: image).uiImage {
                                        UIPasteboard.general.image = uiImage
                                    }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    case .failure:
                        CardImagePlaceholder(card: card)
                    @unknown default:
                        CardImagePlaceholder(card: card)
                    }
                }
            } else {
                CardImagePlaceholder(card: card)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}

// MARK: - Card Image Placeholder

private struct CardImagePlaceholder: View {
    let card: CardResult

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text(card.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
    }
}

// MARK: - Card Header Section

private struct CardHeaderSection: View {
    let card: CardResult

    var body: some View {
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
    }
}

// MARK: - Card Type Line Section

private struct CardTypeLineSection: View {
    let card: CardResult
    let typeLine: String

    var body: some View {
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
}

// MARK: - Card Text Section

private struct CardTextSection: View {
    let card: CardResult

    var body: some View {
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

            if card.oracleText == nil && card.flavorText == nil {
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
    let cardName: String
    let label: String

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
                        CardFaceImagePlaceholder(face: face, cardName: cardName)
                    @unknown default:
                        CardFaceImagePlaceholder(face: face, cardName: cardName)
                    }
                }
            } else {
                CardFaceImagePlaceholder(face: face, cardName: cardName)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 16)
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
