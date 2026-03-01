# Design Document: Random Card View

## Overview

`RandomCardView` is the content for the Random tab in `MainTabView`. It displays a continuous stream of random cards the user can swipe through, with optional filters to constrain what cards appear.

## LazyPagingDetailNavigator Refactor

Two small changes to `LazyPagingDetailNavigator` are needed before it can support random cards.

### 1. Configurable bottom content

Replace the hardcoded counter pill `.safeAreaInset` block with a generic, nilable `BottomContent: View` parameter:

```swift
struct LazyPagingDetailNavigator<..., BottomContent: View>: View {
    let bottomContent?: (_ currentIndex: Int, _ totalCount: Int) -> BottomContent?
}
```

Existing search callers pass the current "X of Y" pill. `RandomCardView` passes "X of Y in session". This permits removing the totalCount property too. If the callback or its result is nil, nothing is shown.

### 2. Clamp currentIndex when items shrinks

`currentIndex` is internal `@State`. If `items` shrinks (e.g. when filters are applied and history is truncated), `currentIndex` can become out of bounds. Add an `onChange(of: items.count)` handler that clamps both `currentIndex` and `scrollPosition`:

```swift
.onChange(of: items.count) { _, newCount in
    if currentIndex >= newCount {
        currentIndex = max(0, newCount - 1)
        scrollPosition = currentIndex
    }
}
```

## Card Display

`Card` already conforms to `Nameable` and `Identifiable`, so it serves as both `ItemReference` and `Item`. The `loader` is an identity closure since the full card is already in hand:

```swift
LazyPagingDetailNavigator(
    items: history,
    initialIndex: 0,
    totalCount: history.count,
    hasMorePages: true,
    isLoadingNextPage: isLoadingNext,
    nextPageError: loadError.map { SearchErrorState(error: $0) },
    loader: { card in card },
    loadDistance: 1,
    onNearEnd: fetchNextCard,
    onRetryNextPage: fetchNextCard
) { card in
    CardDetailView(card: card)
} toolbarContent: { card in
    // bookmark + share + filters toolbar items
} bottomContent: { index, total in
    Text("\(index + 1) of \(total) in session")
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, 20)
}
```

`onNearEnd` fires when the user is within `loadDistance` cards of the end, triggering a fetch appended to `history`. `LazyPagingDetailNavigator` handles the loading placeholder page and error/retry UI.

State in `RandomCardView`:

```swift
@State private var history: [Card] = []
@State private var isLoadingNext: Bool = false
@State private var loadError: Error? = nil
@State private var filters = RandomCardFilters()
```

On `onAppear`, call `fetchNextCard()` to populate the first card.

## Navigation Bar

- Title: current card name (from `LazyPagingDetailNavigator`'s existing `navigationTitle`)
- Leading toolbar (via `toolbarContent` closure):
  - Filters button (`line.3.horizontal.decrease.circle`) → opens filter sheet
- Trailing toolbar (via `toolbarContent` closure):
  - Bookmark toggle (same pattern as `SearchResultsDetailNavigator`)
  - Share button (same pattern as `SearchResultsDetailNavigator`)

## Filter Sheet

Presented as a `.sheet`. Header: X (cancel) top-left, checkmark (apply) top-right.

For each filter type, if none are selected, no filtering is applied for that type.

Content sections (top to bottom):

1. **Color** — horizontal row of tappable mana icons for W, U, B, R, G, C. Uses existing `Card.Color` cases and color assets. Label below: "Show cards containing any of these colors." Below and attached in the same section, a Switch labeled "Color identity" which filters using Scryfall `id` instead of `color`.
2. **Format** — multi-select inline chips, one per `Format` case using `Format.label`. Above the fold show Standard, Modern, Legacy, Commander. Have an expandable arrow to show below the fold, which includes all the others. Label below: "Show cards legal in any of these formats." If anything below the fold is enabled, it starts expanded.
3. **Type** — multi-select inline chips for card types. Label below: "Show cards matching any of these types." Above the fold, show Artifact, Creature, Enchantment, Instant, Land, Planeswalker, Sorcery.
4. **Rarity** — multi-select inline chips for Common, Uncommon, Rare, Mythic, Special, Bonus using `Card.Rarity` cases. Label below: "Show cards matching any of these rarities."
5. **Reset to defaults** -- button to reset all filters to empty, that is, their most permissive.

Filter state:

```swift
struct RandomCardFilters {
    var colors: Set<Card.Color> = []
    var formats: Set<Format> = []
    var types: Set<String> = []
    var rarities: Set<Card.Rarity> = []
}
```

Not persisted.

## Query String Construction

`RandomCardFilters` builds a Scryfall `q` string:

- Colors: each active color as `c:X` joined with `OR`, wrapped in parens: `(c:w OR c:u)`
- Formats: `(f:modern OR f:legacy)` etc.
- Supertypes: `(t:legendary OR t:basic)` etc.
- Rarities: `(r:common OR r:uncommon)` etc.
- All active filter groups joined with a space (AND)

## Filter Accept Behavior

When user taps the checkmark:

1. Save new filters
2. Dismiss the sheet
3. Truncate `history` to `history[0...currentIndex]` (remove cards to the right that were fetched under old filters)
4. Fetch a new random card with the updated query and append it

The `onChange(of: items.count)` clamp in `LazyPagingDetailNavigator` handles any scroll position fixup if the truncation lands the index out of bounds.

## Data Fetching

Call `ScryfallClient.getRandomCard(query:)` from `ScryfallKit+Async.swift` directly from `RandomCardView`. No separate state class needed.

## UI/UX Notes

- Swiping right always fetches a fresh card; there is no global "end" to the stream.
- History is session-local and not persisted across app launches.
- Changing filters mid-session truncates forward history to avoid showing cards fetched under different criteria.

## Files to Modify

- `Views/LazyPagingDetailNavigator.swift` — add `BottomContent` generic parameter, add `onChange(of: items.count)` clamp

## Files to Create

- `Views/Tabs/RandomCardView.swift`
