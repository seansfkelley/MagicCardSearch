//
//  ManaCostView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct ManaCostView: View {
    let manaCost: String
    let size: CGFloat

    init(_ manaCost: String, size: CGFloat = 16) {
        self.manaCost = manaCost
        self.size = size
    }

    var body: some View {
        if let symbols = safelyParseManaCost(manaCost) {
            HStack(spacing: 2) {
                ForEach(symbols.enumerated(), id: \.offset) { _, symbol in
                    CircleSymbolView(symbol, size: size)
                }
            }
        } else {
            Text(manaCost)
                .font(.system(size: size * 0.6))
                .foregroundStyle(.secondary)
        }
    }

    private func safelyParseManaCost(_ cost: String) -> [String]? {
        let pattern = #/\{[^}]+\}/#
        
        var symbols: [String] = []
        var consumedLength = 0
        
        for match in cost.matches(of: pattern) {
            let matchRange = match.range
            let matchStart = cost.distance(from: cost.startIndex, to: matchRange.lowerBound)
            
            guard matchStart == consumedLength else {
                return nil
            }
            
            symbols.append(String(cost[matchRange]))
            consumedLength = cost.distance(from: cost.startIndex, to: matchRange.upperBound)
        }
        
        guard consumedLength == cost.count else {
            return nil
        }
        
        return symbols
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        ManaCostView("{3}{U}{U}", size: 24)
        ManaCostView("{2}{W}{U}", size: 24)
        ManaCostView("{X}{R}{R}", size: 24)
        ManaCostView("{W/U}{W/U}{W/U}", size: 24)
        ManaCostView("{5}{B}{B}{B}", size: 24)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
}
