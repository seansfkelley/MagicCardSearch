//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @Binding var unparsedInputText: String
    @FocusState var isSearchFocused: Bool
    @State private var textSelection: TextSelection?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                filters.isEmpty ? "Search for cards..." : "Add filters...",
                text: $unparsedInputText,
                selection: $textSelection
            )
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.none)
            .onSubmit {
                createNewFilterFromSearch(fallbackToNameFilter: true)
            }
            .onChange(of: isSearchFocused) { oldValue, newValue in
                if newValue && !unparsedInputText.isEmpty {
                    textSelection = TextSelection(range: unparsedInputText.startIndex..<unparsedInputText.endIndex)
                }
            }
            
            if !unparsedInputText.isEmpty {
                Button(action: {
                    unparsedInputText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: unparsedInputText) { (previous: String, current: String) in
            if previous.count < current.count && current.hasSuffix(" ") {
                createNewFilterFromSearch()
            }
        }
    }

    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = unparsedInputText.trimmingCharacters(in: .whitespaces)

        if let filter = SearchFilter.from(trimmed) {
            filters.append(filter)
            unparsedInputText = ""
        } else if fallbackToNameFilter {
            let unquoted = stripMatchingQuotes(from: trimmed)
            if !unquoted.isEmpty {
                filters.append(SearchFilter("name", .equal, unquoted))
                unparsedInputText = ""
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
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                SearchBarView(
                    filters: $filters,
                    unparsedInputText: $text,
                    isSearchFocused: _isFocused
                )
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    return PreviewWrapper()
}
