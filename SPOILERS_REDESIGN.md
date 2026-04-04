# Spoilers Tab Redesign

## Phase 1: Set Selector

### Overview

Add a daily-cached MTGJSON data feed to determine which sets are currently spoiling,
and expose a floating set-selector header above the card grid that lets users narrow
results to a single set or view all spoiling sets at once.

---

### 1. CSV Library

The URL to fetch is `https://mtgjson.com/api/v5/csv/sets.csv`.

Three viable options — all give named-column access. The parsing code differs slightly.

---

#### Option A: `SwiftCSV` (`https://github.com/swiftcsv/SwiftCSV.git`)

Parses into `[[String: String]]` row dictionaries keyed by header name.
No Codable, minimal API surface.

```swift
import SwiftCSV

// csvString is the raw String from the network response
let csv = try CSV<Named>(string: csvString)
let sets = csv.rows.compactMap { row -> SpoilingSet? in
    guard let code = row["code"],
          let name = row["name"],
          let dateString = row["releaseDate"],
          let date = dateFormatter.date(from: dateString)
    else { return nil }
    return SpoilingSet(code: code, name: name, releaseDate: date)
}
```

---

#### Option B: `yaslab/CSV.swift` (`https://github.com/yaslab/CSV.swift.git`, from `2.5.2`)

Streaming row-by-row API with subscript access by header name.

```swift
import CSV

let reader = try CSVReader(string: csvString, hasHeaderRow: true)
var sets: [SpoilingSet] = []
while reader.next() != nil {
    guard let code = reader["code"],
          let name = reader["name"],
          let dateString = reader["releaseDate"],
          let date = dateFormatter.date(from: dateString)
    else { continue }
    sets.append(SpoilingSet(code: code, name: name, releaseDate: date))
}
```

---

#### Option C: `CodableCSV` (`https://github.com/dehesa/CodableCSV.git`)

Decodes directly into a `Decodable` type using `CSVDecoder`. It supports a
`dateStrategy` configuration property with cases including `.deferredToDate`,
`.iso8601`, `.formatted(DateFormatter)`, and `.custom(...)`.

MTGJSON dates are `yyyy-MM-dd`. While ISO 8601 as a standard supports date-only
strings, CodableCSV's `.iso8601` case hardcodes the format `yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ`
(verified in `sources/Utils.swift`), so it won't parse them. Use `.formatted` instead.

With `dateStrategy` set on the decoder, `releaseDate` can be `Date` directly in
the row struct — no post-hoc string conversion needed:

```swift
import CodableCSV

private struct SetRow: Decodable {
    let code: String
    let name: String
    let releaseDate: Date
}

private let mtgjsonDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

let decoder = CSVDecoder {
    $0.headerStrategy = .firstLine
    $0.dateStrategy = .formatted(mtgjsonDateFormatter)
}
// takes Data (not String), convenient since we cache Data from the network anyway
let sets = try decoder.decode([SetRow].self, from: csvData).map {
    SpoilingSet(code: $0.code, name: $0.name, releaseDate: $0.releaseDate)
}
```

Extra columns in the CSV are ignored — standard `Decodable` behavior. The private
`SetRow` struct is the only extra piece; it could be eliminated if `SpoilingSet`
itself were made `Decodable`, but that's not worth the conformance noise.

---

All three work fine. A and B are more minimal; C is the most idiomatic Swift but
adds a dependency heavier than needed for one small fetch. Pick any.

---

### 2. Data Model: `SpoilingSet`

A lightweight value type that captures only what we need:

```swift
struct SpoilingSet: Identifiable, Hashable {
    let code: String      // lowercased set code, used as `id`
    let name: String      // human-readable set name
    let releaseDate: Date

    var id: String { code }
}
```

---

### 3. Data Layer: `SpoilingSetService`

A new `@MainActor @Observable` singleton responsible for:

1. **Daily-cached fetch** of the MTGJSON CSV  
   Use `bestEffortCache` (memory + disk) with a 1-day expiry, keyed by a fixed
   string such as `"mtgjson-set-decks-csv"`. Cache the raw `Data` from the URL
   response. On app start, check the cache first; fetch from the network only when
   the cache entry is absent or expired.

2. **Parsing** the CSV into `[SpoilingSet]` via `CSVReader<HasHeaderRow>` and
   filtering to sets whose release date is `>= today - 14 days`.

3. **Exposing** a sorted `[SpoilingSet]` property (farthest-in-the-future first,
   then descending by date for already-released sets).

The service should expose a `LoadableResult<[SpoilingSet], Error>` property so
`SpoilersView` can render an appropriate loading/error/empty state.

---

### 4. Set Selector Header

A new `SpoilersSetSelectorView` rendered above (not inside) the card grid `ScrollView`.

**Layout:**  
A horizontally scrolling row of `Capsule`-shaped buttons, each containing:
- An icon on the left
- A label on the right (set code in all-caps)

The first item is **"All Sets"** using the `common` SVG asset (rendered via the
existing `SetIconView`/SVGKit infrastructure or as a simple `Image("common")`
asset reference) and the label "ALL".

Subsequent items use `SetIconView(setCode: SetCode(set.code), size: 16)` and display
the uppercased set code. Items are ordered farthest-in-the-future first, matching
the order exposed by `SpoilingSetService`.

The selected capsule should have a filled/tinted appearance; unselected capsules
should have a secondary/outline style.

---

### 5. Selection State & `@AppStorage`

The selected set code is stored in `@AppStorage("spoilersSelectedSetCode")` as a
`String`. An empty string represents the "all sets" selection.

**Stale-selection guard:** After `SpoilingSetService` finishes loading (or when the
app foregrounds and the service data refreshes), check whether the stored set code
is present in the current `spoilingSets` list. If not, reset the stored value to
`""` (all sets).

---

### 6. Query Construction

Replace the current `SpoilersObjectList.shared` singleton with a per-query approach
modeled after `AllPrintsView`:

- **All sets:** `(set:aaa OR set:bbb OR set:ccc)` where the set codes are taken
  from `SpoilingSetService.spoilingSets`. Sort: `order: .spoiled, sortDirection: .desc`.
  If `spoilingSets` is empty (service still loading or error), fall back to the
  previous `date>=today` query as a temporary measure.
- **Single set:** `set:aaa`. Sort: `order: .spoiled, sortDirection: .desc`.

Both queries should pass `unique: .prints` to match current behavior.

---

### 7. In-Memory Query Cache

Mirror the `AllPrintsView` pattern:

```swift
private static let objectListCache = StrongMemoryStorage<String, ScryfallObjectList<Card>>(
    config: .init(expiry: .hours(1), countLimit: 10)
)
```

The cache key is the selected set code string (empty = all sets). When the selected
set changes, look up the cache first; create and store a new `ScryfallObjectList`
only on a miss. When `SpoilingSetService` refreshes its data (i.e., a new day's
fetch returns different sets), flush this cache entirely so queries are rebuilt with
the updated set list.

---

### 8. `SpoilersView` Layout Changes

Current structure:

```
ZStack
  └── switch(spoilersList.value)
        └── ScrollView > LazyVGrid
```

New structure:

```
VStack(spacing: 0)
  ├── SpoilersSetSelectorView   ← floating header (not in the scroll view)
  └── ZStack
        └── switch(objectList.value)
              └── ScrollView > LazyVGrid
```

The set selector view gets a background matching `systemBackground` and a subtle
bottom separator to visually "float" over the grid.

---

### 9. Files to Create / Modify

| File | Action |
|------|--------|
| `Logic/Spoilers/SpoilingSet.swift` | New — model |
| `Logic/Spoilers/SpoilingSetService.swift` | New — singleton service |
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
VStack(spacing: 0)
  ├── SpoilersSetSelectorView     ← set selector (Phase 1)
  ├── SpoilersFilterBarView       ← sort + color filter (Phase 2)
  └── ZStack
        └── switch(objectList.value)
              └── ScrollView > LazyVGrid
```

Both headers get a `systemBackground` background to cover the grid beneath them
when it scrolls under.

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
