import XCTest
@testable import CatWatch

final class SettingsApplicationTests: XCTestCase {
    func testAppearanceDoesNotTouchShortcutsOrClient() throws {
        var current = ConfigDraft.load()
        var events: [String] = []
        let application = SettingsApplication(
            persist: { _ in events.append("persist") },
            appearance: { _ in events.append("appearance") },
            shortcuts: { _ in events.append("shortcuts") },
            client: { _ in events.append("client") }
        )
        var proposed = current
        proposed.panelOpacity = 0.5

        try application.apply(proposed, to: &current, scope: .appearance)

        XCTAssertEqual(events, ["appearance", "persist"])
        XCTAssertEqual(current.panelOpacity, 0.5)
    }

    func testShortcutFailureRestoresPreviousRegistrationAndDraft() {
        struct Conflict: Error {}

        var current = ConfigDraft.load()
        let previous = current
        var registered: [String] = []
        let application = SettingsApplication(
            persist: { _ in XCTFail("失败配置不应持久化") },
            appearance: { _ in },
            shortcuts: { draft in
                registered.append(draft.hotKeyText)
                if draft.hotKeyText != previous.hotKeyText {
                    throw Conflict()
                }
            },
            client: { _ in }
        )
        var proposed = current
        proposed.hotKeyText = "cmd+shift+j"

        XCTAssertThrowsError(try application.apply(proposed, to: &current, scope: .shortcuts))
        XCTAssertEqual(current, previous)
        XCTAssertEqual(registered, ["cmd+shift+j", previous.hotKeyText])
    }

    func testStorageOnlyPersistsWithoutRuntimeReload() throws {
        var current = ConfigDraft.load()
        var events: [String] = []
        let application = SettingsApplication(
            persist: { _ in events.append("persist") },
            appearance: { _ in events.append("appearance") },
            shortcuts: { _ in events.append("shortcuts") },
            client: { _ in events.append("client") }
        )
        var proposed = current
        proposed.captureRegionEnabled.toggle()

        try application.apply(proposed, to: &current, scope: .storageOnly)

        XCTAssertEqual(events, ["persist"])
    }

    func testSettingsEditsPreserveRuntimePanelGeometry() throws {
        var current = ConfigDraft.load()
        current.panelWidth = 611
        current.panelOriginX = 123
        var proposed = current
        proposed.panelWidth = 520
        proposed.panelOriginX = nil
        proposed.prompt += " 简短"
        let application = SettingsApplication(
            persist: { _ in }, appearance: { _ in }, shortcuts: { _ in }, client: { _ in }
        )

        try application.apply(proposed, to: &current, scope: .client)

        XCTAssertEqual(current.panelWidth, 611)
        XCTAssertEqual(current.panelOriginX, 123)
    }
}
