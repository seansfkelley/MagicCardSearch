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
    @State private var partialSymbolRange: Range<String.Index>?
    
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
        if let range = partialSymbolRange {
            inputText.replaceSubrange(range, with: symbol)
            let location = inputText.index(range.lowerBound, offsetBy: symbol.count)
            inputSelection = .init(range: location..<location)
            partialSymbolRange = nil
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
            partialSymbolRange = match.range
            showSymbolPicker = true
        } else if partialSymbolRange != nil {
            partialSymbolRange = nil
            showSymbolPicker = false
        }
    }
}

// MARK: - Symbol Picker

struct SymbolPickerView: View {
    let onSymbolSelected: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SymbolGroupRow(
                symbols: ["{T}", "{Q}", "{S}", "{E}"],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: ["{W}", "{U}", "{B}", "{R}", "{G}", "{C}"],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: ["{X}", "{1}", "{2}", "{3}", "{4}", "{5}", "{6}", "{7}", "{8}", "{9}"],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: [
                    "{W/U}", "{W/B}", "{U/B}", "{U/R}", "{B/R}",
                    "{B/G}", "{R/W}", "{R/G}", "{G/W}", "{G/U}",
                ],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: ["{2/W}", "{2/U}", "{2/B}", "{2/R}", "{2/G}" ],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: ["{W/P}", "{U/P}", "{B/P}", "{R/P}", "{G/P}" ],
                onSymbolTapped: onSymbolSelected
            )
        }
        .padding()
    }
}

struct SymbolGroupRow: View {
    let symbols: [String]
    let onSymbolTapped: (String) -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Button(action: {
                        onSymbolTapped(symbol)
                    }) {
                        MtgSymbolView(symbol, size: 32, oversize: 32)
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
                            MtgSymbolView(symbol, size: 32, oversize: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
