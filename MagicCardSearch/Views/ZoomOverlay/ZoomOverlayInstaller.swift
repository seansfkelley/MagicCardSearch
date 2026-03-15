import SwiftUI
import Combine

/// Installs the FloatingZoomOverlayView into the UIWindow above all other content.
/// Must be called with a live UIViewController whose view is already in the window hierarchy.
@MainActor
enum ZoomOverlayInstaller {
    private static var isInstalled = false
    // Retained for the lifetime of the app.
    private static var cancellable: AnyCancellable?

    static func installIfNeeded(from viewController: UIViewController) {
        guard !isInstalled, let window = viewController.view.window else { return }

        let manager = ZoomOverlayManager.shared
        let host = UIHostingController(
            rootView: FloatingZoomOverlayView()
                .environmentObject(manager)
        )
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.frame = window.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(host.view)

        // Mirror isVisible onto the UIKit layer so touches pass through when inactive.
        cancellable = manager.$isVisible.sink { [weak host] isVisible in
            host?.view.isUserInteractionEnabled = isVisible
        }

        isInstalled = true
    }
}

