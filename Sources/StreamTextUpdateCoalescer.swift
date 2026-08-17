import Foundation

@MainActor
final class StreamTextUpdateCoalescer {
    private let interval: TimeInterval
    private var lastEmission: Date?
    private var pendingText: String?
    private var pendingEmitter: ((String) -> Void)?
    private var scheduledWork: DispatchWorkItem?

    init(interval: TimeInterval = 0.04) {
        self.interval = max(0, interval)
    }

    func submit(_ text: String, emit: @escaping (String) -> Void) {
        pendingText = text
        pendingEmitter = emit
        let now = Date()
        if let lastEmission, now.timeIntervalSince(lastEmission) < interval {
            scheduleFlush(after: interval - now.timeIntervalSince(lastEmission))
        } else {
            flush()
        }
    }

    func flush() {
        scheduledWork?.cancel()
        scheduledWork = nil
        guard let text = pendingText, let emitter = pendingEmitter else { return }
        pendingText = nil
        pendingEmitter = nil
        lastEmission = Date()
        emitter(text)
    }

    func cancel() {
        scheduledWork?.cancel()
        scheduledWork = nil
        pendingText = nil
        pendingEmitter = nil
        lastEmission = nil
    }

    private func scheduleFlush(after delay: TimeInterval) {
        guard scheduledWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flush()
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }
}
