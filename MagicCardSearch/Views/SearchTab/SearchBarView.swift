import SwiftUI
import OSLog
import FocusOnAppear
import SwiftUIIntrospect

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchBarView")

struct SearchBarView: View {
    @Binding var searchState: SearchState

    @FocusState private var fieldFocused: Bool
    @State private var showSymbolPicker = false
    private let textFieldDelegate: SearchTextFieldDelegate

    init(searchState: Binding<SearchState>) {
        self._searchState = searchState

        // The only reason this is here is because UITextField.delegate is weak, so we need to
        // retain it as long as this view is alive.
        self.textFieldDelegate = SearchTextFieldDelegate(
            onReturn: {
                if let filter = searchState.wrappedValue.searchText.toFilter().value {
                    searchState.wrappedValue.filters.append(filter)
                    searchState.wrappedValue.searchText = ""
                    searchState.wrappedValue.desiredSearchSelection = nil
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
        SearchBarLayout {
            TextField(
                searchState.filters.isEmpty ? "Search for cards..." : "Add filters...",
                text: $searchState.searchText,
                selection: $searchState.desiredSearchSelection,
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
            .focused($fieldFocused)
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
                    searchState.desiredSearchSelection = nil
                    fieldFocused = true
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
                SymbolPickerGridView { insertSymbol($0) }
                    .presentationCompactAdaptation(.popover)
            }
        }
        .onChange(of: searchState.searchText) { previous, current in
            if !previous.isEmpty && current.isEmpty {
                showSymbolPicker = false
            }

            if let (filter, newText, newSelection) = maybeAutoUpdateSearchText(previous: previous, current: current, selection: searchState.actualSearchSelection) {
                if let filter {
                    searchState.filters.append(filter)
                }
                searchState.searchText = newText
                searchState.desiredSearchSelection = newSelection.map { TextSelection(range: $0) }
            }
        }
        .onChange(of: searchState.filters) {
            showSymbolPicker = false
        }
        .onChange(of: searchState.desiredSearchSelection) {
            // Once it's passed in one time, nil it out so next time it'll take effect again. I
            // didn't 100% test that this was necessary, but it does work as written and I spent way
            // too long fucking about with selection so I left it as-is.
            searchState.desiredSearchSelection = nil
        }
    }

    private func insertSymbol(_ symbol: SymbolCode) {
        searchState.searchText.replaceSubrange(searchState.actualSearchSelection, with: symbol.rawValue)
        let index = searchState.searchText.index(searchState.actualSearchSelection.lowerBound, offsetBy: symbol.rawValue.count)
        searchState.desiredSearchSelection = .init(insertionPoint: index)
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

        logger.trace("updating SwiftUI with selection=\(newSelection)")
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

// MARK: - Preview

#Preview {
    PreviewContainer { searchState in
        SearchBarView(searchState: searchState)
            .padding()
    }
}
