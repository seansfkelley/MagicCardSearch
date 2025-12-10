# ScryfallKit Migration Notes

## Overview
This document describes the migration from custom Card models to ScryfallKit's data models and query layer.

## Changes Made

### 1. CardSearchService ✅
- Now uses `ScryfallClient` from ScryfallKit instead of direct URLSession calls
- Uses string-based queries (not ScryfallKit's detailed filter enums) as requested
- Returns ScryfallKit's `Card` type instead of custom `CardResult`
- Maps `SearchConfiguration` enums to ScryfallKit enums

### 2. SearchConfiguration ✅
- Added conversion methods to map to ScryfallKit enums:
  - `UniqueMode.toScryfallKitUniqueMode()` → `ScryfallKit.UniqueMode`
  - `SortField.toScryfallKitSortMode()` → `ScryfallKit.SortMode?`
  - `SortOrder.toScryfallKitSortDirection()` → `ScryfallKit.SortDirection`
- Keeps original enums for UI and persistence (as requested - no ScryfallKit objects persisted)

### 3. CardListItem ✅
- Lightweight, serializable wrapper for favorites persistence
- Extracts only necessary fields from ScryfallKit's `Card`
- Implements `Codable` for JSON persistence
- Handles double-faced cards by preferring front face image

### 4. Parser (Unchanged) ✅
- `SearchFilter` type remains unchanged as requested
- No modifications to Parser directory

### 5. Card+Extensions ✅
- Added helper properties to make ScryfallKit's `Card` easier to work with
- Properties for accessing front/back faces
- Helper properties that automatically prefer front face for double-faced cards
- Color conversion helpers to convert `[Card.Color]` to `[String]`
- Legalities dictionary conversion

### 6. ScryfallKitAdapters ✅
- Created adapter types for `RelatedPart` and `Ruling`
- Bridges between ScryfallKit's types and view expectations
- `RelatedPartAdapter` wraps `Card.RelatedCard`
- `RulingAdapter` wraps `Card.Ruling` and converts date format

### 7. RulingsService ✅
- Updated to use `ScryfallClient.getRulings()` instead of direct URLSession
- Maintains cache for performance
- Supports both card ID and legacy URL-based fetching

### 8. CardResultsView ✅
- Updated to use `Card` instead of `CardResult`
- `CardResultCell` now checks `card.isDoubleFaced` instead of enum cases
- Uses new extension helpers for accessing image URLs

### 9. CardDetailNavigator ✅
- Updated to accept `[Card]` instead of `[CardResult]`
- All type signatures updated

### 10. CardListView ✅
- Updated `CardDetailNavigatorFromList` to load and work with `Card` objects
- Maintains use of `CardListItem` for display

### 11. CardDetailView ✅
- Updated to work with ScryfallKit's `Card` type
- Updated all card face views to use `Card.Face` instead of custom `CardFace`
- Uses adapter types for `RelatedPart` and `Ruling`
- Color handling updated to work with `Card.Color` enum

## Migration Requirements for Views

All views need to be updated to work with ScryfallKit's `Card` instead of `CardResult`.

### Key Differences Between CardResult and ScryfallKit Card:

**Old CardResult:**
- Enum with `.regular` and `.transforming` cases
- Unified interface via computed properties
- Custom handling of double-faced cards

**ScryfallKit Card:**
- Single struct type
- Uses optional `cardFaces` array for double-faced cards
- More comprehensive (includes prices, legalities, etc.)
- Properties may be differently named or structured

### Properties Mapping Guide:

| CardResult Property | ScryfallKit Card Property | Notes |
|-------------------|------------------------|-------|
| `id` | `id` | Same |
| `name` | `name` | Same |
| `manaCost` | `manaCost` | Same |
| `typeLine` | `typeLine` | Same |
| `oracleText` | `oracleText` | Same |
| `power` | `power` | Same |
| `toughness` | `toughness` | Same |
| `smallImageUrl` | `imageUris?.small` | ScryfallKit uses nested struct |
| `normalImageUrl` | `imageUris?.normal` | ScryfallKit uses nested struct |
| `largeImageUrl` | `imageUris?.large` | ScryfallKit uses nested struct |
| `legalities` | `legalities` | May need conversion |
| `setCode` | `set` | Different property name |
| `setName` | `setName` | Same |
| `collectorNumber` | `collectorNumber` | Same |
| `rarity` | `rarity` | May be enum vs string |
| `releasedAt` | `releasedAt` | Same |
| `scryfallUri` | `scryfallURI` | Similar |
| `artist` | `artist` | Same |
| `colors` | `colors` | Same |
| Double-faced cards | `cardFaces` array | Check if `cardFaces` is non-nil/non-empty |

### Files That Need Updates:

1. **CardResultsView.swift** ✅ - Changed `CardResult` to `Card`
2. **CardDetailView.swift** ✅ - Updated to work with `Card` and `card.cardFaces`
3. **CardListView.swift** ✅ - Updated to load full `Card` objects
4. **CardDetailNavigator.swift** ✅ - Updated to use `Card`
5. **RulingsService.swift** ✅ - Updated to use ScryfallKit client
6. **Card+Extensions.swift** ✅ (New) - Helper extensions created
7. **ScryfallKitAdapters.swift** ✅ (New) - Adapter types created
8. **SearchConfiguration.swift** ✅ - Added conversion methods
9. **CardListItem.swift** ✅ (New) - Serializable wrapper created

### Remaining Work:

- **Build and test** - Verify all files compile and imports are correct
- **Remove old types** - Consider deprecating or removing `CardResult`, `RegularCard`, `TransformingCard`, `CardFace`, `Ruling`, `RelatedPart`, `ScryfallSearchResponse`, `ScryfallRulingsResponse` from `CardResult.swift` once migration is verified
- **Check for other references** - Search for any remaining usages of old types in other files not yet examined

### Helper Extensions Needed:

Consider creating extensions on `Card` to simplify view code:
- Helper to get front face properties for double-faced cards
- Helper to get image URLs  with proper fallbacks
- Any other common access patterns

## Testing Checklist

- [ ] Project compiles without errors
- [ ] All imports are correct (ScryfallKit is available)
- [ ] Search returns results
- [ ] Pagination works
- [ ] Card details display correctly
- [ ] Double-faced cards display both faces
- [ ] Double-faced cards flip animation works in grid
- [ ] Favorites can be added/removed
- [ ] Favorites persist across app launches
- [ ] Favorites list displays correctly
- [ ] Tapping favorites loads full card details
- [ ] Search configuration persists
- [ ] Share links work correctly
- [ ] Rulings load correctly
- [ ] Related cards load correctly
- [ ] Color indicators display correctly
- [ ] Legalities display correctly
- [ ] Set information displays correctly
- [ ] Power/toughness displays correctly
- [ ] Artist information displays correctly
- [ ] Oracle text displays correctly
- [ ] Flavor text displays correctly
- [ ] Card images load correctly
- [ ] Image context menus work (share, copy)

## Known Differences & Considerations

### Type Differences

1. **Colors**: ScryfallKit uses `[Card.Color]` enum instead of `[String]`. Extensions added to convert.
2. **Legalities**: ScryfallKit uses `[String: Card.Legality]` instead of `[String: String]`. Extension added to convert.
3. **Rarity**: ScryfallKit likely uses an enum; accessed via `.rawValue` for string representation.
4. **Ruling dates**: ScryfallKit uses `String` for `publishedAt`, old code used `Date`. Adapter converts.
5. **Related cards**: ScryfallKit uses `Card.RelatedCard` instead of custom `RelatedPart`. Adapter created.

### API Changes

1. **ScryfallClient** is async/await based (good match for existing code)
2. **Network logging** can be configured with `networkLogLevel` parameter
3. **Pagination** handled by parsing `nextPage` URL parameter (ScryfallKit doesn't have direct URL fetch)

### SearchConfiguration Mapping

- Most sort fields map directly to ScryfallKit's `SortMode`
- `review` sort mode not supported by ScryfallKit (will use default)
- All unique modes map directly
- All sort directions map directly

### Persistence

- `CardListItem` continues to be used for favorites (no ScryfallKit objects persisted)
- `SearchConfiguration` continues to use its own enums (no ScryfallKit enums persisted)
- Only card IDs are stored, full cards are fetched on demand

### Migration Path

The old `CardResult.swift` file with custom types (`CardResult`, `RegularCard`, `TransformingCard`, `CardFace`, etc.) can be removed once migration is verified. These types have been completely replaced by:
- `Card` from ScryfallKit
- `Card.Face` from ScryfallKit  
- `Card.Ruling` from ScryfallKit (with adapter)
- `Card.RelatedCard` from ScryfallKit (with adapter)
- `CardListItem` for persistence
