//
//  LegalityGridView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit

struct LegalityGridView: View {
    let card: Card
    
    // The weird order here is because the column view goes English reading order, and it's a lot
    // easier to get it to do the right thing like this than trying to flow it down the columns.
    private let orderedFormats: [Format] = [
        .standard,
        .pioneer,
        .historic,
        .modern,
        .brawl,
        .legacy,
        .vintage,
        .pauper,
        .commander,
        .penny,
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ], spacing: 12) {
            ForEach(orderedFormats, id: \.self) { format in
                LegalityItemView(
                    format: format,
                    legality: card.getLegality(for: format),
                    // TODO: ScryfallKit doesn't have this field, but it should.
                    isGameChanger: false,
                )
            }
        }
    }
}

private struct LegalityItemView: View {
    let format: Format
    let legality: Card.Legality
    let isGameChanger: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(legalityColor)
                .frame(width: 80, height: 28)
                .overlay(
                    Text(legalityDisplayText.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                )
            
            Text(format.label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var legalityDisplayText: String {
        return if format == .commander && isGameChanger {
            "\(legality.label)/GC"
        } else {
            legality.label
        }
    }
    
    private var legalityColor: Color {
        if format == .commander && legality == .legal && isGameChanger {
            // TODO: A different color.
            return .green
        } else {
            return switch legality {
            case .legal: .green
            case .notLegal: .gray
            case .restricted: .orange
            case .banned: .red
            }
        }
    }
}
