//
//  CardDetailView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI

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
                For0Each(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardDetailView(card: card)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(cards[currentIndex].name)
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
        }
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
