import CoreMotion
import Observation
import UIKit

// MARK: - Horizon level (camera)
/// The camera's level from the gyroscope. Only the level overlay reads it, so twenty readings a second redraw the
/// level alone, never the camera's buttons.
@Observable
final class HorizonLevel {
    /// The screen's tilt against the horizon, in degrees.
    private(set) var rollAngle: Double = 0
    private(set) var isLevel = false
    /// Lying flat (on a table, or pointing down from a tripod): the level becomes a bubble.
    private(set) var isFlat = false
    private(set) var flatOffset: CGPoint = .zero

    @ObservationIgnored private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates(to: .main) { [weak self] reading, _ in
            guard let self, let gravity = reading?.gravity else { return }
            let angle = atan2(gravity.x, -gravity.y) * 180 / .pi
            let level = abs(angle) < 0.8
            // A short snap when the phone comes level.
            if level && !self.isLevel {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            self.rollAngle = angle
            self.isLevel = level
            self.isFlat = abs(gravity.z) > 0.85
            self.flatOffset = CGPoint(x: gravity.x * 35, y: -gravity.y * 35)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}
