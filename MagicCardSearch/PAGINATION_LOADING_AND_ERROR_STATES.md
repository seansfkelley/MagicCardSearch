# Pagination Loading and Error States Implementation

## Overview
Enhanced pagination to include comprehensive loading and error states in both the grid view and card detail navigator. Users now see clear feedback when pages are loading or fail to load, with retry functionality for pagination errors.

## Changes Made

### 1. CardResultsView Updates

#### New State Properties
- **`nextPageError: SearchErrorState?`**: Tracks errors that occur during pagination (separate from initial search errors)

#### Pagination Status View (Grid)
Added a new `paginationStatusView` that appears at the bottom of the scroll view:

**Loading State:**
- Shows a scaled progress indicator
- Displays "Loading more results..." message
- Full-width layout with vertical padding

**Error State:**
- Shows error icon (based on error type)
- Displays error title and description
- Includes a "Retry" button
- Uses same error categorization as main search errors
- Retry button calls `retryNextPage()` instead of restarting search

**Display Logic:**
- Only shows when there's a next page URL, currently loading, or an error
- Replaces the simple progress indicator that was in the grid
- Positioned after the grid with consistent padding

#### Updated `loadNextPageIfNeeded()`
- Now sets `nextPageError` when pagination fails
- Clears `nextPageError` on successful load
- Guards against loading if error is already showing
- Prevents retry loops

#### New `retryNextPage()` Method
- Clears the pagination error state
- Calls `loadNextPageIfNeeded()` to retry
- Separate from main search retry (which resets everything)

#### Sheet Integration
Passes pagination state to `CardDetailNavigator`:
- `totalCount`: For accurate counter display
- `hasMorePages`: Whether there are more pages to load
- `isLoadingNextPage`: Current loading state
- `nextPageError`: Current error state (if any)
- `onNearEnd`: Callback to trigger pagination
- `onRetryNextPage`: Callback to retry failed pagination

### 2. CardDetailNavigator Updates

#### New Properties
- **`totalCount`**: Total result count across all pages
- **`hasMorePages`**: Whether there are more pages to load
- **`isLoadingNextPage`**: Current pagination loading state
- **`nextPageError`**: Current pagination error state
- **`onRetryNextPage`**: Callback to retry failed pagination

#### Pagination Status Page (Swipeable)
Added a full-screen pagination status page that users can swipe to:

**When to Show:**
- Appears as the last page in the horizontal scroll
- Shows when `hasMorePages`, `isLoadingNextPage`, or `nextPageError` is true
- Has a special ID of `-1` to distinguish it from card pages

**Loading State:**
- Large centered progress indicator
- "Loading more cards..." message
- Consistent sizing with card pages

**Error State:**
- Large error icon (50pt)
- Error title (title2, semibold)
- Error description with horizontal padding
- Large "Retry" button with prominent style
- Calls `onRetryNextPage?()` callback

**Fallback:**
- Shows loading state if none of the above conditions match
- Defensive programming for unexpected states

#### Dynamic Navigation Title
- Shows card name when viewing a card
- Shows "Loading..." when on pagination page

#### Enhanced Counter Display
- Shows `"X of Y"` using `totalCount` when available
- Shows `"X of Y"` using `cards.count` as fallback
- Shows "Loading more..." when on pagination page

#### Layout Considerations
- Pagination page uses same geometry as card pages
- Maintains consistent frame sizing
- Centers content vertically and horizontally
- Proper spacing for readability

## User Experience

### Grid View Pagination

#### Success Flow:
1. User scrolls down through results
2. When 4 items from bottom, next page loads automatically
3. "Loading more results..." indicator appears at bottom
4. New results appear seamlessly
5. Indicator disappears

#### Error Flow:
1. User scrolls down through results
2. Pagination fails (network error, server error, etc.)
3. Error card appears at bottom with icon, title, and description
4. User taps "Retry" button
5. Error clears, loading indicator appears
6. If successful, new results appear
7. If failed again, error reappears

### Detail View Pagination

#### Success Flow:
1. User swipes through cards
2. When 3 cards from end, next page loads automatically
3. User can swipe to pagination page showing spinner
4. New cards appear
5. User can continue swiping through them

#### Error Flow:
1. User swipes through cards
2. Pagination fails
3. User can swipe to pagination page showing error
4. Error page shows appropriate icon, title, and description
5. User taps "Retry" button
6. Error page shows loading spinner
7. If successful, card pages appear
8. If failed, error reappears

### Error vs Pagination Error

**Main Search Error (`errorState`):**
- Replaces entire results view
- Occurs during initial search
- Retry button restarts the search from beginning
- Clears all results

**Pagination Error (`nextPageError`):**
- Appears at end of existing results
- Occurs when loading additional pages
- Retry button only retries the next page
- Preserves existing loaded results

## Technical Notes

### State Management
- Pagination error is separate from main search error
- Errors are cleared before retry attempts
- Guards prevent multiple simultaneous page loads
- Loading states prevent duplicate requests

### Error Propagation
- Uses existing `SearchErrorState` enum
- Categorizes errors (4xx, 5xx, other)
- Provides contextual messages
- Maintains consistent error UI

### Performance Considerations
- Lazy loading prevents loading all pages at once
- Error states don't block main UI
- Pagination happens in background tasks
- User can continue viewing loaded results even with errors

### Edge Cases Handled
- No more pages: indicators hidden
- Already loading: duplicate requests prevented
- Error showing: prevents new load attempts until retry
- Empty results with error: appropriate state shown
- Navigation title/counter: handles pagination page gracefully

## Benefits

1. **Clear Feedback**: Users always know what's happening with pagination
2. **Graceful Degradation**: Errors don't lose loaded results
3. **Easy Recovery**: One-tap retry for failed pagination
4. **Consistent UX**: Same error handling patterns across views
5. **Visual Continuity**: Pagination states match overall app design
6. **Accessibility**: Clear text and icons describe states
7. **Defensive**: Handles unexpected states gracefully
