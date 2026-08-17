import Foundation

@MainActor
final class BatchCaptureQueue {
    enum BeginCaptureResult: Equatable {
        case started
        case busy
        case full
    }

    enum ImmediateCaptureAction: Equatable {
        case captureCurrentScreen
        case sendQueuedImages
        case waitForBatchCapture
    }

    let maximumImageCount = 8

    private var queuedImages: [Data] = []
    private var isCaptureInFlight = false

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

    func takeAllForSending() -> [Data] {
        guard !isCaptureInFlight else { return [] }
        guard !queuedImages.isEmpty else { return [] }
        defer { queuedImages.removeAll(keepingCapacity: true) }
        return queuedImages
    }

    func clear() {
        queuedImages.removeAll(keepingCapacity: true)
        isCaptureInFlight = false
    }

    func immediateCaptureAction() -> ImmediateCaptureAction {
        if !queuedImages.isEmpty {
            return .sendQueuedImages
        }
        if isCaptureInFlight {
            return .waitForBatchCapture
        }
        return .captureCurrentScreen
    }
}
