import SwiftUI
import Combine

/// Hosts the FloatingZoomOverlayView in a dedicated UIWindow above all other windows,
/// including SwiftUI sheet/fullScreenCover presentations.
/// Must be called with a live UIViewController whose view is already in the window hierarchy.
@MainActor
enum ZoomOverlayInstaller {
    private static var isInstalled = false
    private static var overlayWindow: UIWindow?
    // Retained for the lifetime of the app.
    private static var cancellable: AnyCancellable?

    static func installIfNeeded(from viewController: UIViewController) {
        guard !isInstalled,
              let windowScene = viewController.view.window?.windowScene
        else { return }

        let manager = ZoomOverlayManager.shared

        let host = UIHostingController(
            rootView: FloatingZoomOverlayView()
                .environmentObject(manager)
        )
        host.view.backgroundColor = .clear

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.isUserInteractionEnabled = false
        overlayWindow.rootViewController = host
        overlayWindow.makeKeyAndVisible()
        // Don't keep this as key window — yield key status back to the main window.
        viewController.view.window?.makeKey()

        Self.overlayWindow = overlayWindow

        // Enable interaction only after the originating gesture has ended and
        // handed off to the overlay's own gestures.
        cancellable = manager.$isGestureActive
            .combineLatest(manager.$isVisible)
            .sink { isGestureActive, isVisible in
                overlayWindow.isUserInteractionEnabled = isVisible && !isGestureActive
            }

        isInstalled = true
    }
}


