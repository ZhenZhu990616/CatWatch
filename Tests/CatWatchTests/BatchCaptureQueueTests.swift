import XCTest
@testable import CatWatch

@MainActor
final class BatchCaptureQueueTests: XCTestCase {
    func testBeginCaptureTransitionsThroughStartedBusyAndFull() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertTrue(queue.isCapturing)
        XCTAssertEqual(queue.beginCapture(), .busy)

        queue.cancelInFlightCapture()

        for index in 0..<queue.maximumImageCount {
            XCTAssertEqual(queue.beginCapture(), .started, "expected start for capture \(index)")
            queue.completeCapture(Data([UInt8(index)]))
        }

        XCTAssertEqual(queue.beginCapture(), .full)
        XCTAssertFalse(queue.isCapturing)
    }

    func testCompleteCaptureAppendsInOrder() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([1]))
        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([2]))
        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([3]))

        XCTAssertEqual(queue.takeAllForSending(), [Data([1]), Data([2]), Data([3])])
        XCTAssertEqual(queue.takeAllForSending(), [])
    }

    func testCancelInFlightCaptureDoesNotAppend() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([1]))

        XCTAssertEqual(queue.beginCapture(), .started)
        queue.cancelInFlightCapture()
        queue.completeCapture(Data([2]))

        XCTAssertEqual(queue.takeAllForSending(), [Data([1])])
    }

    func testRemoveLastAndClearEmptyTheQueue() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([1]))
        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([2]))

        XCTAssertEqual(queue.removeLast(), Data([2]))
        XCTAssertEqual(queue.takeAllForSending(), [Data([1])])

        XCTAssertEqual(queue.beginCapture(), .started)
        queue.completeCapture(Data([3]))
        queue.clear()

        XCTAssertEqual(queue.takeAllForSending(), [])
        XCTAssertFalse(queue.isCapturing)
    }

    func testImmediateCaptureActionReflectsQueueState() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.immediateCaptureAction(), .captureCurrentScreen)

        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertEqual(queue.immediateCaptureAction(), .waitForBatchCapture)

        queue.completeCapture(Data([1]))
        XCTAssertEqual(queue.immediateCaptureAction(), .sendQueuedImages)
    }
}
