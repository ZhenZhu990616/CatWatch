import Foundation

@MainActor
final class BatchCaptureQueue {
    enum BeginCaptureResult: Equatable {
        case started
        case busy
        case full
    }

    enum TransferResult: Equatable {
        case empty
        case captureInFlight
        case images([Data])
    }

    enum ImmediateCaptureAction: Equatable {
        case captureCurrentScreen
        case sendQueuedImages
        case waitForBatchCapture
    }

    let maximumImageCount = 8

    private var queuedImages: [Data] = []
    private var isCaptureInFlight = false

    var count: Int {
        queuedImages.count
    }

    var isEmpty: Bool {
        queuedImages.isEmpty
    }

    var isCapturing: Bool {
        isCaptureInFlight
    }

    func beginCapture() -> BeginCaptureResult {
        if queuedImages.count >= maximumImageCount {
            return .full
        }
        guard !isCaptureInFlight else {
            return .busy
        }

        isCaptureInFlight = true
        return .started
    }

    func completeCapture(_ imageData: Data) {
        guard isCaptureInFlight else { return }
        isCaptureInFlight = false
        guard queuedImages.count < maximumImageCount else { return }
        queuedImages.append(imageData)
    }

    func cancelInFlightCapture() {
        isCaptureInFlight = false
    }

    @discardableResult
    func removeLast() -> Data? {
        guard !isCaptureInFlight else { return nil }
        guard !queuedImages.isEmpty else { return nil }
        return queuedImages.removeLast()
    }

    func takeAllForSending() -> TransferResult {
        if isCaptureInFlight {
            return .captureInFlight
        }
        guard !queuedImages.isEmpty else {
            return .empty
        }
        defer { queuedImages.removeAll(keepingCapacity: true) }
        return .images(queuedImages)
    }

    func clear() {
        queuedImages.removeAll(keepingCapacity: true)
        isCaptureInFlight = false
    }

    func immediateCaptureAction() -> ImmediateCaptureAction {
        if isCaptureInFlight {
            return .waitForBatchCapture
        }
        if !queuedImages.isEmpty {
            return .sendQueuedImages
        }
        return .captureCurrentScreen
    }
}
