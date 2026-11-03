import CoreMotion
import Observation
import UIKit

// MARK: - Horizon level (camera)
/// The camera's level from the gyroscope, upright or on its side: the tilt is measured against the nearest
/// edge, so an iPhone held sideways for a whole couple reads 0° when straight. Readings are smoothed, and the
/// level has a little slack at its edge, so it neither jitters nor buzzes again and again. Only the level
/// overlay reads it, so its readings redraw the overlay alone.
@Observable
final class HorizonLevel {
    /// The phone's roll in degrees (0 upright, 90 on its side): the horizon line turns by it.
    private(set) var rollAngle: Double = 0
    /// The tilt against the nearest edge, in tenths of a degree, so the overlay redraws only when the number changes.
    private(set) var tilt: Double = 0
    /// The nearest edge (0, ±90, 180): the number turns with it, so it reads the right way up.
    private(set) var reference: Double = 0
    private(set) var isLevel = false
    /// Lying flat (on a table, or pointing down from a tripod): the level becomes a bubble.
    private(set) var isFlat = false
    private(set) var flatOffset: CGPoint = .zero

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var gravity = (x: 0.0, y: -1.0, z: 0.0)

    /// The tilt of `roll` against the nearest of the four edges.
    static func tilt(roll: Double) -> (reference: Double, tilt: Double) {
        let reference = (roll / 90).rounded() * 90
        return (reference, roll - reference)
    }

    /// "0°", "+2,8°", "−1,4°" (never "−0,0°").
    static func text(_ tilt: Double) -> String {
        let shown = (tilt * 10).rounded() / 10
        guard shown != 0 else { return "0°" }
        return (shown > 0 ? "+" : "−") + String(format: "%.1f", abs(shown)).replacingOccurrences(of: ".", with: ",") + "°"
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] reading, _ in
            guard let self, let raw = reading?.gravity else { return }
            self.update(with: raw)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func update(with raw: CMAcceleration) {
        // A light low-pass filter: a steady hand reads steady.
        let smoothing = 0.2
        gravity = (
            x: gravity.x + (raw.x - gravity.x) * smoothing,
            y: gravity.y + (raw.y - gravity.y) * smoothing,
            z: gravity.z + (raw.z - gravity.z) * smoothing
        )
        let roll = atan2(gravity.x, -gravity.y) * 180 / .pi
        let measured = Self.tilt(roll: roll)
        // In at 0.5°, out only past 1°.
        let level = isLevel ? abs(measured.tilt) < 1.0 : abs(measured.tilt) < 0.5
        if level && !isLevel {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        let flat = isFlat ? abs(gravity.z) > 0.8 : abs(gravity.z) > 0.88
        let shownTilt = (measured.tilt * 10).rounded() / 10

        if abs(roll - rollAngle) >= 0.1 { rollAngle = roll }
        if shownTilt != tilt { tilt = shownTilt }
        if measured.reference != reference { reference = measured.reference }
        if level != isLevel { isLevel = level }
        if flat != isFlat { isFlat = flat }
        let offset = CGPoint(x: (gravity.x * 35).rounded(), y: (-gravity.y * 35).rounded())
        if offset != flatOffset { flatOffset = offset }
    }
}
