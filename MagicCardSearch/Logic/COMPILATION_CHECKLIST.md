# Compilation Checklist

Run through this checklist to verify the migration is complete and the project builds successfully.

## Pre-Build Verification

- [ ] All new files are added to the Xcode project:
  - [ ] Card+Extensions.swift
  - [ ] CardListItem.swift
  - [ ] ScryfallKitAdapters.swift

- [ ] ScryfallKit module is available:
  - [ ] Check project dependencies/packages
  - [ ] Verify ScryfallKit is linked to target

## Build Issues to Check

### Import Issues
If you see "No such module 'ScryfallKit'":
- Check that ScryfallKit package is properly integrated
- May need to be added as a package dependency if it's a separate SPM package
- Or if it's embedded, check the target membership

### Type Resolution Issues

**Card type not found**:
```swift
// Should be imported in these files:
import ScryfallKit // in CardSearchService.swift
import ScryfallKit // in CardResultsView.swift  
import ScryfallKit // in CardDetailView.swift
import ScryfallKit // in CardDetailNavigator.swift
import ScryfallKit // in CardListView.swift
import ScryfallKit // in Card+Extensions.swift
import ScryfallKit // in ScryfallKitAdapters.swift
import ScryfallKit // in RulingsService.swift
import ScryfallKit // in ModelsSearchConfiguration.swift
import ScryfallKit // in CardListItem.swift
```

### Missing Properties

**Card.set vs Card.setCode**:
- ScryfallKit uses `card.set` (String?)
- Old code used `card.setCode`
- Should be fixed in all views

**Card.scryfallURI vs Card.scryfallUri**:
- ScryfallKit uses `card.scryfallURI`
- Old code used `card.scryfallUri`
- Check CardDetailView toolbar

**Card.rulingsURI vs Card.rulingsUri**:
- ScryfallKit uses `card.rulingsURI`
- Old code used `card.rulingsUri`
- Check CardDetailView

### Color-Related Issues

If you see errors with color indicators:
```swift
// Wrong:
ColorIndicatorView(colors: face.colorIndicator)

// Correct:
ColorIndicatorView(colors: face.colorIndicatorAsStrings)
// or
ColorIndicatorView(colors: face.colorIndicator?.map { $0.rawValue })
```

### Face Property Access

**manaCost differences**:
- `Card.Face.manaCost` is non-optional String in ScryfallKit
- Old `CardFace.manaCost` was optional String?
- Check for unnecessary optional unwrapping

```swift
// Wrong:
if let manaCost = face.manaCost, !manaCost.isEmpty {

// Correct:
if !face.manaCost.isEmpty {
```

### Ruling/RelatedPart Issues

If you see adapter-related errors:
```swift
// For rulings:
let rulingAdapter = RulingAdapter(from: scryfallRuling)

// For related parts:
let relatedPart = RelatedPartAdapter(from: scryfallRelatedCard)
```

## Runtime Issues to Check

### API Response Handling

**ObjectList structure**:
- ScryfallKit returns `ObjectList<Card>` which has:
  - `data: [Card]`
  - `totalCards: Int?`
  - `hasMore: Bool`
  - `nextPage: String?`
  - `warnings: [String]?`

### Display Issues

**Image URLs**:
- Check `card.imageUris?.small`, `?.normal`, `?.large`
- For double-faced cards: `card.cardFaces?.first?.imageUris?.small`
- Extensions should handle this: `card.smallImageURL`, `card.normalImageURL`, etc.

**Rarity display**:
- `card.rarity` is likely an enum
- Use `card.rarity?.rawValue` for string representation

**Language display**:
- `card.lang` should still work
- Check CardSetInfoSection in CardDetailView

## Warnings to Address

### Deprecation Warnings
- Check for any deprecated ScryfallKit APIs
- Update to current versions if needed

### SwiftLint Issues
- File may trigger `file_length` warning (already disabled in CardDetailView)
- Check for other linting issues

## Final Verification

- [ ] Project builds without errors
- [ ] No import warnings
- [ ] No type mismatch errors
- [ ] All Card properties accessible
- [ ] All view files compile
- [ ] Service files compile
- [ ] Model files compile

## Quick Test Build

Try building with:
```bash
# Clean build folder
cmd+shift+K

# Build
cmd+B

# Or from command line:
xcodebuild -scheme YourSchemeName clean build
```

## If Build Fails

1. **Check the error message** - Most issues will be:
   - Missing imports
   - Property name mismatches
   - Type conversion issues

2. **Search for old types** - Make sure no files still reference:
   - `CardResult` (except CardResult.swift itself)
   - `RegularCard`
   - `TransformingCard`
   - Old `CardFace` type
   - Old `Ruling` type
   - Old `RelatedPart` type

3. **Check ScryfallKit integration**:
   - Is the package/module available?
   - Is it properly linked to the app target?
   - Are all source files included?

4. **Verify type conversions**:
   - Colors: `[Card.Color]` → `[String]`
   - Legalities: `[String: Card.Legality]` → `[String: String]`
   - Dates: String → Date conversions

## Success Criteria

✅ Project builds without errors
✅ All imports resolve
✅ All type conversions work
✅ No missing property errors
✅ Ready for runtime testing
