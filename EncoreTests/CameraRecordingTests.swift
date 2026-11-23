import Testing
import AVFoundation
@testable import Encore

/// A take that ends by itself (a call, an alarm, a full disk) is kept when AVFoundation says what was recorded is fine. It used to
/// be thrown away whenever there was an error, so a lesson of several minutes was lost for a call in the last seconds.
struct CameraRecordingTests {
    private func error(finishedSuccessfully: Bool?) -> NSError {
        var info: [String: Any] = [:]
        if let finishedSuccessfully { info[AVErrorRecordingSuccessfullyFinishedKey] = finishedSuccessfully }
        return NSError(domain: AVFoundationErrorDomain, code: AVError.diskFull.rawValue, userInfo: info)
    }

    @Test func aNormalEndIsPlayable() {
        #expect(CameraRecording.isPlayable(afterError: nil))
    }

    @Test func aTakeThatEndedByItselfButWasRecordedIsKept() {
        #expect(CameraRecording.isPlayable(afterError: error(finishedSuccessfully: true)))
    }

    @Test func aTakeAVFoundationCallsUnfinishedIsNotKept() {
        #expect(!CameraRecording.isPlayable(afterError: error(finishedSuccessfully: false)))
    }

    @Test func anErrorThatSaysNothingIsNotKept() {
        #expect(!CameraRecording.isPlayable(afterError: error(finishedSuccessfully: nil)))
    }
}
