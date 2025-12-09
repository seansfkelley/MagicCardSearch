# Collapsible Search Bar Implementation

## Overview
This document describes the implementation of a collapsible search bar that responds to scroll events in the main results pane. When the user scrolls down, the search bar collapses into a compact horizontal layout. When they scroll back up or reach the top, it expands back to the full interface.

## Implementation Details

### 1. Scroll Tracking (`CardResultsView.swift`)

**Added State Variables:**
- `@Binding var isSearchBarCollapsed: Bool` - Controls collapse state
- `@State private var scrollOffset: CGFloat = 0` - Current scroll position
- `@State private var lastScrollOffset: CGFloat = 0` - Previous scroll position for calculating delta
- `@State private var scrollVelocity: CGFloat = 0` - Scroll velocity for detecting flick gestures

**Scroll Detection:**
- Added `GeometryReader` inside the `ScrollView` to track scroll position
- Created `ScrollOffsetPreferenceKey` to communicate scroll position changes
- Named coordinate space "scroll" for consistent measurements

**Collapse Logic (`handleScrollOffsetChange`):**
- **At top (offset >= 0)**: Always expand
- **Scrolling down (delta < -30)**: Collapse with spring animation
- **Flick scroll up (delta > 50)**: Expand with spring animation
- Does NOT expand on slow upward scroll without release

### 2. State Management (`ContentView.swift`)

**Added State:**
- `@State private var isSearchBarCollapsed = false` - Central collapse state

**Updated Layout:**
- Moved warnings and clear all button into the conditional block that checks `!isSearchBarCollapsed`
- Added `.transition(.move(edge: .bottom).combined(with: .opacity))` for smooth animations
- Passed collapse state and callbacks to `BottomBarFilterView`

**New Callbacks:**
- `onExpandTap`: Expands the search bar when collapsed elements are tapped
- `onClearAll`: Clears all filters and focuses search

### 3. Collapsed UI (`BottomBarFilterView.swift`)

**Updated Structure:**
The view now has two states:

#### Collapsed State (when `isCollapsed && !filters.isEmpty`):
```
[Warning Icon]     [X filters]     [Clear Icon]
   (circular)      (wide capsule)    (circular)
```

- **Warning Button**: Circular button (50x50) with orange warning triangle icon
  - Only visible when `warnings` is not empty
  - Taps call `onExpandTap()`
- **Filter Count**: Wide capsule in center showing "X filters"
  - Taps call `onExpandTap()`
- **Clear All Button**: Circular button (50x50) with red X icon
  - Taps call `onClearAll()`

All elements use `.glassEffect(.regular.interactive())` with appropriate shapes.

#### Expanded State (original layout):
- Full pill list with scroll view
- Complete search bar with magnifying glass and text field
- All original functionality intact

### 4. Transitions

All transitions use:
```swift
.spring(response: 0.3, dampingFraction: 0.8)
```

This creates smooth, natural animations that feel responsive.

## User Experience Flow

1. **Initial State**: Search bar is expanded, showing all filters and search field
2. **User Scrolls Down**: After scrolling down ~30 points, the bar collapses into compact mode
3. **Flick Scroll Up**: Quick upward flick gesture (50+ point delta) expands the bar
4. **Reach Top**: Scrolling to the top (offset >= 0) always expands the bar
5. **Tap Collapsed Elements**: Tapping any of the three collapsed buttons expands the bar
6. **Slow Scroll Up**: Slowly scrolling up without releasing does NOT expand (by design)

## Customization Notes

### Adjusting Sensitivity
To change when the bar collapses/expands, modify these values in `CardResultsView.handleScrollOffsetChange()`:
- `delta < -30` - Make more negative to require more downward scroll before collapsing
- `delta > 50` - Make higher to require faster flick gesture to expand

### Visual Adjustments
In `BottomBarFilterView.swift`:
- Button sizes: `.frame(width: 50, height: 50)` for circular buttons
- Capsule padding: `.padding(.horizontal, 24)` and `.padding(.vertical, 12)`
- Icon sizes: `.font(.system(size: 20))`
- Colors: `.orange` for warnings, `.red` for clear button

## Preview Support

Both `CardResultsView` and `BottomBarFilterView` have updated previews:
- Added `isCollapsed` state variable
- `BottomBarFilterView` preview includes a "Toggle Collapsed" button for testing
- Easy to test both states in Xcode previews

## Future Enhancements

Potential improvements:
1. Add haptic feedback when collapsing/expanding
2. Customize animation curves based on scroll velocity
3. Add preference for users to disable auto-collapse
4. Smooth morphing animation between shapes (requires MatchedGeometryEffect)
5. Support for landscape orientation with adjusted layout
