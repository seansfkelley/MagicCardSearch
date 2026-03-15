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

        let overlayWindow = PassthroughWindow(windowScene: windowScene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.isUserInteractionEnabled = false
        overlayWindow.rootViewController = host
        overlayWindow.makeKeyAndVisible()
        // Don't keep this as key window — yield key status back to the main window.
        viewController.view.window?.makeKey()

        Self.overlayWindow = overlayWindow

        // Mirror isVisible onto the window so touches pass through when inactive.
        cancellable = manager.$isVisible.sink { isVisible in
            overlayWindow.isUserInteractionEnabled = isVisible
        }

        isInstalled = true
    }
}

/// A UIWindow that passes hit-tests through to the window below when it has no
/// interactive content at the tapped point.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === rootViewController?.view ? nil : view
    }
}

