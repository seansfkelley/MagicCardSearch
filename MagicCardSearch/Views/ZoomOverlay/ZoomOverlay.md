# Zoom Overlay

An overlay that lets users pinch-zoom any image seamlessly into a lightbox covering the entire app, without requiring a first tap to get into the lightbox (as is common in iOS). The overlay lives in a dedicated `UIWindow` above all other UI, including sheets.

## State and Lifecycle

`ZoomOverlayState` is the shared mutable core: it holds the zoomable image, source frame, etc., and owns all the transition logic (commit, dismiss, rubber-band, etc.). Neither gesture view contains decision-making logic — they translate raw recognizer events into state mutations and method calls.

`ZoomOverlayInstaller` places a `ZoomOverlayFloatingView` in a dedicated `UIWindow` above all other UI at app startup. This is what makes the overlay appear above sheets and other presentations. The window's interaction is disabled during the initiating phase so touches reach the app content underneath, then enabled once the floating phase takes over.

### Gesture Phases

**Initiating phase** (`isInitiatingGesture == true`): The overlay window has `isUserInteractionEnabled = false`. The source view's `ZoomOverlayInitiatingGestureView` drives the transform directly. The source view is hidden (opacity 0) without any transition and the overlay image is positioned at the same screen location, making it appear seamless. The initiating gesture is allowed to continue uninterrupted.

**Floating phase** (`isInitiatingGesture == false`, `isVisible == true`): When the initiating gesture ends, `ZoomOverlayFloatingView` is allowed to interact and receives all further gestures via `ZoomOverlayFloatingGestureView`.

## Key Views and Methods

### `View.zoomOverlay`

The public API. Apply `.zoomOverlay(for:)` to any view to make it zoomable. The modifier hides the source view while the overlay is showing the given image (identity comparison on the `UIImage` instance), so there's no visual doubling. This relies on the image having a stable identity once non-nil. It can be applied to any view, but the overlay content must be an image.

### `ZoomOverlayInstaller`

Called once at app startup (from the scene delegate or equivalent). Creates a `UIWindow` at level `.alert + 1` and hosts `ZoomOverlayFloatingView` in it. The window's `isUserInteractionEnabled` is toggled via a Combine sink on `ZoomOverlayState` so that touches pass through during the initiating phase and are captured only once the overlay owns the gesture.

### `ZoomOverlayState`

The single source of truth. A `@MainActor` singleton (`ObservableObject`) that holds all display state. Both gesture phases read and write this directly.

Key methods:

- `show` sets up state for the given originating view and seamlessly transitions to the overlay view.
- `maybeCommitInitiatingGesture` is called when the initiating gesture ends and decides whether to revert (auto-dismiss) or to continue (and enable the overlay's interactions). 
- `dismiss` (and overloads) animates seamlessly back to the originating view's position, then shows it.
- `snapTo*Bounds` animates the overlay back to the configured bounds. 

### `ZoomOverlayInitiatingGestureView`

A transparent `UIViewRepresentable` overlay on the source view. Handles the gesture that initiates the zoom. Three recognizers:

- **Pinch** presents the overlay on `.began`, drives `scale`/`offset` via centroid math on `.changed`, calls `maybeCommitInitiatingGesture` on `.ended`.
- **Pan** (2-finger, requires pinch to be active) tracks finger drift during a pinch so the image follows the centroid. Never recognizes on its own, which would be pointless (since there would be no zoom) and would interfere with any containing scroll view.
- **Tap** presents the overlay centered on screen with an animation. Suppressed if a parent scroll view is decelerating or out-of-bounds (bounce), to avoid triggering on scroll-stopping taps.

The pan recognizer's sole job is to contribute translation during a simultaneous pinch. It is prevented from recognizing independently via `gestureRecognizerShouldBegin`.

### `ZoomOverlayFloatingGestureView`

The UIKit gesture layer for the floating phase. Three recognizers:

- **Pinch** re-zooms the image with centroid tracking and scale rubber-banding.
- **Pan** pans with rubber-banding at edges and (unlike its initiating counterpart) allows 1-finger pans. During a simultaneous pinch, does not rubber-band to avoid fighting the pinch centroid math.
- **Tap** dismisses.

Pan may dismiss with a fling animation if velocity exceeds the threshold.

### `ZoomOverlayFloatingView`

Renders the overlay view, lightbox background, and hosts the floating gesture recognizer.

## Assumptions and Known Issues

**Screen size is fixed for the duration of a transition.** `screenSize` is captured at `show` call time and used throughout for pan bounds and centering math. A rotation or multitasking resize while the overlay is visible will produce incorrect bounds until the next initiation.

**The source frame is fixed for the duration of a transition.** `sourceFrame` is the screen-space rect of the card at the moment the gesture began. If the source view scrolls or moves while the overlay is up (e.g. the scroll view bounces), the overlay image will not track it.

**One overlay at a time.** `ZoomOverlayState` is a singleton with no concept of a stack. Initiating a new zoom while one is already visible replaces the state immediately, with no transition between them.

**`UIImage` identity is stable.** The source image hiding logic uses `===` to match the overlay's image against the modifier's image. If the image instance is replaced (e.g. re-decoded from cache) while the overlay is visible, the source view will un-hide prematurely and both will be visible simultaneously.

**The overlay window is installed before any zoom is triggered.** `ZoomOverlayInstaller.installIfNeeded` must be called at scene setup. If a zoom gesture fires before installation, the initiating view will drive transforms with no visible overlay.

**`@MainActor` throughout.** All state mutations assume the main thread. The Combine sink in `ZoomOverlayInstaller` does not marshal to the main actor explicitly; it relies on `ZoomOverlayState` being `@MainActor` and `objectWillChange` being published on the main thread, which holds as long as all writes go through the state object's methods.

**The only containing views that compete for tap events are scroll views.** The tap-suppression logic in `ZoomOverlayInitiatingGestureView` walks the ancestor hierarchy looking for a `UIScrollView`. If the view is not inside a scroll view, the tap event will always trigger a zoom. Other types of events aren't checked for competing views.

**Visual artifacts occur if the originating view is clipped.** The overlay pops the image out to the highest level, so if the originating view is faded or clipped by anything other than the physical screen bounds, there will be an obvious jump as the image appears (and disappears) since it animates to/from the originating view's clipped area, but is not itself clipped.

**Pan does not rubber-band while a pinch is active.** Both recognizers fire every frame during a simultaneous pinch+pan, and rubber-banded pan resistance fights the pinch centroid math, causing the image to drift from the focal point. The workaround is to apply raw translation during a pinch and resync `rawPanOffset` each frame, so rubber-banding resumes correctly once the pinch ends.

## Why UIKit and Combine

> Note: My experiments suggest that implementing this feature exclusively in SwiftUI is impossible, but I don't know it _that_ well so it's possible I was going down the wrong path and the assertions about requiring UIKit are misguided. This is my best understanding.

**`UIWindow`**: The overlay must appear above SwiftUI sheets and full-screen covers, which are themselves hosted in separate `UIWindow` instances at elevated window levels. A SwiftUI overlay or `ZStack` layer is confined to its own window and cannot paint above another window, so the only way to guarantee the zoom image is always on top is to host it in its own window at a higher level still. A side effect of this is that the window must have interaction disabled when the overlay is not in use, otherwise it would silently eat all touches even when invisible.

**UIKit gestures**: SwiftUI's gesture system doesn't expose `UIGestureRecognizerDelegate`, which is required here for two things: gating the pan recognizer on pinch state via `gestureRecognizerShouldBegin`, and blocking scroll view pan recognizers from firing simultaneously with the pinch via `shouldRecognizeSimultaneouslyWith`. Without delegate control, it's not possible to prevent the scroll view from scrolling during a pinch, or to suppress the tap during a scroll-arrest touch.

**Combine**: The overlay `UIWindow` lives outside any SwiftUI view hierarchy, so SwiftUI's `onChange` and environment have no reach into it. The only way to reactively update `isUserInteractionEnabled` on the window in response to state changes is to subscribe directly to the `ObservableObject` publisher, which is what `ZoomOverlayInstaller`'s `AnyCancellable` does.
