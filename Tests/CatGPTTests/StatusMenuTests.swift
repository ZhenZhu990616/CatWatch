import XCTest
@testable import CatGPT

@MainActor
final class StatusMenuTests: XCTestCase {
    func testStatusMenuOmitsRetiredPermissionAndShortcutActions() {
        let titles = AppDelegate().makeStatusMenu().items.map(\.title)

        XCTAssertFalse(titles.contains("打开屏幕录制权限设置"))
        XCTAssertFalse(titles.contains("重新注册快捷键"))
        XCTAssertTrue(titles.contains("偏好设置"))
        XCTAssertTrue(titles.contains("退出"))
    }
}
