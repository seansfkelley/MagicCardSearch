//
//  FilterPopoverView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-15.
//

import SwiftUI

struct PrintFilterSettings: Equatable {
    enum FrameFilter: String, CaseIterable {
        case any = "Any"
        case retro = "Retro"
        case modern = "Modern"
    }
    
    enum TextFilter: String, CaseIterable {
        case any = "Any"
        case normal = "Normal"
        case fullArt = "Full-art"
    }
    
    enum GameFilter: String, CaseIterable {
        case any = "Any"
        case digital = "Digital"
        case paper = "Paper"
    }
    
    var frame: FrameFilter = .any
    var text: TextFilter = .any
    var game: GameFilter = .any
    
    var isDefault: Bool {
        frame == .any && text == .any && game == .any
    }
    
    mutating func reset() {
        frame = .any
        text = .any
        game = .any
    }
    
    func toQueryFor(oracleId: String) -> String {
        var query = "oracleid:\(oracleId) include:extras unique:prints order:released dir:desc"

        switch frame {
        case .any:
            break
        case .retro:
            query += " frame:old"
        case .modern:
            query += " frame:new"
        }
        
        switch text {
        case .any:
            break
        case .normal:
            query += " -is:full"
        case .fullArt:
            query += " is:full"
        }
        
        switch game {
        case .any:
            break
        case .digital:
            query += " (game:mtgo OR game:arena)"
        case .paper:
            query += " game:paper"
        }
        
        return query
    }
}

struct FilterPopoverView: View {
    @Binding var filterSettings: PrintFilterSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section("Frame") {
                Picker("Frame", selection: $filterSettings.frame) {
                    ForEach(PrintFilterSettings.FrameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Text") {
                Picker("Text", selection: $filterSettings.text) {
                    ForEach(PrintFilterSettings.TextFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Game") {
                Picker("Game", selection: $filterSettings.game) {
                    ForEach(PrintFilterSettings.GameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                filterSettings.reset()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Show All Prints")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(filterSettings.isDefault ? .gray : .red)
            }
            .buttonStyle(.borderless)
            .disabled(filterSettings.isDefault)
            .padding(.top)
        }
        .padding(20)
        .frame(width: 320)
        .glassEffect(.clear, in: .rect(cornerRadius: 16))
    }
}
