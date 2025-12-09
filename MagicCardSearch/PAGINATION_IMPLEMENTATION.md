# Pagination Implementation Summary

## Overview
Implemented pagination support for card search results according to the Scryfall API List specification. The implementation provides seamless loading of additional results both in the main grid view and while swiping through card details.

## Changes Made

### 1. CardResult.swift
- **Updated `ScryfallSearchResponse`**: Added `nextPage` field to capture the pagination URL from the API response

### 2. CardSearchService.swift
- **Created `SearchResult` struct**: New data structure that bundles cards, total count, and next page URL
- **Refactored `search()` method**: Now returns `SearchResult` instead of just `[CardResult]`
- **Added `fetchNextPage()` method**: Fetches the next page using the provided URL
- **Added `fetchPage()` private helper**: Centralized logic for fetching and decoding paginated responses

### 3. CardResultsView.swift
- **Added state properties**:
  - `totalCount`: Tracks the total number of results across all pages
  - `nextPageURL`: Stores the URL for the next page
  - `isLoadingNextPage`: Tracks loading state for pagination (separate from initial search)
  
- **Updated result count display**: Now shows `totalCount` instead of `results.count`, providing accurate total across all pages

- **Added pagination trigger in grid**:
  - `.onAppear` on each cell checks if we're near the end (4 items from bottom)
  - Calls `loadNextPageIfNeeded()` to fetch next page automatically
  
- **Added loading indicator**: Shows a `ProgressView` at the bottom of the grid when loading the next page

- **Added `loadNextPageIfNeeded()` method**:
  - Guards against concurrent loads and missing next page URL
  - Appends new results to existing results array
  - Updates `nextPageURL` for subsequent pages
  
- **Updated CardDetailNavigator integration**: Passes `onNearEnd` callback to trigger pagination while swiping

### 4. CardDetailNavigator.swift
- **Added `onNearEnd` callback parameter**: Optional closure called when user nears the end of results
- **Added pagination trigger in `onChange(of: scrollPosition)`**: 
  - Detects when user is within 3 items of the end
  - Calls `onNearEnd?()` to trigger next page load

## User Experience

### Main Grid View
1. Initial search shows the first page of results
2. Total result count displays the complete count (e.g., "1,234 results")
3. As user scrolls down, when they get within 4 items of the bottom, the next page loads automatically
4. A progress indicator appears at the bottom while loading
5. New results appear seamlessly appended to the grid

### Detail View Navigation
1. User can swipe through cards horizontally
2. Counter shows current position out of total loaded (e.g., "5 of 1,234")
3. When user gets within 3 cards of the end, next page loads automatically
4. New cards become available to swipe to without interruption
5. Loading happens in the background without blocking navigation

## Technical Notes

- All network operations use Swift Concurrency (async/await)
- Pagination is lazy - only loads when needed
- Guards prevent duplicate page loads
- Original search cancellation logic preserved
- Error handling maintained for both initial search and pagination
- The implementation respects Scryfall's API rate limits by only loading when necessary

## Scryfall API Compliance

The implementation follows the Scryfall List specification:
- Reads `total_cards` for accurate result count
- Checks `has_more` field (implicitly via `next_page` presence)
- Uses `next_page` URL directly without modification
- Maintains all original query parameters through the pagination chain
