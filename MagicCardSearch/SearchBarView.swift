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
    let historyProvider: AutocompleteProvider

    @FocusState var isSearchFocused: Bool
    @State private var showSymbolPicker = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

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

            if isSearchFocused {
                Button(action: {
                    showSymbolPicker.toggle()
                }) {
                    Image(systemName: "curlybraces.square")
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
            }
        }
        .padding(.vertical)
        .padding(.horizontal)
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

        if let filter = SearchFilter.tryParseUnambiguous(trimmed) {
            filters.append(filter)
            historyProvider.recordFilterUsage(filter)
            inputText = ""
        } else if fallbackToNameFilter {
            let unquoted = stripMatchingQuotes(from: trimmed)
            if !unquoted.isEmpty {
                let filter = SearchFilter.name(unquoted)
                filters.append(filter)
                historyProvider.recordFilterUsage(filter)
                inputText = ""
            }
        }
    }

    private func insertSymbol(_ symbol: String) {
        if let selection = inputSelection {
            switch selection.indices {
            case .selection(let range):
                inputText.replaceSubrange(range, with: symbol)
                let location = inputText.index(range.lowerBound, offsetBy: symbol.count)
                inputSelection = .init(range: location..<location)
            case .multiSelection(_):
                // TODO: how or why
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

    private func stripMatchingQuotes(from string: String) -> String {
        if string.hasPrefix("\"") && string.hasSuffix("\"") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else if string.hasPrefix("'") && string.hasSuffix("'") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else {
            return string
        }
    }
}

// MARK: - Symbol Picker

struct SymbolPickerView: View {
    let onSymbolSelected: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SymbolGroupRow(
                symbols: ["{T}", "{Q}", "{S}"],
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
                symbols: ["{2/W}", "{2/U}", "{2/B}", "{2/R}", "{2/G}",],
                onSymbolTapped: onSymbolSelected
            )

            SymbolGroupRow(
                symbols: ["{W/P}", "{U/P}", "{B/P}", "{R/P}", "{G/P}",],
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
                        CircleSymbolView(symbol, size: 32)
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
                            CircleSymbolView(symbol, size: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = []
        @State private var inputText = ""
        @State private var inputSelection: TextSelection?
        @State private var historyProvider = AutocompleteProvider()
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                SearchBarView(
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    historyProvider: historyProvider,
                    isSearchFocused: _isFocused
                )
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    return PreviewWrapper()
}
