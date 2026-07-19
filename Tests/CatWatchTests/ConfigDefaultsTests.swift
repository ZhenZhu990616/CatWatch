import XCTest
@testable import CatWatch

final class ConfigDefaultsTests: XCTestCase {
    func testFloatingPanelUsesReadableFirstLaunchSize() {
        XCTAssertEqual(ConfigDraft.defaultPanelWidth, 520)
        XCTAssertEqual(ConfigDraft.defaultPanelHeight, 320)

        let aspectRatio = Double(ConfigDraft.defaultPanelWidth) / Double(ConfigDraft.defaultPanelHeight)
        XCTAssertGreaterThan(aspectRatio, 1.55)
        XCTAssertLessThan(aspectRatio, 1.70)
    }
}
