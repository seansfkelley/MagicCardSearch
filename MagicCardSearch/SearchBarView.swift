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
                }
                .buttonStyle(.plain)
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
