# Technical Decisions

## [SQLiteData](https://github.com/pointfreeco/sqlite-data)

A library with SwiftData-like ergonomics for reading and writing, but permitting direct control over the schema and optionally query patterns. Used because, in descending order of priority:

- Hooks into SwiftUI's observable-heavy lifecyling, like SwiftData, but unlike more-raw SQLite libraries (e.g. SQLite.swift), and is similarly easy-to-use for basic data reading/writing.
- Unlike SwiftData, it supports non-View business objects, so things like autocomplete or history state management are first-class participants in the data model.
- I prefer to be in control of the database schema and its migrations, which SwiftData does not permit, in part to preserve options should I change frameworks.
- By being wordier around database interactions, especially writes, it encourages (though does not require) putting those into a management object/class for DRYness/consistency, which is a style I prefer.

I do not like having to use [Dependencies](https://github.com/pointfreeco/swift-dependencies), which introduces initialization complexity, the potential for new types of runtime errors, parallels SwiftUI's "environment" features, and is insufficiently documented, however, this was largely a one-time cost.

## Semi-permanent Scryfall Caches

Magic data doesn't change that often. Initialization will be faster and less network-dependent by caching this data on disk for a long time.

This is implemented via `ScryfallCatalogs`, and whether or not it's cached on disk it introduces a bunch of uncertainty around data availability, which is the unfortunate reality of depending on a remote service for core data access. Autocomplete can gracefully degrade by simply not offering suggestions if there is no data, but the wiring of the singleton data blobs requires more machinery than I'd like, especially around actor isolation and `@MainActor` infection.

### Blob Store Instead of Purpose-built Tables

The semi-permanent cached data is fairly heterogenous, excepting the long list of "catalogs". There is no upside to e.g. a dedicated `sets` table, since I never want to query/mutate/aggregate that data in a SQL-like fashion but rather use it as a key-value store and/or do in-memory searches over the entire data set.

Additionally, a blob store can replace the need for generalized disk caching, such as with loaded SVGs, for which I did not find a promising Swift library. 

## ScryfallKit

This library is thinner than I thought at first. I keep it around mostly because the Scryfall schema doesn't change (or doesn't change in ways that matter to me) very often, so it's convenient that someone else has already written the types.

There have been some mild annoyances beyond the fact that it's slightly out of date, but never enough to effectively copy-paste it into this project and reimplement the networking portion, which is the alternative.

## On-device Name Autocomplete

Scryfall's name-autocomplete API doesn't seem meaningfully better than what I can bang together using a list of strings, and since we Scryfall provides the complete list of card names in the same fashion as other catalogs I need for other purposes, there's no much reason to introduce network latency where not required to implement the feature. 30,000 names is small for pocket supercomputers.

## Home-rolled `NSCache` Wrapper (`MemoryCache`)

It was simple enough, and I wasn't able to find any promising caching libraries that had the features I actually needed. Most were focused on things like fine-tuned eviction rules but didn't provide complexities I would actually want (such as get-through-cache while guaranteeing a cache miss would only trigger a single fetch, even if concurrent). 

## `Polarity`

This exists because a bare boolean was ambiguous. The obvious field to use would have been `negated`, since the idiomatic default-false would cover the common case, but this introduced double negatives. A two-valued enumeration avoids all usage-site ambiguity and also makes stringification slightly more elegant, since unlike a boolean it knows how to stringify itself appropriately.

## `FilterQuery` and `[Partial]FilterTerm`

Separating the parsing of the boolean expression query structure from the filter's text simplifies many operations and allows DRYing code. (Some) incomplete boolean expressions can be parsed and suggestions provided for constituent (potentially-incomplete) filters. Code interested in inspecting a potentially-incomplete query term can reuse the code without doing a full parse (and potentially being limited by how tolerant the full parser would have been around incomplete filter terms).

`FilterQuery` is unlike a typical boolean query language structure because it doesn't bake AND/OR precedence into the type system and permits even more versions of redundant representations than one normally could make with infinitely deep one-term AND/ORs. It also inlines `Polarity` into each enum variant instead of having a dedicated NOT variant. This partially-flattened representation was chosen because it:

- is reasonably ergonomic to write by hand for testing and example-query purposes.
- requires less recursion and type-juggling when pattern-matching to inspect a parsed query.
- permits aggressive flattening of redundant nesting, even down to a single term, which aids database inspection and debugging.
- simplifies the common case of wrapping single-term autocomplete suggestions into a valid query component.
