//
//  CardDetailView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//
import SwiftUI

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: CardResult
    
    var body: some View {
        NavigationStack {
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
                        // Section 1: Name and Mana Cost
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
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Section 2: Type Line with Color Indicator
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                if let colorIndicator = card.colorIndicator, !colorIndicator.isEmpty {
                                    ColorIndicatorView(colors: colorIndicator)
                                }
                                
                                if let typeLine = card.typeLine {
                                    Text(typeLine)
                                        .font(.body)
                                        .italic()
                                } else {
                                    Text("Unknown Type")
                                        .font(.body)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Section 3: Text Box (Oracle and Flavor Text)
                        VStack(alignment: .leading, spacing: 12) {
                            if let oracleText = card.oracleText, !oracleText.isEmpty {
                                Text(formatOracleText(oracleText))
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if let flavorText = card.flavorText, !flavorText.isEmpty {
                                Text(flavorText)
                                    .font(.body)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
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
                        
                        // Section 4: Power/Toughness (conditional)
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
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Section 5: Artist Credit
                        VStack(alignment: .leading, spacing: 8) {
                            if let artist = card.artist {
                                HStack(spacing: 4) {
                                    Image(systemName: "paintbrush.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Artist unknown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.systemBackground))
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
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
    
    private func formatOracleText(_ text: String) -> String {
        // Replace common symbols with readable text
        // In a real implementation, you might want to render these as actual symbols
        var formatted = text
        formatted = formatted.replacingOccurrences(of: "{T}", with: "⤸")
        formatted = formatted.replacingOccurrences(of: "{Q}", with: "↷")
        return formatted
    }
}
