# Manual Tests

## Autocomplete

Be careful to note trailing whitespace. Vertical pipes represent cursor. Inputs are one character at a time unless "swipe" is specified.

- ` ` (single space): no-op
- `foo:bar `: creates filter, empty search bar
- `foo:/bar baz/`: creates filter, empty search bar
- `(foo bar)`: creates filter, empty search bar
- `type:` then swipe `instant`: search bar has `type:filter|`
- swipe `memory` then swipe `lapse`: search bar has `"memory lapse|"`
- `urza's `: search bar has `"urza's |`
- `"foo bar baz `: search bar has `"foo bar baz ` (unchanged)
