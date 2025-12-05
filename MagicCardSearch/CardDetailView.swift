//
//  CardDetailView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

// MARK: - Card Detail Navigator

struct CardDetailNavigator: View {
    let cards: [CardResult]
    let initialIndex: Int
    
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(cards: [CardResult], initialIndex: Int) {
        self.cards = cards
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardDetailView(card: card)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(cards[currentIndex].name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .status) {
                    Text("\(currentIndex + 1) of \(cards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Card Detail View

struct CardDetailView: View {
    let card: CardResult
    
    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(0.7, contentMode: .fit)
                .frame(maxWidth: 300)
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
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            Text("Card ID: \(card.id)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Single Card") {
    CardDetailNavigator(
        cards: [
            CardResult(id: "1", name: "Black Lotus", imageUrl: nil),
            CardResult(id: "2", name: "Mox Ruby", imageUrl: nil),
            CardResult(id: "3", name: "Time Walk", imageUrl: nil)
        ],
        initialIndex: 0
    )
}

#Preview("Card Detail Only") {
    CardDetailView(
        card: CardResult(
            id: "preview-id",
            name: "Black Lotus",
            imageUrl: nil
        )
    )
}
