//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct SymbolSuggestion {
    let textInputRange: Range<String.Index>
    let symbolParts: String
}

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?

    @FocusState var isSearchFocused: Bool
    @State private var showSymbolPicker = false
    @State private var partialSymbol: SymbolSuggestion?
    
    @Bindable var autocompleteProvider: CombinedSuggestionProvider

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                Group {
                    if autocompleteProvider.isLoading {
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
                }
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
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
                    SymbolPickerView(partialText: partialSymbol?.symbolParts ?? "") { symbol in
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
            checkForPartialSymbol(current)
        }
    }

    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else { return }

        if let filter = SearchFilter.tryParseUnambiguous(trimmed) {
            filters.append(filter)
            inputText = ""
        } else if fallbackToNameFilter {
            filters.append(SearchFilter.basic(.name(trimmed, false)))
            inputText = ""
        }
    }

    private func insertSymbol(_ symbol: String) {
        if let partial = partialSymbol {
            inputText.replaceSubrange(partial.textInputRange, with: symbol)
            let location = inputText.index(partial.textInputRange.lowerBound, offsetBy: symbol.count)
            inputSelection = .init(range: location..<location)
            partialSymbol = nil
        } else if let selection = inputSelection {
            switch selection.indices {
            case .selection(let range):
                inputText.replaceSubrange(range, with: symbol)
                let location = inputText.index(range.lowerBound, offsetBy: symbol.count)
                inputSelection = .init(range: location..<location)
            case .multiSelection:
                // TODO: how or why
                // swiftlint:disable:next fallthrough
                fallthrough
            @unknown default:
                inputText += symbol
                inputSelection = .init(range: inputText.endIndex..<inputText.endIndex)
            }
        } else {
            inputText += symbol
            inputSelection = .init(range: inputText.endIndex..<inputText.endIndex)
        }
    }
    
    private func checkForPartialSymbol(_ text: String) {
        if let match = try? /{[a-zA-Z\/\s]*$/.firstMatch(in: text) {
            let matchedText = String(text[match.range])
            let filteredText = matchedText.filter { $0.isLetter || $0 == "/" }
            partialSymbol = SymbolSuggestion(textInputRange: match.range, symbolParts: filteredText)
            showSymbolPicker = true
        } else if partialSymbol != nil {
            partialSymbol = nil
            showSymbolPicker = false
        }
    }
}

// MARK: - Symbol Picker

struct SymbolPickerView: View {
    let partialText: String
    let onSymbolSelected: (String) -> Void
    
    private let allSymbolGroups: [[String]] = [
        ["{T}", "{Q}", "{S}", "{E}"],
        ["{W}", "{U}", "{B}", "{R}", "{G}", "{C}"],
        ["{X}", "{1}", "{2}", "{3}", "{4}", "{5}", "{6}", "{7}", "{8}", "{9}"],
        ["{W/U}", "{W/B}", "{U/B}", "{U/R}", "{B/R}", "{B/G}", "{R/W}", "{R/G}", "{G/W}", "{G/U}"],
        ["{2/W}", "{2/U}", "{2/B}", "{2/R}", "{2/G}"],
        ["{W/P}", "{U/P}", "{B/P}", "{R/P}", "{G/P}"]
    ]
    
    private var selectableSymbols: Set<String> {
        let lowercasedPartial = partialText.lowercased()
        
        // If partial is empty, match everything
        if lowercasedPartial.isEmpty {
            return Set(allSymbolGroups.flatMap { $0 })
        }
        
        // Split partial content on '/' to get parts to match
        let partialParts = lowercasedPartial.split(separator: "/").map(String.init)
        
        var matchingSymbols = Set<String>()
        
        for group in allSymbolGroups {
            for symbol in group {
                // Extract content between braces
                let symbolContent = symbol.dropFirst().dropLast().lowercased() // Remove '{' and '}'
                let symbolParts = symbolContent.split(separator: "/").map(String.init)
                
                // All partial parts must match at least one symbol part
                let allMatch = partialParts.allSatisfy { partialPart in
                    symbolParts.contains { symbolPart in
                        symbolPart.hasPrefix(partialPart)
                    }
                }
                
                if allMatch {
                    matchingSymbols.insert(symbol)
                }
            }
        }
        
        return matchingSymbols
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(allSymbolGroups.enumerated()), id: \.offset) { _, symbols in
                SymbolGroupRow(
                    symbols: symbols,
                    selectableSymbols: selectableSymbols,
                    onSymbolTapped: onSymbolSelected
                )
            }
        }
        .padding()
    }
}

struct SymbolGroupRow: View {
    let symbols: [String]
    let selectableSymbols: Set<String>
    let onSymbolTapped: (String) -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    let isSelectable = selectableSymbols.contains(symbol)
                    Button(action: {
                        onSymbolTapped(symbol)
                    }) {
                        MtgSymbolView(symbol, size: 32, oversize: 32)
                    }
                    .buttonStyle(.plain)
                    .opacity(isSelectable ? 1.0 : 0.3)
                    .disabled(!isSelectable)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        let isSelectable = selectableSymbols.contains(symbol)
                        Button(action: {
                            onSymbolTapped(symbol)
                        }) {
                            MtgSymbolView(symbol, size: 32, oversize: 32)
                        }
                        .buttonStyle(.plain)
                        .opacity(isSelectable ? 1.0 : 0.3)
                        .disabled(!isSelectable)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
