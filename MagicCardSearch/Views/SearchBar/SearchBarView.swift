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
    
    let searchHistoryTracker: SearchHistoryTracker
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
            searchHistoryTracker.recordUsage(of: filter)
            inputText = ""
        } else if fallbackToNameFilter {
            let filter = SearchFilter.basic(.name(trimmed, false))
            filters.append(filter)
            searchHistoryTracker.recordUsage(of: filter)
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
                symbols: ["{T}", "{Q}", "{S}", "{E}", "{P}"].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: ["{W}", "{U}", "{B}", "{R}", "{G}", "{C}"].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: ["{X}", "{1}", "{2}", "{3}", "{4}", "{5}", "{6}", "{7}", "{8}", "{9}"].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: [
                    "{W/U}", "{W/B}", "{U/B}", "{U/R}", "{B/R}",
                    "{B/G}", "{R/W}", "{R/G}", "{G/W}", "{G/U}",
                ].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: [
                    "{2/W}", "{2/U}", "{2/B}", "{2/R}", "{2/G}",
                    "{C/W}", "{C/U}", "{C/B}", "{C/R}", "{C/G}",
                ].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: ["{W/P}", "{U/P}", "{B/P}", "{R/P}", "{G/P}"].map(SymbolCode.init),
                onSymbolTapped: onSymbolSelected
            )
            SymbolGroupRow(
                symbols: [
                    "{W/U/P}", "{W/B/P}", "{U/B/P}", "{U/R/P}", "{B/R/P}",
                    "{B/G/P}", "{R/W/P}", "{R/G/P}", "{G/W/P}", "{G/U/P}",
                ].map(SymbolCode.init),
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
