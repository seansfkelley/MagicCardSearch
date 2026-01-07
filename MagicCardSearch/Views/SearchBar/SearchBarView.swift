import SwiftUI
import FocusOnAppear
import SwiftUIIntrospect

struct SearchBarView: View {
    @Binding var searchState: SearchState
    let isAutocompleteLoading: Bool

    @State private var showSymbolPicker = false
    // Write-only wrapper state for telling UIKit what we want. Never read from, but we still define
    // it like this so that we aren't creating a new wrapper Binding (and thereby changing the
    // object identity/underlying state) every render cycle.
    @State private var wrappedDesiredSelection: TextSelection?
    private let textFieldDelegate: SearchTextFieldDelegate

    init(searchState: Binding<SearchState>, isAutocompleteLoading: Bool) {
        self._searchState = searchState
        self.isAutocompleteLoading = isAutocompleteLoading

        // The only reason this is here is because UITextField.delegate is weak, so we need to
        // retain it as long as this view is alive.
        self.textFieldDelegate = SearchTextFieldDelegate(
            onReturn: {
                if let filter = searchState.wrappedValue.searchText.toSearchFilter().value {
                    searchState.wrappedValue.filters.append(filter)
                    searchState.wrappedValue.searchText = ""
                    searchState.wrappedValue.desiredSearchSelection = "".range
                    return false
                } else {
                    searchState.wrappedValue.performSearch()
                    return true
                }
            },
            actualSelection: searchState.actualSearchSelection
        )
    }

    var body: some View {
        SearchBarLayout(icon: isAutocompleteLoading ? .progress : .visible) {
            TextField(
                searchState.filters.isEmpty ? "Search for cards..." : "Add filters...",
                text: $searchState.searchText,
                selection: $wrappedDesiredSelection,
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.none)
            .submitLabel(.go)
            // I would like to do the below, but it seems to prevent third-party keyboards from
            // being allowed to be the default keyboard. When set along with one or more of the
            // preceding options (textContentType? autocorrectionDisabled?) it does successfully get
            // rid of the predictive text bar that is not very useful.
            // .keyboardType(.asciiCapable)
            .introspect(.textField, on: .iOS(.v26)) { textField in
                textField.smartDashesType = .no
                textField.smartQuotesType = .no
                textField.smartInsertDeleteType = .no
                textField.delegate = textFieldDelegate
            }
            .focusOnAppear(config: .init(
                returnKeyType: .go,
                autocorrectionType: .no,
                autocapitalizationType: .none,
            ))
            .frame(maxWidth: .infinity)

            if !searchState.searchText.isEmpty {
                Button(action: {
                    searchState.searchText = ""
                    searchState.desiredSearchSelection = "".endIndexRange
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
        .onChange(of: searchState.searchText) { previous, current in
            if !previous.isEmpty && current.isEmpty {
                showSymbolPicker = false
            }

            if Self.didAppend(characterFrom: [" "], to: previous, toCreate: current, withSelection: searchState.actualSearchSelection) {
                if current.allSatisfy({ $0.isWhitespace }) {
                    searchState.searchText = ""
                    searchState.desiredSearchSelection = "".endIndexRange
                    return
                }

                if (try? /^-?\(/.prefixMatch(in: searchState.searchText)) == nil {
                    let partial = PartialSearchFilter.from(searchState.searchText)
                    if case .name(let isExact, let term) = partial.content, case .bare(let content) = term {
                        searchState.searchText = PartialSearchFilter(
                            negated: partial.negated,
                            content: .name(isExact, .unterminated(.doubleQuote, content)),
                        )
                        .description
                        searchState.desiredSearchSelection = searchState.searchText.endIndexRange
                        return
                    }
                }
            }

            if Self.didAppend(characterFrom: [" ", "'", "\"", ")", "/"], to: previous, toCreate: current, withSelection: searchState.actualSearchSelection) {
                if case .valid(let filter) = searchState.searchText.toSearchFilter() {
                    searchState.filters.append(filter)
                    searchState.searchText = ""
                    searchState.desiredSearchSelection = "".endIndexRange
                }
                return
            }

            if let (newText, newSelection) = removeAutoinsertedWhitespace(current, searchState.actualSearchSelection),
               newText != searchState.searchText {
                searchState.searchText = newText
                searchState.desiredSearchSelection = newSelection
                return
            }
        }
        .onChange(of: searchState.filters) {
            showSymbolPicker = false
        }
        .onChange(of: searchState.desiredSearchSelection) {
            print("view saw desired change", searchState.desiredSearchSelection)
            wrappedDesiredSelection = .init(range: searchState.desiredSearchSelection)
        }
        .onChange(of: searchState.actualSearchSelection) {
            print("view saw actual change", searchState.actualSearchSelection)
        }
        .onChange(of: wrappedDesiredSelection) {
            wrappedDesiredSelection = nil
        }
    }

    private static func didAppend(
        characterFrom characters: Set<Character>,
        to previous: String,
        toCreate current: String,
        withSelection selection: Range<String.Index>,
    ) -> Bool {
        guard current.count > previous.count else {
            return false
        }

        guard let lastCharacter = current.last, characters.contains(lastCharacter) else {
            return false
        }

        return selection.upperBound == current.endIndex
    }

    private func insertSymbol(_ symbol: SymbolCode) {
        searchState.searchText.replaceSubrange(searchState.actualSearchSelection, with: symbol.normalized)
        let index = searchState.searchText.index(searchState.actualSearchSelection.lowerBound, offsetBy: symbol.normalized.count)
        searchState.desiredSearchSelection = index..<index
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

// MARK: - UITextField Delegate

private class SearchTextFieldDelegate: NSObject, UITextFieldDelegate {
    let onReturn: () -> Bool
    let actualSelection: Binding<Range<String.Index>>

    init(
        onReturn: @escaping () -> Bool,
        actualSelection: Binding<Range<String.Index>>
    ) {
        self.onReturn = onReturn
        self.actualSelection = actualSelection
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn()
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard let text = textField.text else { return }

        let newSelection = Range<String.Index>.from(range: textField.selectedTextRange, in: textField, text: text)

        print("setting to SwiftUI", newSelection)
        actualSelection.wrappedValue = newSelection
    }
}

// MARK: - TextSelection Extensions

@MainActor
extension Range where Bound == String.Index {
    static func from(range: UITextRange?, in textField: UITextField, text: String) -> Range<String.Index> {
        guard let range else { return text.endIndexRange }

        let startOffset = textField.offset(from: textField.beginningOfDocument, to: range.start)
        let endOffset = textField.offset(from: textField.beginningOfDocument, to: range.end)
        
        let startIndex = text.index(text.startIndex, offsetBy: Swift.max(0, Swift.min(startOffset, text.count)))
        let endIndex = text.index(text.startIndex, offsetBy: Swift.max(startOffset, Swift.min(endOffset, text.count)))

        return startIndex..<endIndex
    }
}
