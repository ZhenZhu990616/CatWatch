import AppKit
import XCTest
@testable import CatGPT

final class ResultPanelCompatibilityTests: XCTestCase {
    @MainActor
    func testClearingStoredPanelOriginStopsReusingTheOldPosition() throws {
        let controller = ResultPanelController()
        controller.configure(
            width: 240,
            height: 120,
            opacity: 0.94,
            textOpacity: 1,
            fontSize: 14,
            textColor: .system,
            originX: 17,
            originY: 19
        )
        XCTAssertEqual(controller.panelOrigin, NSPoint(x: 17, y: 19))

        controller.configure(
            width: 240,
            height: 120,
            opacity: 0.94,
            textOpacity: 1,
            fontSize: 14,
            textColor: .system,
            originX: nil,
            originY: nil
        )

        XCTAssertNil(controller.panelOrigin)
    }

    @MainActor
    func testAnswerTextAdoptsDarkHUDMaterialAppearance() throws {
        let app = NSApplication.shared
        let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
        let controller = ResultPanelController()

        controller.showPhase("thinking")

        let panel = try XCTUnwrap(
            app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) }
        )
        defer { panel.close() }

        panel.appearance = NSAppearance(named: .aqua)
        let effectView = try XCTUnwrap(firstSubview(of: NSVisualEffectView.self, in: panel.contentView))
        effectView.appearance = NSAppearance(named: .vibrantDark)

        controller.show(text: "模型返回的答案", kind: "ready")

        let textView = try XCTUnwrap(firstSubview(of: NSTextView.self, in: panel.contentView))
        XCTAssertEqual(textView.string, "模型返回的答案")
        XCTAssertEqual(
            textView.effectiveAppearance.name,
            effectView.effectiveAppearance.name,
            "回答视图必须采用 HUD 材质外观，不能依赖不同 macOS 版本隐式解析动态颜色"
        )
    }

    @MainActor
    func testResultPanelTextIsNotSelectableAndEntireSurfaceUsesWindowDragging() throws {
        let app = NSApplication.shared
        let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
        let controller = ResultPanelController()

        controller.show(text: "不可选文本", kind: "ready")

        let panel = try XCTUnwrap(
            app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) }
        )
        defer { panel.close() }

        let textView = try XCTUnwrap(firstSubview(of: NSTextView.self, in: panel.contentView))
        XCTAssertFalse(textView.isSelectable)
        XCTAssertEqual(String(describing: type(of: panel)), "ResultPanelWindow")
        XCTAssertTrue(panel.isMovableByWindowBackground)
    }

    @MainActor
    func testBatchIndicatorShowsOnlyCachedStarsAndHidesAnswerText() throws {
        let app = NSApplication.shared
        let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
        let controller = ResultPanelController()

        controller.showBatch(count: 3)

        let panel = try XCTUnwrap(app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) })
        defer { panel.close() }
        let batchView = try XCTUnwrap(firstSubview(of: BatchCaptureIndicatorView.self, in: panel.contentView))
        let textView = try XCTUnwrap(firstSubview(of: NSTextView.self, in: panel.contentView))

        XCTAssertFalse(batchView.isHidden)
        XCTAssertEqual(batchView.count, 3)
        XCTAssertEqual(batchView.accessibilityLabel(), "已缓存 3 张截图")
        XCTAssertTrue(textView.isHidden)
    }

    @MainActor
    func testSendingPhaseHidesBatchIndicatorAndRestoresPaw() throws {
        let app = NSApplication.shared
        let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
        let controller = ResultPanelController()
        controller.showBatch(count: 2)

        let panel = try XCTUnwrap(app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) })
        defer { panel.close() }
        controller.showPhase("sending")

        let batchView = try XCTUnwrap(firstSubview(of: BatchCaptureIndicatorView.self, in: panel.contentView))
        let phaseView = try XCTUnwrap(firstSubview(of: PhaseIndicatorView.self, in: panel.contentView))
        XCTAssertTrue(batchView.isHidden)
        XCTAssertFalse(phaseView.isHidden)
    }

    @MainActor
    func testFlushPendingFrameImmediatelyPersistsDebouncedMove() throws {
        let controller = ResultPanelController()
        controller.configure(
            width: 240,
            height: 120,
            opacity: 0.94,
            textOpacity: 1,
            fontSize: 14,
            textColor: .system,
            originX: 17,
            originY: 19
        )
        controller.show(text: "位置测试", kind: "ready")
        let panel = try XCTUnwrap(NSApplication.shared.windows.last)

        var saved: (Int, Int, Double, Double)?
        controller.onFrameChanged = { saved = ($0, $1, $2, $3) }
        var movedFrame = panel.frame
        movedFrame.origin.x += 11
        movedFrame.origin.y += 7
        panel.setFrame(movedFrame, display: false)
        controller.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: panel))
        controller.flushPendingFrame()

        XCTAssertEqual(saved?.2, movedFrame.origin.x)
        XCTAssertEqual(saved?.3, movedFrame.origin.y)
    }

    private func firstSubview<View: NSView>(of type: View.Type, in root: NSView?) -> View? {
        guard let root else { return nil }
        if let match = root as? View { return match }
        for subview in root.subviews {
            if let match = firstSubview(of: type, in: subview) {
                return match
            }
        }
        return nil
    }
}
