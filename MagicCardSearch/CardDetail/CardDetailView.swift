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
                                placeholderView
                            @unknown default:
                                placeholderView
                            }
                        }
                    } else {
                        placeholderView
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                .padding(.bottom, 24)
                
                VStack(spacing: 0) {
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
                    
                    if let typeLine = card.typeLine, !typeLine.isEmpty {
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
                        
                        if card.oracleText == nil && card.flavorText == nil {
                            Text("No text")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let power = card.power, let toughness = card.toughness {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(power)/\(toughness)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let artist = card.artist {
                        Divider()
                            .padding(.horizontal)
                        
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
                    
                    if let legalities = card.legalities, !legalities.isEmpty {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            LegalityGridView(legalities: legalities, isGameChanger: card.gameChanger ?? false)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let allParts = card.allParts, !allParts.isEmpty {
                        List {
                            Section("Related Parts") {
                                ForEach(allParts) { part in
                                    Button {
                                        Task {
                                            await loadRelatedCard(id: part.id)
                                        }
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
    
    private var placeholderView: some View {
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
