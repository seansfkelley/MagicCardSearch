# Plan: Draft Editing State for Search Sheet

## Context

Currently, `SearchState` is a single `@Observable` class holding both high-frequency editing state (text, cursor, working filters) and committed search state (results, configuration, nonce). The search sheet mutates `SearchState` directly, meaning filter edits are immediately visible everywhere and dismissing the sheet cannot revert changes.

This refactor introduces `SearchEditingState` — a separate `@Observable` class for the sheet's draft state. The sheet operates on a snapshot; changes only commit to `SearchState` on explicit search. Dismissing discards the draft silently.

## New File

### `MagicCardSearch/Logic/ViewModels/SearchEditingState.swift`

New `@MainActor @Observable` class holding all editing-related state extracted from `SearchState`:

- `searchText: String` (with `didSet` invalidating `cachedSelectedFilter`)
- `desiredSearchSelection: TextSelection?`
- `actualSearchSelection: Range<String.Index>` (with `didSet` invalidating `cachedSelectedFilter`)
- `filters: [FilterQuery<FilterTerm>]` — working copy, initialized from committed filters
- `selectedFilter: CurrentlyHighlightedFilterFacade` — computed/cached, same logic as current `SearchState`
- `getSuggestions() async throws -> [AutocompleteSuggestion]` — delegates to `suggestionProvider`
- `clearAll()` — clears `searchText`, `desiredSearchSelection`, and `filters` only

Init takes `filters: [FilterQuery<FilterTerm>]` and `suggestionProvider: AutocompleteSuggestionProvider`.

## Modified Files

### 1. `SearchState.swift` — Remove editing state, add factory

**Remove:** `searchText`, `desiredSearchSelection`, `actualSearchSelection`, `cachedSelectedFilter`, `selectedFilter`, `getSuggestions()`

**Add:**
```swift
func makeEditingState() -> SearchEditingState {
    SearchEditingState(filters: filters, suggestionProvider: suggestionProvider)
}
```

**Modify `clearAll()`** to only clear committed state:
```swift
func clearAll() {
    filters = []
    results = nil
}
```

Everything else (`filters`, `configuration`, `results`, `searchNonce`, `performSearch()`, `clearWarnings()`) stays unchanged.

### 2. `SearchTabView.swift` — Sheet lifecycle coordinator

**Add:** `@State private var editingState: SearchEditingState?`

**Sheet open:** Create editing state when `showSearchSheet` becomes true:
```swift
.onChange(of: showSearchSheet) { _, isShowing in
    if isShowing {
        editingState = searchState.makeEditingState()
    }
}
```

**Sheet dismiss:** Nil out on dismiss (discards draft):
```swift
.sheet(isPresented: $showSearchSheet, onDismiss: { editingState = nil }) {
    if let editingState {
        NavigationStack {
            SearchSheetView(
                editingState: editingState,
                warnings: searchState.results?.value.latestValue?.warnings ?? [],
                onSearch: commitSearch
            )
        }
    }
}
```

**Commit function:** Copies draft filters to committed state and searches:
```swift
private func commitSearch() {
    guard let editingState else { return }
    if let filter = PartialFilterQuery.from(
        editingState.searchText, autoclosePairedDelimiters: true
    ).value?.transformLeaves(using: FilterTerm.from) {
        editingState.filters.append(filter)
    }
    searchState.filters = editingState.filters
    searchState.performSearch()
    showSearchSheet = false
}
```

**Remove:** `.onChange(of: searchState.searchNonce) { showSearchSheet = false }` — sheet dismissal is now explicit in `commitSearch()`.

### 3. `SearchSheetView.swift` — Change interface

Replace `@Binding var searchState: SearchState` with:
```swift
let editingState: SearchEditingState
let warnings: [String]
let onSearch: () -> Void
```

Pass these through to `AutocompleteView` and `SearchBarAndPillsView`.

### 4. `AutocompleteView.swift` — Use editing state

Replace `@Binding var searchState: SearchState` with:
```swift
var editingState: SearchEditingState
var onSearch: () -> Void
```

All `searchState.*` references become `editingState.*`.

**Keep** the `.name` suggestion immediate-search behavior — `filterRow` still calls `onSearch()` when `shouldSearchImmediately` is true:
```swift
let shouldSearchImmediately = suggestion.source == .name && editingState.selectedFilter.scopedRange == nil

// In the onTap:
if addFilter(filter) == .filter && shouldSearchImmediately {
    onSearch()
}
```

The `addFilter` and `setFilterString` methods change `searchState` references to `editingState`.

The `scopedRange` extension on `CurrentlyHighlightedFilterFacade` stays as-is (private to this file).

### 5. `SearchBarAndPillsView.swift` — Use editing state + warnings parameter

Replace `@Binding var searchState: SearchState` with:
```swift
var editingState: SearchEditingState
let warnings: [String]
let onSearch: () -> Void
```

- `searchState.results?.value.latestValue?.warnings ?? []` → `warnings`
- `searchState.filters` → `editingState.filters`
- `searchState.clearAll` → `editingState.clearAll`
- `onFilterEdit` / `onFilterRemove` use `editingState`
- Pass `editingState` and `onSearch` to `SearchBarView`

### 6. `SearchBarView.swift` — Use editing state

Replace `@Binding var searchState: SearchState` with:
```swift
@Bindable var editingState: SearchEditingState
let onSearch: () -> Void
```

**Init:** `SearchTextFieldDelegate` captures `editingState` (reference type) directly in closures. The `actualSelection` binding uses `Binding(get:set:)`:
```swift
self.textFieldDelegate = SearchTextFieldDelegate(
    onReturn: {
        if let filter = PartialFilterQuery.from(editingState.searchText, ...)... {
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
```

**Body:** Use `$editingState.searchText` and `$editingState.desiredSearchSelection` for `TextField` bindings (enabled by `@Bindable`). All other `searchState` references become `editingState`.

### 7. `FilterRowView.swift` — Keep `showImmediateSearchIcon`

No change needed. It's already a dumb display parameter controlled by `AutocompleteView`.

### 8. `PreviewContainer.swift` — Add editing state support

Add a convenience method or overload so sheet-internal view previews can get a `SearchEditingState`. Alternatively, update individual `#Preview` blocks in affected files to construct `SearchEditingState` directly. The existing `PreviewContainer` stays unchanged for non-sheet views.

## Files NOT Changed

These views use `SearchState` directly for committed state and are unaffected:
- `ContentView.swift`
- `FakeSearchBarButtonView.swift`
- `SearchLandingView.swift`
- `AllSearchHistoryView.swift`
- `SearchResultsGridView.swift`
- `ScryfallTagsCardSection.swift`

## Implementation Order

1. Create `SearchEditingState.swift`
2. Add `makeEditingState()` to `SearchState`
3. Remove editing properties from `SearchState`, modify `clearAll()`
4. Update `SearchBarView` (most complex — delegate init rewiring)
5. Update `SearchBarAndPillsView`
6. Update `AutocompleteView`
7. Update `SearchSheetView`
8. Update `SearchTabView` (sheet lifecycle)
9. Fix previews
10. Build + lint

## Verification

- Build the project and confirm no errors
- Open search sheet, add filter pills, dismiss with X → filters revert, results unchanged
- Open search sheet, add filters, press Return → search executes, sheet dismisses, results appear
- Tap a `.name` suggestion → still immediately commits and searches
- "Clear all" inside the sheet → clears draft only, does not affect committed results
- "Clear all" on FakeSearchBar → clears committed state, opens fresh sheet
- Pinned/history/example searches on landing view → still work (bypass sheet entirely)
- Tag searches from card detail → still work
- Display options change → still re-searches correctly
