import XCTest
@testable import CatWatch

@MainActor
final class ShortcutSettingsTests: XCTestCase {
    func testHotKeyParserRejectsMultiplePrimaryKeys() {
        XCTAssertThrowsError(try Shortcut.parse("cmd+shift+a+b"))
    }

    func testInvalidShortcutRestoresLastAppliedValue() {
        let initial = ConfigDraft.load()
        var applyCount = 0
        let model = makeModel(initial: initial) { _, _ in
            applyCount += 1
        }

        model.setShortcut("j", at: \ConfigDraft.hotKeyText, field: .captureShortcut)

        XCTAssertEqual(model.draft.hotKeyText, initial.hotKeyText)
        XCTAssertNotNil(model.error(for: .captureShortcut))
        XCTAssertEqual(applyCount, 0)
    }

    func testDuplicateShortcutRestoresLastAppliedValue() {
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in
            XCTFail("不应应用重复快捷键")
        }

        model.setShortcut(initial.selectionHotKeyText, at: \ConfigDraft.hotKeyText, field: .captureShortcut)

        XCTAssertEqual(model.draft.hotKeyText, initial.hotKeyText)
        XCTAssertEqual(model.error(for: .captureShortcut), "不能与其他 CatWatch 快捷键重复。")
    }

    func testCaptureRegionShortcutCannotDuplicateAnotherShortcut() {
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in
            XCTFail("不应应用重复快捷键")
        }

        model.setShortcut(
            initial.hotKeyText,
            at: \ConfigDraft.captureRegionHotKeyText,
            field: .captureRegionShortcut
        )

        XCTAssertEqual(model.draft.captureRegionHotKeyText, initial.captureRegionHotKeyText)
        XCTAssertEqual(model.error(for: .captureRegionShortcut), "不能与其他 CatWatch 快捷键重复。")
    }

    func testBatchCaptureShortcutCannotDuplicateAnotherShortcut() {
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in XCTFail("不应应用重复快捷键") }

        model.setShortcut(initial.hotKeyText, at: \ConfigDraft.batchCaptureHotKeyText, field: .batchCaptureShortcut)

        XCTAssertEqual(model.draft.batchCaptureHotKeyText, initial.batchCaptureHotKeyText)
        XCTAssertEqual(model.error(for: .batchCaptureShortcut), "不能与其他 CatWatch 快捷键重复。")
    }

    func testResetShortcutsRestoresCaptureRegionShortcutDefault() {
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in }

        model.setShortcut("cmd+shift+r", at: \ConfigDraft.captureRegionHotKeyText, field: .captureRegionShortcut)
        model.resetShortcuts()

        XCTAssertEqual(model.draft.hotKeyText, ConfigDraft.defaultHotKey)
        XCTAssertEqual(model.draft.selectionHotKeyText, ConfigDraft.defaultSelectionHotKey)
        XCTAssertEqual(model.draft.panelHotKeyText, ConfigDraft.defaultPanelHotKey)
        XCTAssertEqual(model.draft.captureRegionHotKeyText, ConfigDraft.defaultCaptureRegionHotKey)
        XCTAssertEqual(model.draft.batchCaptureHotKeyText, ConfigDraft.defaultBatchCaptureHotKey)
    }

    func testRegistrationFailureRestoresLastAppliedValue() {
        struct RegistrationError: LocalizedError {
            var errorDescription: String? { "快捷键已被其他应用占用。" }
        }

        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in
            throw RegistrationError()
        }

        model.setShortcut("cmd+shift+j", at: \ConfigDraft.hotKeyText, field: .captureShortcut)

        XCTAssertEqual(model.draft.hotKeyText, initial.hotKeyText)
        XCTAssertEqual(model.error(for: .captureShortcut), "快捷键已被其他应用占用。")
    }

    private func makeModel(
        initial: ConfigDraft,
        apply: @escaping (ConfigDraft, SettingsUpdateScope) throws -> Void
    ) -> SettingsViewModel {
        SettingsViewModel(
            initialDraft: initial,
            stateProvider: {
                SettingsState(
                    signedIn: false,
                    accountId: "",
                    screenPermission: false,
                    statusText: "就绪",
                    hotKeyStatus: "已启用"
                )
            },
            applyDraft: apply
        )
    }
}
