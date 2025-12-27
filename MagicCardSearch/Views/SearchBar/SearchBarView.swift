//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI
import FocusOnAppear
import SwiftUIIntrospect

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Bindable var autocompleteProvider: CombinedSuggestionProvider
    let searchHistoryTracker: SearchHistoryTracker
    let onSubmit: () -> Void

    @State private var showSymbolPicker = false

    var body: some View {
        SearchBarLayout(icon: autocompleteProvider.loadingState.isLoadingDebounced ? .progress : .visible) {
            TextField(
                filters.isEmpty ? "Search for cards..." : "Add filters...",
                text: $inputText,
                selection: $inputSelection,
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.none)
            .submitLabel(.search)
            // I would like to do the below, but it seems to prevent third-party keyboards from
            // being allowed to be the default keyboard. When set along with one or more of the
            // preceding options (textContentType? autocorrectionDisabled?) it does successfully get
            // rid of the predictive text bar that is not very useful.
            // .keyboardType(.asciiCapable)
            .introspect(.textField, on: .iOS(.v26)) { textView in
                textView.smartDashesType = .no
                textView.smartQuotesType = .no
                textView.smartInsertDeleteType = .no
            }
            .onSubmit {
                createNewFilterFromSearch(fallbackToNameFilter: true)
                onSubmit()
            }
            .focusOnAppear(config: .init(
                returnKeyType: .search,
                autocorrectionType: .no,
                autocapitalizationType: .none,
            ))
            .frame(maxWidth: .infinity)

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
        }
        .onChange(of: inputText) { previous, current in
            if Self.didAppendClosingCharacter(previous, current, inputSelection) {
                createNewFilterFromSearch()
            } else if let (newText, newSelection) = removeAutoinsertedWhitespace(current, inputSelection), newText != inputText {
                inputText = newText
                inputSelection = newSelection
            }
        }
    }

    private static func didAppendClosingCharacter(_ previous: String, _ current: String, _ selection: TextSelection?) -> Bool {
        guard current.count > previous.count else {
            return false
        }

        guard current.firstMatch(of: /[ '"\)\/]$/) != nil else {
            return false
        }

        // Aggressively default to true because it seems like safer default behavior.
        return if let selection = selection {
            switch selection.indices {
            case .selection(let range): range.upperBound == current.endIndex
            case .multiSelection: true
            @unknown default: true
            }
        } else {
            // A cursor at a single point without a selection is still represented as a non-nil
            // zero-length range, so I guess this branch is only hit if you're not focused on it?
            true
        }
    }

    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else { return }
        
        // FIXME: This is kind of gross; shouldn't we be able to unconditionally pass it through to
        // the parser and then it can tell us if it's valid or not?
        //
        // TODO: The parenthesized parser is a superset of PartialSearchFilter. This control flow
        // should be cleaned up to not have duplicative regexes.
        if (try? /^-?\(/.prefixMatch(in: trimmed)) != nil {
            if let disjunction = ParenthesizedDisjunction.tryParse(trimmed), let filter = disjunction.toSearchFilter() {
                filters.append(.disjunction(filter))
                inputText = ""
                return // TODO: gross control flow
            }
        } else if let filter = PartialSearchFilter.from(trimmed).toComplete() {
            filters.append(filter)
            searchHistoryTracker.recordUsage(of: filter)
            inputText = ""
            return // TODO: gross control flow
        }

        if fallbackToNameFilter {
            let filter = SearchFilter.name(false, false, trimmed)
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
