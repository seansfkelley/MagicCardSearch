import SwiftUI
import OSLog
import FocusOnAppear
import SwiftUIIntrospect

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchBarView")

struct SearchBarView: View {
    @Bindable var editingState: SearchEditingState
    let onSearch: () -> Void
    var isFocused: FocusState<Bool>.Binding

    @State private var showSymbolPicker = false
    private let textFieldDelegate: SearchTextFieldDelegate

    init(editingState: SearchEditingState, onSearch: @escaping () -> Void, isFocused: FocusState<Bool>.Binding) {
        self._editingState = Bindable(wrappedValue: editingState)
        self.onSearch = onSearch
        self.isFocused = isFocused

        // The only reason this is here is because UITextField.delegate is weak, so we need to
        // retain it as long as this view is alive.
        self.textFieldDelegate = SearchTextFieldDelegate(
            onReturn: {
                if let filter = PartialFilterQuery.from(editingState.searchText, autoclosePairedDelimiters: true).value?.transformLeaves(using: FilterTerm.from) {
                    editingState.filters.append(filter)
                    editingState.searchText = ""
                    editingState.desiredSearchSelection = nil
                    return false
                } else {
                    onSearch()
                    return true
                }
            },
            onAddFilter: { editingState.filters.append($0) },
            actualSelection: Binding(
                get: { editingState.actualSearchSelection },
                set: { editingState.actualSearchSelection = $0 }
            ),
        )
    }

    var body: some View {
        SearchBarLayout {
            TextField(
                editingState.filters.isEmpty ? "Search for cards..." : "Add filters...",
                text: $editingState.searchText,
                selection: $editingState.desiredSearchSelection,
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
            .focused(isFocused)
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

            if !editingState.searchText.isEmpty {
                Button(action: {
                    editingState.searchText = ""
                    editingState.desiredSearchSelection = nil
                    isFocused.wrappedValue = true
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
        .onChange(of: editingState.filters) {
            showSymbolPicker = false
        }
        .onChange(of: editingState.desiredSearchSelection) {
            // Once it's passed in one time, nil it out:
            //
            // - this makes it "imperative" which is the current desired behavior
            // - this allows the field to change selection on its own in the (few?) cases where
            //   it does actually stay locked to the binding
            //
            // The async is to give it a chance to take effect in the cases where focus and
            // selection are set simultaneously -- without this, it would focus but not select. This
            // used to happen when tapping a pill to edit it on an unfocused search bar.
            DispatchQueue.main.async {
                editingState.desiredSearchSelection = nil
            }
        }
    }

    private func insertSymbol(_ symbol: SymbolCode) {
        editingState.searchText.replaceSubrange(editingState.actualSearchSelection, with: symbol.rawValue)
        let index = editingState.searchText.index(editingState.actualSearchSelection.lowerBound, offsetBy: symbol.rawValue.count)
        editingState.desiredSearchSelection = .init(insertionPoint: index)
    }
}

// MARK: - UITextField Delegate

private class SearchTextFieldDelegate: NSObject, UITextFieldDelegate {
    let onReturn: () -> Bool
    let onAddFilter: (FilterQuery<FilterTerm>) -> Void
    let actualSelection: Binding<Range<String.Index>>

    init(
        onReturn: @escaping () -> Bool,
        onAddFilter: @escaping (FilterQuery<FilterTerm>) -> Void,
        actualSelection: Binding<Range<String.Index>>
    ) {
        self.onReturn = onReturn
        self.onAddFilter = onAddFilter
        self.actualSelection = actualSelection
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersInRanges ranges: [NSValue], replacementString string: String) -> Bool {
        // We shouldn't get multiple ranges ever, but in case we do, this whole block is a
        // best-effort anyway so we can just ignore it and hope for the best for the user.
        guard ranges.count == 1, let range = ranges.first as? NSRange else {
            logger.warning("got update with count=\(ranges.count) ranges, expected 1")
            return true
        }

        // This is how deletion is represented. Always allowed; cannot trigger any special action.
        guard !string.isEmpty else { return true }

        guard let swiftRange = Range(range, in: textField.text ?? "") else {
            logger.warning("failed to convert NSRange range=\(range) to Swift Range")
            return true
        }

        guard let textRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument) else {
            logger.warning("unexpectedly failed to get text range spanning entire UITextField")
            return true
        }

        guard let textChange = processSearchTextEdit(textField.text ?? "", inserting: string, inRange: swiftRange) else { return true }

        logger.debug("replacing current=\"\(textField.text ?? "")\" with new=\"\(textChange.newText)\" and returning false")
        textField.replace(textRange, withText: textChange.newText)
        if let selection = textChange.newSelection {
            if let uiTextRange = UITextRange.from(selection, in: textField) {
                textField.selectedTextRange = uiTextRange
            } else {
                logger.warning("failed to synthesize a UITextRange from range=\(selection)")
            }
        }
        if let filter = textChange.filter {
            logger.debug("auto-inserting filter=\(filter)")
            onAddFilter(filter)
        }

        return false
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

private extension UITextRange {
    static func from(_ range: Range<String.Index>, in textField: UITextField) -> UITextRange? {
        guard let text = textField.text else { return nil }

        let utf16 = text.utf16
        let startOffset = utf16.distance(from: utf16.startIndex, to: range.lowerBound.samePosition(in: utf16)!)
        let endOffset = utf16.distance(from: utf16.startIndex, to: range.upperBound.samePosition(in: utf16)!)

        guard let start = textField.position(from: textField.beginningOfDocument, offset: startOffset),
              let end = textField.position(from: textField.beginningOfDocument, offset: endOffset) else {
            return nil
        }

        return textField.textRange(from: start, to: end)
    }
}

// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @FocusState var focused: Bool
        var editingState: SearchEditingState
        var body: some View {
            SearchBarView(editingState: editingState, onSearch: {}, isFocused: $focused)
                .padding()
        }
    }

    return PreviewContainer { searchState in
        Wrapper(editingState: searchState.wrappedValue.makeEditingState())
    }
}
