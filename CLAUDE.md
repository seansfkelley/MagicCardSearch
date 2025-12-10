# MagicCardSearch

This is an iOS app for searching the library of Magic: The Gathering ("MTG" or "Magic") cards using the Scryfall API.

## App Features

- The entire app is heavily focused on search, with robust and ergonomic autocomplete behaviors.
- Scryfall's query language is baked into the core UI of the app; this is a power-user tool and does not include guided "advanced search" features.
- There are simple "favoriting" features for basic list management.
- Fluid navigation is a must; most interactions are scroll and swipe, and navigation must be easily dismissed/backtracked.
- Most views include a share button to enable easy sharing of state with other apps or people.

## Code Layout

- `Logic/` -- API layer code and shared data models
- `Views/` -- most of the code for the app, which is UI, organized in subdirectories according to where in the app it appears
- `Parser/` -- a basic implementation of the Scryfall query syntax using the Citron parser generator (https://roopc.net/citron/)

## Scryfall

- Scryfall is an advanced MTG search engine with a robust query language.  
- The API documentation can be found at https://scryfall.com/docs/api.

## Tools

- Run SwiftLint after your changes and ensure they adhere to the style.
