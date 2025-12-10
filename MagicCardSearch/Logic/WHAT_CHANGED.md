# ScryfallKit Migration - What Changed

A quick reference guide for understanding the changes made during the ScryfallKit migration.

## The Big Picture

**Before**: Custom card models → Manual URLSession calls → Custom decoding
**After**: ScryfallKit Card models → ScryfallClient → Built-in decoding

## Quick Reference: Old vs New

### Card Types

| Old Type | New Type | Notes |
|----------|----------|-------|
| `CardResult` (enum) | `Card` (struct) | Single type, use `card.isDoubleFaced` |
| `RegularCard` | `Card` | Merged into single type |
| `TransformingCard` | `Card` | Use `card.cardFaces` |
| `CardFace` | `Card.Face` | From ScryfallKit |
| `Ruling` | `Card.Ruling` | From ScryfallKit, wrapped in `RulingAdapter` |
| `RelatedPart` | `Card.RelatedCard` | From ScryfallKit, wrapped in `RelatedPartAdapter` |

### Property Name Changes

| Old Property | New Property | Notes |
|--------------|--------------|-------|
| `card.setCode` | `card.set` | Different name |
| `card.scryfallUri` | `card.scryfallURI` | Case change |
| `card.rulingsUri` | `card.rulingsURI` | Case change |
| `card.smallImageUrl` | `card.smallImageURL` | Use extension helper |
| `card.normalImageUrl` | `card.normalImageURL` | Use extension helper |
| `card.largeImageUrl` | `card.largeImageURL` | Use extension helper |

### Type Changes

| Property | Old Type | New Type | Conversion |
|----------|----------|----------|------------|
| `colors` | `[String]?` | `[Card.Color]?` | `.map { $0.rawValue }` |
| `colorIndicator` | `[String]?` | `[Card.Color]?` | `.map { $0.rawValue }` |
| `legalities` | `[String: String]?` | `[String: Card.Legality]?` | Use `.legalitiesDict` extension |
| `rarity` | `String?` | `Card.Rarity?` | Use `.rawValue` |
| `manaCost` (in Face) | `String?` | `String` | Non-optional in ScryfallKit |

### Service Changes

| Service | Old Implementation | New Implementation |
|---------|-------------------|-------------------|
| **CardSearchService** | URLSession → JSON decode | ScryfallClient.searchCards() |
| **RulingsService** | URLSession → JSON decode | ScryfallClient.getRulings() |
| **Card fetching** | Manual URL building | ScryfallClient.getCard() |

### Double-Faced Card Handling

**Old Way** (enum-based):
```swift
switch card {
case .regular(let regularCard):
    // Handle single-faced
case .transforming(let transformingCard):
    let front = transformingCard.frontFace
    let back = transformingCard.backFace
}
```

**New Way** (conditional):
```swift
if card.isDoubleFaced {
    let front = card.frontFace // helper extension
    let back = card.backFace // helper extension
} else {
    // Single-faced card
}
```

### Search Configuration

**Unchanged**: The app still uses its own `SearchConfiguration` with custom enums.

**What's new**: Added conversion methods:
```swift
config.uniqueMode.toScryfallKitUniqueMode() → ScryfallKit.UniqueMode
config.sortField.toScryfallKitSortMode() → ScryfallKit.SortMode?
config.sortOrder.toScryfallKitSortDirection() → ScryfallKit.SortDirection
```

### Favorites/Persistence

**Unchanged**: Still uses `CardListItem` for persistence.

**What's new**: `CardListItem.init(from: Card)` now accepts ScryfallKit's `Card` type.

### SearchFilter

**Unchanged**: The entire Parser directory and `SearchFilter` type remain untouched, as requested.

## Helper Extensions Added

### Card+Extensions.swift

```swift
// Double-faced card helpers
card.isDoubleFaced: Bool
card.frontFace: Card.Face?
card.backFace: Card.Face?

// Display helpers (prefer front face for double-faced)
card.displayManaCost: String?
card.displayTypeLine: String?
card.displayOracleText: String?
card.displayPower: String?
card.displayToughness: String?
card.displayArtist: String?
card.displayColors: [String]?
card.displayColorIndicator: [String]?

// Image URL helpers
card.smallImageURL: String?
card.normalImageURL: String?
card.largeImageURL: String?

// Type conversion
card.legalitiesDict: [String: String]?
```

### Card.Face Extensions

```swift
face.hasPowerToughness: Bool
face.colorsAsStrings: [String]?
face.colorIndicatorAsStrings: [String]?
```

## Adapter Types

### RulingAdapter
Wraps `Card.Ruling` to convert the date string to a `Date` object for display.

### RelatedPartAdapter
Wraps `Card.RelatedCard` to match the expected interface in views.

## Files You Can Remove Later

Once the migration is verified working, these can be removed:
- Most of `CardResult.swift` (keep file for other types if needed, or delete entirely)
  - `enum CardResult`
  - `struct RegularCard`
  - `struct TransformingCard`
  - `struct CardFace`
  - `struct Ruling`
  - `struct RelatedPart`
  - `struct ScryfallSearchResponse`
  - `struct ScryfallRulingsResponse`

## Import Changes

All files that work with `Card` now need:
```swift
import ScryfallKit
```

This includes:
- CardSearchService.swift
- CardResultsView.swift
- CardDetailView.swift
- CardDetailNavigator.swift
- CardListView.swift
- RulingsService.swift
- Card+Extensions.swift
- CardListItem.swift
- ScryfallKitAdapters.swift
- ModelsSearchConfiguration.swift

## What Didn't Change

✅ **Parser** - SearchFilter remains unchanged
✅ **UI** - View structure and layouts are the same
✅ **Persistence** - Still using UserDefaults and JSON encoding
✅ **Search syntax** - Users can still use the same search strings
✅ **Display options** - Sort, filter, and display options unchanged
✅ **Architecture** - MVVM structure maintained

## Common Gotchas

1. **Forgetting to import ScryfallKit** - Causes "Cannot find type 'Card'" errors
2. **Using old property names** - `setCode` vs `set`, `scryfallUri` vs `scryfallURI`
3. **Not converting colors** - `[Card.Color]` needs `.map { $0.rawValue }` for strings
4. **manaCost in Face** - Now non-optional, don't use `if let`
5. **Adapter types** - Remember to wrap `Card.Ruling` and `Card.RelatedCard` in views

## Testing Priority

1. **Critical**: Search functionality
2. **Critical**: Card detail display
3. **Critical**: Favorites persistence
4. **Important**: Double-faced cards
5. **Important**: Pagination
6. **Important**: Rulings
7. **Nice-to-have**: Related cards
8. **Nice-to-have**: All edge cases

## Need Help?

- See **COMPILATION_CHECKLIST.md** for build issues
- See **MIGRATION_NOTES.md** for technical details
- See **MIGRATION_COMPLETE.md** for overview
