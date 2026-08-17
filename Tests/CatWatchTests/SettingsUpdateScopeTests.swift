import XCTest
@testable import CatWatch

final class SettingsUpdateScopeTests: XCTestCase {
    private var base: ConfigDraft { ConfigDraft.load() }

    func testAppearanceFieldsOnlyRequestAppearanceUpdate() {
        var changed = base
        changed.panelOpacity = 0.41
        XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.appearance])
    }

    func testShortcutFieldsOnlyRequestShortcutUpdate() {
        var changed = base
        changed.hotKeyText = "cmd+shift+j"
        XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.shortcuts])
    }

    func testClientFieldsOnlyRequestClientUpdate() {
        var changed = base
        changed.model = "gpt-5.6-sol"
        XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.client])
    }

    func testCaptureRegionOnlyRequestsStorageUpdate() {
        var changed = base
        changed.captureRegionEnabled.toggle()
        XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.storageOnly])
    }

    func testMultipleFamiliesReturnAllRequiredScopes() {
        var changed = base
        changed.panelFontSize += 1
        changed.prompt += " 更简短"
        XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.appearance, .client])
    }
}
