# Error Handling Implementation

## Overview
Added comprehensive error handling to `CardResultsView` to provide clear user feedback when searches fail due to Scryfall API errors or network issues.

## Changes Made

### 1. New State Property
- **`errorState: SearchErrorState?`**: Tracks the current error state, if any

### 2. SearchErrorState Enum
A new private enum that categorizes errors into three types:

#### Error Types
1. **`clientError`** (4xx status codes)
   - Title: "Search Error"
   - Description: "There was a problem with your search. Please check your filters and try again."
   - Icon: `exclamationmark.triangle`
   - Indicates issues with the search query itself

2. **`serverError`** (5xx status codes)
   - Title: "Scryfall is Unavailable"
   - Description: "Scryfall is experiencing issues. Please try again in a moment."
   - Icon: `server.rack`
   - Indicates Scryfall server problems

3. **`other`** (network errors, etc.)
   - Title: "Connection Error"
   - Description: "Unable to connect to Scryfall. Please check your internet connection and try again."
   - Icon: `wifi.slash`
   - Indicates general connectivity issues

### 3. UI Updates

#### Error View Branch
Added a new branch in the main content conditional:
```swift
} else if let error = errorState {
    errorView(for: error)
}
```

This appears after the "Start Your Search" zero state but before the "No Results" state, ensuring errors take priority in the display hierarchy.

#### Error View Builder
New `errorView(for:)` method creates a `ContentUnavailableView` with:
- Dynamic title and icon based on error type
- Contextual description
- "Try Again" button with `.borderedProminent` style
- Button action calls `maybePerformSearch()` to retry

### 4. Error State Management

#### Setting Error State
In `maybePerformSearch()`:
- Clears `errorState` when starting a new search
- Sets `errorState` from caught errors (if not cancelled)
- Uses `SearchErrorState(from:)` initializer to categorize the error

#### Clearing Error State
Error state is cleared when:
- Starting a new search
- Clearing all filters
- Successfully completing a search

### 5. Error State Initialization
The `SearchErrorState` initializer examines errors to determine the correct category:
- Checks if error is `SearchError.httpError`
- Uses status code ranges to categorize:
  - `400..<500` → clientError
  - `500..<600` → serverError
  - Everything else → other
- Falls back to `other` for non-HTTP errors

## User Experience

### Error Display
1. When a search fails, the loading overlay disappears
2. The results area is replaced with an error `ContentUnavailableView`
3. User sees:
   - Appropriate icon for the error type
   - Clear title explaining the issue
   - Helpful description with guidance
   - "Try Again" button to retry

### Retry Behavior
- Tapping "Try Again" reruns the exact same query
- Uses existing `maybePerformSearch()` logic
- Automatically clears error state on retry
- Shows loading overlay while retrying

### Error Priority
The view hierarchy prioritizes states in this order:
1. Zero state (no filters)
2. **Error state** (new)
3. Empty results
4. Results with data

This ensures errors are always visible and actionable.

## Technical Notes

- Errors during pagination (`loadNextPageIfNeeded()`) are logged but don't set error state
  - This prevents disrupting an existing results view
  - User can continue viewing loaded results
- Task cancellation errors are ignored (not shown to user)
- Error categorization is defensive - unknown errors fall back to generic "Connection Error"
- The retry mechanism reuses existing search infrastructure, ensuring consistent behavior
