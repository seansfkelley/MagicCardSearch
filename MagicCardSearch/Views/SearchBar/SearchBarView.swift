import SwiftUI
import FocusOnAppear
import SwiftUIIntrospect

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    let isAutocompleteLoading: Bool
    let searchState: SearchState
    let onSubmit: () -> Void

    @State private var showSymbolPicker = false

    var body: some View {
        SearchBarLayout(icon: isAutocompleteLoading ? .progress : .visible) {
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
                if let filter = inputText.toSearchFilter().value {
                    filters.append(filter)
                    inputText = ""
                    inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                }
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
            if !previous.isEmpty && current.isEmpty {
                showSymbolPicker = false
            }

            if Self.didAppend(characterFrom: [" "], to: previous, toCreate: current, withSelection: inputSelection) {
                let partial = PartialSearchFilter.from(inputText)
                if case .name(let isExact, let term) = partial.content, case .bare(let content) = term {
                    inputText = PartialSearchFilter(
                        negated: partial.negated,
                        content: .name(isExact, .unterminated(.doubleQuote, content)),
                    )
                    .description
                    inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                    return
                }
            }

            if Self.didAppend(characterFrom: [" ", "'", "\"", ")", "/"], to: previous, toCreate: current, withSelection: inputSelection) {
                if case .valid(let filter) = inputText.toSearchFilter() {
                    filters.append(filter)
                    inputText = ""
                    inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                }
                return
            }

            if let (newText, newSelection) = removeAutoinsertedWhitespace(current, inputSelection), newText != inputText {
                inputText = newText
                inputSelection = newSelection
                return
            }
        }
        .onChange(of: filters) {
            showSymbolPicker = false
        }
    }

    private static func didAppend(
        characterFrom characters: Set<Character>,
        to previous: String,
        toCreate current: String,
        withSelection selection: TextSelection?,
    ) -> Bool {
        guard current.count > previous.count else {
            return false
        }

        guard let lastCharacter = current.last, characters.contains(lastCharacter) else {
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
