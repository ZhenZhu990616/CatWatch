import AppKit
import Foundation

enum SelectionCapture {
    @MainActor
    static func captureImageData(maxEdge: Int) async throws -> Data {
        let region = try await SelectionOverlayController.selectRect()
        if #unavailable(macOS 14.0) {
            // 旧截屏路径无法排除自家窗口，只能等蒙层真正消失后再截。
            try? await Task.sleep(nanoseconds: 90_000_000)
        }
        try Task.checkCancellation()
        return try await Screenshotter.captureImageData(maxEdge: maxEdge, region: region)
    }

    @MainActor
    static func selectRegion() async throws -> CGRect {
        try await SelectionOverlayController.selectRect()
    }
}

/// 持有本次框选会话的 controller 引用，让 onCancel 精确命中这次会话。
private final class ControllerBox: @unchecked Sendable {
    weak var value: SelectionOverlayController?
}

@MainActor
private final class SelectionOverlayController {
    private static var active: SelectionOverlayController?

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var continuation: CheckedContinuation<CGRect, Error>?
    private var finished = false

    static func selectRect() async throws -> CGRect {
        // 已有一个框选会话在进行（设置页选区域 + 全局快捷键重叠，或快速双触发）：
        // 先取消旧会话，避免它的 continuation/窗口/事件监视器被覆盖而泄漏。
        active?.cancel()

        // 用 box 捕获本次会话的 controller，供 onCancel 精确取消，
        // 而不是裸读全局 active（可能已被下一次会话覆盖）。
        let box = ControllerBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let controller = SelectionOverlayController(continuation: continuation)
                box.value = controller
                active = controller
                controller.begin()
            }
        } onCancel: {
            Task { @MainActor in
                box.value?.cancel()
            }
        }
    }

    private init(continuation: CheckedContinuation<CGRect, Error>) {
        self.continuation = continuation
    }

    private func begin() {
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }
            return event
        }

        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self] rect in self?.finish(rect) }
            view.onCancel = { [weak self] in self?.cancel() }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            return window
        }
    }

    private func finish(_ rect: CGRect) {
        guard !finished else { return }
        finished = true
        cleanup()
        continuation?.resume(returning: rect.standardized)
        continuation = nil
        Self.active = nil
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        cleanup()
        // 用 CancellationError 让上层走"用户取消"路径（安静收场），
        // 而不是被当成错误弹红色提示。
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        Self.active = nil
    }

    private func cleanup() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private final class SelectionOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        NSCursor.crosshair.set()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        guard let localRect = localSelectionRect(), localRect.width >= 12, localRect.height >= 12,
              let window else {
            onCancel?()
            return
        }

        let origin = window.convertPoint(toScreen: localRect.origin)
        onFinish?(CGRect(origin: origin, size: localRect.size))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let rect = localSelectionRect() else {
            drawHint()
            return
        }
        NSColor.clear.setFill()
        rect.fill(using: .clear)

        NSColor.white.withAlphaComponent(0.96).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        outline.lineWidth = 1.5
        outline.stroke()

        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        outline.fill()

        drawSizeLabel(for: rect)
    }

    /// 尚未开始拖选时，在屏幕顶部居中提示操作方式。
    private func drawHint() {
        let text = "拖动框选要提问的区域，按 Esc 取消"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let size = text.size(withAttributes: attributes)
        let padding = NSSize(width: 16, height: 8)
        let badge = NSRect(
            x: bounds.midX - size.width / 2 - padding.width,
            y: bounds.maxY - 96,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2).fill()
        text.draw(
            at: NSPoint(x: badge.minX + padding.width, y: badge.minY + padding.height),
            withAttributes: attributes
        )
    }

    /// 像系统 ⌘⇧4 一样，在选框右下角实时显示宽 × 高。
    private func drawSizeLabel(for rect: NSRect) {
        let scale = window?.backingScaleFactor ?? 1
        let text = "\(Int(rect.width * scale)) × \(Int(rect.height * scale))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let padding = NSSize(width: 6, height: 3)
        var badge = NSRect(
            x: rect.maxX - size.width - padding.width * 2,
            y: rect.minY - size.height - padding.height * 2 - 6,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )
        // 贴近屏幕底部时翻到选框内侧，避免被裁掉。
        if badge.minY < bounds.minY + 4 {
            badge.origin.y = rect.minY + 6
        }
        badge.origin.x = max(bounds.minX + 4, badge.origin.x)

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        text.draw(
            at: NSPoint(x: badge.minX + padding.width, y: badge.minY + padding.height),
            withAttributes: attributes
        )
    }

    private func localSelectionRect() -> CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
