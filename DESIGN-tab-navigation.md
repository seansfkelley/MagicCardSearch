# Design Document: Tab Bar Navigation Refactor

## 1. Current Architecture Summary

The app currently uses a single-page architecture with:

- **ContentView**: The root view containing a `NavigationStack` that switches between:
  - `HomeView` (sections for spoilers, pinned searches, recent searches, examples)
  - `SearchResultsGridView` (card grid results)
- **SearchSheetView**: A modal sheet for the search interface with autocomplete
- **BookmarkedCardsListView**: A modal sheet for bookmarks
- **FakeSearchBarButtonView**: A persistent bottom button that opens the search sheet and previews the current search, if any

Navigation flow:

1. User starts on `HomeView`
2. Tapping the bottom search bar opens `SearchSheetView` as a sheet
3. Executing a search dismisses the sheet and switches `ContentView` to show `SearchResultsGridView`
4. The header icon button returns to `HomeView`
5. Bookmarks are accessed via a toolbar button that opens a sheet

**Problems with current architecture:**

- Navigation between home/results is implicit and confusing (controlled by state changes, not explicit user action)
- The "search bar" at the bottom is actually a button that opens a sheet, which is non-standard
- Bookmarks are hidden behind a toolbar button
- No dedicated place for "random card" functionality
- Switching between content types requires understanding the app's implicit state machine

## 2. Proposed Architecture

Adopt a standard iOS `TabView` with four tabs:

| Tab       | Icon              | Content                                                   |
| --------- | ----------------- | --------------------------------------------------------- |
| Spoilers  | `sparkles`        | Featured/recent spoiler cards in a grid layout            |
| Bookmarks | `bookmark`        | Bookmarked cards list (current `BookmarkedCardsListView`) |
| Random    | `shuffle`         | Random card display (stub for now)                        |
| Search    | `magnifyingglass` | Search interface with results                             |

## 3. Structural Changes

### 3.1 New File: `MainTabView.swift`

A new root view replacing `ContentView` that contains the `TabView`:

```
MainTabView
├── Tab: Spoilers
│   └── SpoilersView (grid layout with date-based sections)
├── Tab: Bookmarks
│   └── BookmarksTabView (adapted from BookmarkedCardsListView)
├── Tab: Random
│   └── RandomCardView (stub placeholder)
└── Tab: Search
    └── SearchTabView (contains search interface + results)
```

### 3.2 File Changes Summary

| File                            | Action       | Notes                                                             |
| ------------------------------- | ------------ | ----------------------------------------------------------------- |
| `ContentView.swift`             | **Replace**  | Becomes `MainTabView.swift` with TabView structure                |
| `HomeView.swift`                | **Refactor** | Extract spoilers into standalone `SpoilersView.swift`             |
| `BookmarkedCardsListView.swift` | **Adapt**    | Remove sheet-specific UI (dismiss button), make embeddable as tab |
| `SearchSheetView.swift`         | **Refactor** | Becomes `SearchTabView.swift`, integrated with results display    |
| `SearchResultsGridView.swift`   | **Keep**     | No changes, embedded within `SearchTabView`                       |
| `FakeSearchBarButtonView.swift` | **Remove**   | No longer needed                                                  |
| `MagicCardSearchApp.swift`      | **Update**   | Change root view from `ContentView` to `MainTabView`              |

**New files to create:**

- `MainTabView.swift` - Root tab container
- `SpoilersView.swift` - Spoilers tab content (grid with date sections)
- `RandomCardView.swift` - Random card tab content (stub placeholder for now)
- `SearchTabView.swift` - Search tab with integrated results

### 3.3 Search Bar Approach

The Search tab does not use `.searchable`. Instead, `SearchBarAndPillsView` (fused filter pills + `{}` symbol button + text field) is anchored above the tab bar as a persistent fixture whenever the Search tab is active, using `.safeAreaInset(edge: .bottom)`. This preserves all existing behavior: the `{}` button, pill/field fusion in a shared glass container, and autocomplete overlay.

## 4. State Management Changes

### 4.1 SearchState

`SearchState` currently manages:

- `filters` - Current search filters
- `configuration` - Sort/unique settings
- `results` - Search results (`ScryfallObjectList<Card>`)
- `searchNonce` / `clearNonce` - Triggers for navigation and UI state changes

Changes needed:

- **Remove `clearNonce`** - No longer useful; clearing search doesn't navigate anywhere in the tab model
- **Remove `searchNonce`** - Navigation is handled by tabs. For cross-tab search initiation (e.g., tapping a filter pill), the calling code can:
  1. Set `searchState.filters`
  2. Call `searchState.performSearch()`
  3. Set `selectedTab = .search`

  No nonce needed; the tab switch and results update happen through normal state flow.

### 4.2 Tab Selection State

Add tab selection state to `MainTabView`, persisted to `@AppStorage`:

```swift
enum Tab: String {
    case spoilers
    case bookmarks
    case random
    case search
}

@AppStorage("selectedTab") private var selectedTab: Tab = .spoilers
```

### 4.3 Cross-Tab Navigation

Some actions need to navigate to the Search tab and execute a search:

- Tapping a pinned/recent search (from Search tab's default state)
- Filter pill taps from card detail views

This can be handled by:

1. Setting `searchState.filters`
2. Calling `searchState.performSearch()`
3. Setting `selectedTab = .search`

## 5. Views to Extract/Create

### 5.1 SpoilersView

Dedicated tab view for spoiler cards:

- Uses the same gridded layout as `SearchResultsGridView`
- Includes horizontal section breaks based on spoiled date (cards grouped by date)
- Assumes results are provided in reverse chronological order
- Error/loading states

Note: Pinned searches, recent searches, and example searches should NOT appear here. These belong in the Search tab's default (no-search) state.

### 5.2 RandomCardView

Stub placeholder for future work.

### 5.3 SearchTabView

The Search tab is a regular tab — no `.searchable`. The existing `SearchSheetView` content is adapted into a persistent tab view:

```
SearchTabView
├── NavigationStack (body)
│   ├── Text empty, no filters → default content:
│   │   - Pinned searches, recent searches, example searches
│   ├── Text non-empty or filters active → autocomplete suggestions (inline list)
│   └── Search executed → SearchResultsGridView
└── .safeAreaInset(edge: .bottom)
    └── SearchBarAndPillsView (persistent, anchored above tab bar)
        ├── Collapsed: compact single-line bar showing current query or placeholder
        └── Focused: full form — ReflowingFilterPillsView above, text field with {} button below
```

The search bar is always visible above the tab bar when the Search tab is selected. When not focused it shows a collapsed/tappable summary of the current query (or a placeholder if empty). When focused it expands to the full `SearchBarAndPillsView` with pills and the `{}` symbol picker — exactly as it works today.

The main content area (behind the search bar) changes based on state:

```
Text empty AND no filters → pinned searches, recent searches, example searches
Text non-empty OR filters active → autocomplete suggestions (inline, not an overlay)
Search executed → SearchResultsGridView
```

Autocomplete renders into the same scrollable list area as the default content — no overlay. All existing autocomplete behaviors are preserved:

- Pin/unpin and swipe-to-delete on history items
- Custom row views for different suggestion types
- Real-time suggestions as the user types
- `ReflowingFilterPillsView` visible only when filters are non-empty, fused into the same glass container as the text field

### 5.4 BookmarksTabView

Adapted from `BookmarkedCardsListView`:

- Remove dismiss button (not a sheet anymore)
- Keep all existing functionality (sort, edit mode, swipe actions)
- Embed in NavigationStack for card detail navigation

## 6. Migration Path

### Phase 1: Create Tab Structure

1. Create `MainTabView.swift` with basic tab structure
2. Update `MagicCardSearchApp` to use `MainTabView`
3. Embed existing views as tab content (minimal refactoring)

### Phase 2: Refactor Individual Tabs

1. Create `SpoilersView` with grid layout and date-based sections
2. Adapt `BookmarkedCardsListView` for tab embedding
3. Create `RandomCardView` stub placeholder
4. Create `SearchTabView` combining search + results

### Phase 3: Cleanup

1. Remove `HomeView` (functionality distributed to tabs)
2. Remove `FakeSearchBarButtonView`
3. Remove `searchNonce`/`clearNonce` from `SearchState`
4. Remove `ContentView`

## 7. UI/UX Considerations

### 7.1 Preserving Search State

When switching away from and back to the Search tab:

- Keep current search results visible
- Keep filter state intact
- Don't auto-clear on tab switch

### 7.2 Deep Linking from Other Tabs

Actions that should navigate to Search tab:

- Tapping a filter pill on any card detail view
- These should set filters and switch tabs programmatically

### 7.3 Random Card Behavior

Stub placeholder for now.

## 8. Files Summary

### Files to Create

- `Views/MainTabView.swift`
- `Views/Tabs/SpoilersView.swift`
- `Views/Tabs/RandomCardView.swift` (stub)
- `Views/Tabs/SearchTabView.swift`
- `Views/Tabs/BookmarksTabView.swift` (or adapt existing in place)

### Files to Modify

- `MagicCardSearchApp.swift` - Use `MainTabView` as root
- `Logic/ViewModels/SearchState.swift` - Remove `searchNonce`/`clearNonce`

### Files to Remove

- `Views/ContentView.swift`
- `Views/HomeView.swift`
- `Views/SearchBar/FakeSearchBarButtonView.swift`
