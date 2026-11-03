import Testing
import Foundation
@testable import Encore

/// The camera's level reads 0° on whichever edge the iPhone is held by, its numbers read as Slovak, and the
/// zoom and self-timer chips step the way the system camera does.
@MainActor
struct DanceCameraTests {
    @Test func theLevelMeasuresAgainstTheNearestEdge() {
        #expect(HorizonLevel.tilt(roll: 2.8) == (reference: 0, tilt: 2.8))
        // On its side for a whole couple: straight is 0°, not 90°.
        let sideways = HorizonLevel.tilt(roll: 92)
        #expect(sideways.reference == 90)
        #expect(abs(sideways.tilt - 2) < 0.0001)
        let otherSide = HorizonLevel.tilt(roll: -89)
        #expect(otherSide.reference == -90)
        #expect(abs(otherSide.tilt - 1) < 0.0001)
        let upsideDown = HorizonLevel.tilt(roll: 178)
        #expect(upsideDown.reference == 180)
        #expect(abs(upsideDown.tilt + 2) < 0.0001)
    }

    @Test func theLevelNeverShowsMinusZero() {
        #expect(HorizonLevel.text(-0.02) == "0°")
        #expect(HorizonLevel.text(2.84) == "+2,8°")
        #expect(HorizonLevel.text(-1.4) == "−1,4°")
    }

    @Test func zoomReadsLikeTheSystemCamera() {
        #expect(CameraZoomFactor.text(0.5) == "0,5×")
        #expect(CameraZoomFactor.text(1) == "1×")
        #expect(CameraZoomFactor.text(1.74) == "1,7×")
        #expect(CameraZoomFactor.text(2.0) == "2×")
    }

    @Test func theSelfTimerStepsRound() {
        #expect(CountdownDuration.off.next == .threeSeconds)
        #expect(CountdownDuration.threeSeconds.next == .fiveSeconds)
        #expect(CountdownDuration.fiveSeconds.next == .tenSeconds)
        #expect(CountdownDuration.tenSeconds.next == .off)
    }
}
