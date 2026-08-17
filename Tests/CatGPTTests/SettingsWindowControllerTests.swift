import AppKit
import XCTest
@testable import CatGPT

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    private let sidebarDividerIdentifier = NSUserInterfaceItemIdentifier("CatGPTSettingsSidebarDivider")

    func testSettingsWindowUsesConfirmedTitleMinimumAndDefaultSize() throws {
        let controller = SettingsWindowController(
            draftProvider: ConfigDraft.load,
            stateProvider: {
                SettingsState(
                    signedIn: false,
                    accountId: "",
                    screenPermission: false,
                    statusText: "就绪",
                    hotKeyStatus: "快捷键未启用"
                )
            },
            onApply: { _, _ in },
            onLogin: {},
            onLogout: {},
            onPermission: {}
        )

        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, "CatGPT 设置")
        XCTAssertEqual(window.contentView?.frame.size, NSSize(width: 800, height: 580))
        XCTAssertEqual(window.minSize, NSSize(width: 760, height: 520))
        XCTAssertGreaterThanOrEqual(window.frame.width, window.minSize.width)
        XCTAssertGreaterThanOrEqual(window.frame.height, window.minSize.height)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertNil(window.toolbar)
    }

    func testSettingsWindowUsesTransparentBackingForMaterialBackgrounds() throws {
        let controller = SettingsWindowController(
            draftProvider: ConfigDraft.load,
            stateProvider: {
                SettingsState(
                    signedIn: false,
                    accountId: "",
                    screenPermission: false,
                    statusText: "就绪",
                    hotKeyStatus: "快捷键未启用"
                )
            },
            onApply: { _, _ in },
            onLogin: {},
            onLogout: {},
            onPermission: {}
        )

        let window = try XCTUnwrap(controller.window)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
    }

    func testSettingsWindowAddsSidebarDividerAcrossFullContentHeight() throws {
        let controller = SettingsWindowController(
            draftProvider: ConfigDraft.load,
            stateProvider: {
                SettingsState(
                    signedIn: false,
                    accountId: "",
                    screenPermission: false,
                    statusText: "就绪",
                    hotKeyStatus: "快捷键未启用"
                )
            },
            onApply: { _, _ in },
            onLogin: {},
            onLogout: {},
            onPermission: {}
        )

        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let frameView = try XCTUnwrap(contentView.superview)
        let divider = try XCTUnwrap(frameView.subviews.first { $0.identifier == sidebarDividerIdentifier })

        XCTAssertEqual(divider.frame.origin.x, 148)
        XCTAssertEqual(divider.frame.origin.y, 0)
        XCTAssertEqual(divider.frame.height, frameView.bounds.height)
    }

    func testShortcutRecorderLeavesVisualSurfaceToSwiftUI() {
        let recorder = SettingsShortcutCaptureButton()

        XCTAssertFalse(recorder.isBordered)
        XCTAssertFalse(recorder.wantsLayer)
        XCTAssertNil(recorder.layer)
        XCTAssertEqual(recorder.focusRingType, .none)
        XCTAssertEqual(recorder.contentTintColor, .controlAccentColor)
    }
}
