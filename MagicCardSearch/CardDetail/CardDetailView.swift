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
                CardImageSection(card: card)
                
                VStack(spacing: 0) {
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
                        
                        CardLegalitiesSection(legalities: legalities, isGameChanger: card.gameChanger ?? false)
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
                                    .font(.body.weight(.semibold))
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                        }
                    }
            }
        }
    }
    
    private func loadRelatedCard(id: String) async {
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
            if let imageUrl = card.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
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
    let allParts: [CardResult.RelatedPart]
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
