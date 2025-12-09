//
//  CardDetailContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//


import SwiftUI

struct CardDetailView: View {
    let card: CardResult
    
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
                }
                .background(Color(.systemBackground))
            }
            .padding(.top)
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
