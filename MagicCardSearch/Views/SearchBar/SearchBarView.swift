//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?

    @FocusState var isSearchFocused: Bool
    @State private var showSymbolPicker = false
    
    @Bindable var autocompleteProvider: CombinedSuggestionProvider
    
    let historySuggestionProvider: HistorySuggestionProvider
    let onSubmit: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                Group {
                    if autocompleteProvider.loadingState.isLoadingDebounced {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                
                TextField(
                    filters.isEmpty ? "Search for cards..." : "Add filters...",
                    text: $inputText,
                    selection: $inputSelection
                )
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.none)
                // ASCII means we don't get smart quotes so can parse double quotes properly.
                .keyboardType(.asciiCapable)
                .submitLabel(.search)
                .onSubmit {
                    createNewFilterFromSearch(fallbackToNameFilter: true)
                    // Perform search and unfocus
                    isSearchFocused = false
                    onSubmit()
                }
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                        inputSelection = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    showSymbolPicker.toggle()
                }) {
                    Image(systemName: "curlybraces")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSymbolPicker, arrowEdge: .bottom) {
                    SymbolPickerView { symbol in
                        insertSymbol(symbol)
                        showSymbolPicker = false
                    }
                    .presentationCompactAdaptation(.popover)
                }
                .if(!isSearchFocused) { view in
                    // Do it this way to ensure we still contribute to layout!
                    view.hidden()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .onTapGesture {
            isSearchFocused = true
        }
        .onChange(of: inputText) { (previous: String, current: String) in
            if previous.count < current.count && current.hasSuffix(" ") {
                createNewFilterFromSearch()
            }
        }
    }

    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else { return }

        if let filter = SearchFilter.tryParseUnambiguous(trimmed) {
            filters.append(filter)
            historySuggestionProvider.recordUsage(of: filter)
            inputText = ""
        } else if fallbackToNameFilter {
            let filter = SearchFilter.basic(.name(trimmed, false))
            filters.append(filter)
            historySuggestionProvider.recordUsage(of: filter)
            inputText = ""
        }
    }

    private func insertSymbol(_ symbol: SymbolCode) {
        if let selection = inputSelection {
            switch selection.indices {
            case .selection(let range):
                inputText.replaceSubrange(range, with: symbol.normalized)
                let location = inputText.index(range.lowerBound, offsetBy: symbol.normalized.count)
                inputSelection = .init(range: location..<location)
            case .multiSelection:
                // TODO: how or why
                // swiftlint:disable:next fallthrough
                fallthrough
            @unknown default:
                inputText += symbol.normalized
                inputSelection = .init(range: inputText.endIndex..<inputText.endIndex)
            }
        } else {
            inputText += symbol.normalized
            inputSelection = .init(range: inputText.endIndex..<inputText.endIndex)
        }
    }
}

// MARK: - Symbol Picker

struct SymbolPickerView: View {
    let onSymbolSelected: (SymbolCode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SymbolGroupRow(
                symbols: [SymbolCode("{T}"), SymbolCode("{Q}"), SymbolCode("{S}"), SymbolCode("{E}")],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [SymbolCode("{W}"), SymbolCode("{U}"), SymbolCode("{B}"), SymbolCode("{R}"), SymbolCode("{G}"), SymbolCode("{C}")],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [SymbolCode("{X}"), SymbolCode("{1}"), SymbolCode("{2}"), SymbolCode("{3}"), SymbolCode("{4}"), SymbolCode("{5}"), SymbolCode("{6}"), SymbolCode("{7}"), SymbolCode("{8}"), SymbolCode("{9}")],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [
                    SymbolCode("{W/U}"), SymbolCode("{W/B}"), SymbolCode("{U/B}"), SymbolCode("{U/R}"), SymbolCode("{B/R}"),
                    SymbolCode("{B/G}"), SymbolCode("{R/W}"), SymbolCode("{R/G}"), SymbolCode("{G/W}"), SymbolCode("{G/U}"),
                ],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [SymbolCode("{2/W}"), SymbolCode("{2/U}"), SymbolCode("{2/B}"), SymbolCode("{2/R}"), SymbolCode("{2/G}") ],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [SymbolCode("{W/P}"), SymbolCode("{U/P}"), SymbolCode("{B/P}"), SymbolCode("{R/P}"), SymbolCode("{G/P}") ],
                onSymbolTapped: onSymbolSelected
            )
        }
        .padding()
    }
}

struct SymbolGroupRow: View {
    let symbols: [SymbolCode]
    let onSymbolTapped: (SymbolCode) -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Button(action: {
                        onSymbolTapped(symbol)
                    }) {
                        SymbolView(symbol, size: 32, oversize: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button(action: {
                            onSymbolTapped(symbol)
                        }) {
                            SymbolView(symbol, size: 32, oversize: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
