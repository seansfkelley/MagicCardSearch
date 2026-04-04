# Spoilers Tab Redesign

## Phase 1: Set Selector

### Overview

Filter `ScryfallCatalogs.sets` — which is already fetched and cached at startup — to
find currently-spoiling sets, and expose a floating set-selector header above the card
grid that lets users narrow results to a single set or view all spoiling sets at once.

No new dependencies or data fetches are required.

---

### 1. `MTGSet` Extension

`MTGSet.releasedAt` is a `String?` in the same `yyyy-MM-dd` format as `Card.releasedAt`.
Add a `releasedAtAsDate: Date?` extension to `MTGSet` matching the existing one on
`Card` (in `Card+Extensions.swift`):

```swift
extension MTGSet {
    var releasedAtAsDate: Date? {
        guard let releasedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: releasedAt)
    }
}
```

Place this in a new `Extensions/MTGSet+Extensions.swift`.

---

### 2. Spoiling Sets

No new service or model is needed. Store the result as `@State` in `SpoilersView` and
recompute it whenever catalogs refresh. `MTGSet.sets` is `@ObservationIgnored` on
`ScryfallCatalogs`, so views can't observe it directly — use `catalogChangeNonce`
as the trigger instead:

```swift
@State private var spoilingSets: [MTGSet] = []

// called from .task and .onChange(of: scryfallCatalogs.catalogChangeNonce)
private func recomputeSpoilingSets() {
    let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now)!
    spoilingSets = (scryfallCatalogs.sets?.values ?? [])
        .filter { ($0.releasedAtAsDate ?? .distantPast) >= twoWeeksAgo }
        .sorted { ($0.releasedAtAsDate ?? .distantPast) > ($1.releasedAtAsDate ?? .distantPast) }
}
```

This runs at most once per catalog load, not on every render.

---

### 3. Set Selector Header

A new `SpoilersSetSelectorView` rendered above (not inside) the card grid `ScrollView`.

**Layout:**
A horizontally scrolling row of `Capsule`-shaped buttons, each containing:
- An icon on the left
- A label on the right (set code in all-caps)

The first item is **"All Sets"** using the `common` SVG asset and the label "All Sets".

Subsequent items use `SetIconView(setCode: SetCode(set.code), size: 16)` and display
the uppercased set code. Items are ordered by `spoilingSets` (farthest-future first).
Items have the release date as a secondary caption below the set code.

The selected capsule should have a filled/tinted appearance; unselected capsules
should have a secondary/outline style.

---

### 4. Selection State & `@AppStorage`

The selected set code is stored in `@AppStorage("spoilersSelectedSetCode")` as a
`String`. An empty string represents the "all sets" selection.

**Stale-selection guard:** When `spoilingSets` is computed, check whether the stored
set code is present in the result. If not, reset it to `""` (all sets).

---

### 5. Query Construction

Replace the current `SpoilersObjectList.shared` singleton with a per-query approach
modeled after `AllPrintsView`:

- **All sets:** `(set:aaa OR set:bbb OR set:ccc)` enumerating all codes from
  `spoilingSets`. Sort: `order: .spoiled, sortDirection: .desc`.
- **Single set:** `set:aaa`. Sort: `order: .spoiled, sortDirection: .desc`.

Both queries pass `unique: .prints` to match current behavior.

If `spoilingSets` is empty (catalogs still loading), the entire spoilers view should
show a loading spinner.

---

### 6. In-Memory Query Cache

Mirror the `AllPrintsView` pattern:

```swift
private static let objectListCache = StrongMemoryStorage<String, ScryfallObjectList<Card>>(
    config: .init(expiry: .hours(1), countLimit: 50)
)
```

The cache key is the selected set code string (empty = all sets). When `spoilingSets`
changes (catalogs reload), flush this cache so queries rebuild with the updated set list.

---

### 7. `SpoilersView` Layout Changes

Current structure:

```
ZStack
  └── switch(spoilersList.value)
        └── ScrollView > LazyVGrid
```

New structure:

```
ZStack
  └── switch(objectList.value)
        └── ScrollView > LazyVGrid
            .safeAreaInset(edge: .top) {
                SpoilersSetSelectorView + Divider()
                    .background(.systemBackground)
            }
```

`.safeAreaInset` is the correct approach here. The scroll view fills the full height;
its content inset is automatically pushed down to start below the header. As the user
scrolls, cards slide under the header, which covers them with its `systemBackground`
background. A `VStack` would not achieve this — the scroll content would just sit
below the header with no overlap.

---

### 8. Files to Create / Modify

| File | Action |
|------|--------|
| `Extensions/MTGSet+Extensions.swift` | New — `releasedAtAsDate` |
| `Views/SpoilersTab/SpoilersSetSelectorView.swift` | New — header UI |
| `Views/SpoilersTab/SpoilersView.swift` | Modify — add header, replace singleton with dynamic queries, add cache |

---

---

## Phase 2: Sort & Color Filters

### Overview

Add a second floating header beneath the set selector containing:
- A sort-order picker (left side)
- A color filter row (right side)

Both selections are stored in `@AppStorage`, included in the query cache key, and
update the Scryfall query as appropriate.

---

### 1. Sort Order

**Options:**

| Display Name | Subtitle | Scryfall params |
|---|---|---|
| Spoiled Date | Newest First (default) | `order: .spoiled, sortDirection: .desc` |
| Rarity | Rarest First | `order: .rarity, sortDirection: .desc` |

**UI:** An `Image(systemName: "arrow.up.arrow.down")` button that opens a `Menu`
containing an inline `Picker`, matching the pattern in `BookmarkedCardListView`
(`Menu { Picker(.inline) { ... } } label: { Image(...) }`).

**Storage:** `@AppStorage("spoilersSortOrder")` as a `RawRepresentable` `String`
enum (`SpoilersSortOrder`).

---

### 2. Color Filters

**Colors:** `W`, `U`, `B`, `R`, `G`, `C` (colorless) — the six standard mana
symbols rendered via the existing `SymbolView` at an appropriate size (e.g., 22pt).

**UI:** A horizontal row of six tappable `SymbolView` buttons. Each toggles its
selected state. A small `xmark` button at the end clears all selections. When no
colors are selected the filter is inactive and no color constraint is added to the
query.

Selected symbols should have full opacity / a tinted highlight; unselected ones
should be rendered at reduced opacity.

**Scryfall query logic:**

- No colors selected → no color clause
- Only non-colorless colors selected → `color<={WUBRG subset}`, e.g. `color<=WUR`
- Only colorless selected → `color:C`
- Colorless + one or more colors → `(color:C OR color<={colors})`

The color string passed to Scryfall should list the selected colors in WUBRG order
followed by C (if selected), e.g. `color<=WUG` not `color<=GWU`, for predictable
cache keys.

**Storage:** `@AppStorage("spoilersColorFilter")` as a comma-separated `String` of
selected color letters in canonical WUBRGC order (empty = no filter).

---

### 3. Second Floating Header: `SpoilersFilterBarView`

A new view with a single-row `HStack`:

```
[ ↕ sort button ]  [ {W} {U} {B} {R} {G} {C}  ✕ ]
```

- The sort button is on the leading edge.
- The mana symbol row is on the trailing side, right-aligned or using a `Spacer` to
  push it to the right.
- The `✕` clear button is visible only when at least one color is selected.

**Layout in `SpoilersView`:**

```
ZStack
  └── switch(objectList.value)
        └── ScrollView > LazyVGrid
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    SpoilersSetSelectorView
                    SpoilersFilterBarView
                    Divider()
                }
                .background(.systemBackground)
            }
```

Both headers sit inside the `.safeAreaInset` content, sharing a single
`systemBackground` background. The scroll view fills the full height; its
content inset is pushed down to start below both headers. As the user scrolls,
cards slide under the headers.

---

### 4. Cache Key Update

The `StrongMemoryStorage` cache key from Phase 1 (a bare set code `String`) must be
updated to include all three query-determining parameters. Define a `CacheKey` struct:

```swift
struct CacheKey: Hashable {
    let setCode: String          // "" = all sets
    let sortOrder: SpoilersSortOrder
    let colorFilter: String      // canonical WUBRGC order, "" = none
}
```

The `StrongMemoryStorage` becomes `StrongMemoryStorage<CacheKey, ScryfallObjectList<Card>>`.
No other cache changes are needed.

---

### 5. Files to Create / Modify

| File | Action |
|------|--------|
| `Logic/Spoilers/SpoilersSortOrder.swift` | New — enum + Scryfall params |
| `Views/SpoilersTab/SpoilersFilterBarView.swift` | New — second header UI |
| `Views/SpoilersTab/SpoilersView.swift` | Modify — add second header, update cache key |

---

---

## Alternatives Considered

### Data Source for Spoiling Sets

The original design proposed fetching `https://mtgjson.com/api/v5/csv/sets.csv` daily
and parsing it with `CodableCSV` to determine which sets are currently spoiling. This
was superseded when it became clear that `ScryfallCatalogs.sets` already contains the
same information (`MTGSet.releasedAt`) and is already fetched and cached at startup —
making the CSV fetch, the new library dependency, and the intermediate model type all
unnecessary.


