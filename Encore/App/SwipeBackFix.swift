import UIKit
import SwiftUI

// MARK: - Safe Swipe-Back Controller
// Replaces the dangerous global UINavigationController.viewDidLoad category override.
// Disables the interactivePopGestureRecognizer purely via isEnabled ONLY when a view explicitly requests it (e.g. RoutineCanvasView),
// preventing UIKit's _UISystemGestureGateGestureRecognizer from freezing touches for 36+ seconds at app launch.

struct DisableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SwipeBackDisablerView())
    }
}

private struct SwipeBackDisablerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackDisablerViewController {
        SwipeBackDisablerViewController()
    }
    
    func updateUIViewController(_ uiViewController: SwipeBackDisablerViewController, context: Context) {}
}

private final class SwipeBackDisablerViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

public extension View {
    /// Safely disables the navigation edge swipe-back gesture while this specific view is presented,
    /// without tampering with UINavigationController's internal gesture delegate or causing gesture hangs.
    func disableSwipeBack() -> some View {
        self.modifier(DisableSwipeBackModifier())
    }
}
