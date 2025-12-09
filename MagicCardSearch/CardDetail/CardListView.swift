//
//  CardListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI

struct CardListView: View {
    @ObservedObject var listManager = CardListManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if listManager.cards.isEmpty {
                    emptyStateView
                } else {
                    cardListView
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: shareableText
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(listManager.cards.isEmpty)
                }
                
            }
        }
    }
    
    // MARK: - Shareable Text
    
    private var shareableText: String {
        listManager.sortedCards.map { card in
            return if let setCode = card.setCode {
                "1 \(card.name) (\(setCode)"
            } else {
                "1 \(card.name)"
            }
        }.joined(separator: "\n")
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Cards Saved")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the star button on any card to add it to your list.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Card List
    
    private var cardListView: some View {
        List {
            ForEach(listManager.sortedCards) { card in
                CardListRow(card: card)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                listManager.removeCard(withId: card.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            
            Section {
                Button(role: .destructive) {
                    // Clear all action will trigger on long press
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(list.isEmpty ? .gray : .red)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1)
                        .onEnded { _ in
                            withAnimation {
                                listManager.clearAll()
                            }
                        }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Card List Row

private struct CardListRow: View {
    let card: CardListItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Card Image
            Group {
                if let imageUrl = card.smallImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 60, height: 84)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 84)
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
            
            // Card Info
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let typeLine = card.typeLine {
                    Text(typeLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 60, height: 84)
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
    }
}

// MARK: - Preview

#Preview("With Cards") {
    CardListView()
}

#Preview("Empty State") {
    CardListView()
}
