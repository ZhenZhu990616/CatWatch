import Foundation
import XCTest

final class PermissionPromptRegressionTests: XCTestCase {
    func testRegisteringDoubleTapShortcutDoesNotRequestAccessibilityAutomatically() throws {
        let source = try sourceFile(named: "HotKey.swift")
        let registerMethod = try XCTUnwrap(
            source.between("func register(shortcut:", and: "    func unregisterAll()")
        )

        XCTAssertFalse(
            registerMethod.contains("requestAccessibilityIfNeeded()"),
            "注册快捷键不能自行弹出辅助功能授权；系统提示只能由用户在设置中主动请求。"
        )
    }

    func testKeychainStartupReadDisablesAuthenticationUI() throws {
        let source = try sourceFile(named: "Config.swift")
        let readMethod = try XCTUnwrap(
            source.between("private static func readString", and: "    private static func saveString")
        )

        XCTAssertTrue(
            readMethod.contains("kSecUseAuthenticationContext as String: context"),
            "启动读取钥匙串必须传入禁止交互的认证上下文，避免拒绝后重复弹窗。"
        )
        XCTAssertTrue(
            readMethod.contains("context.interactionNotAllowed = true"),
            "启动读取钥匙串必须禁止钥匙串显示认证界面。"
        )
    }

    func testServiceSettingsOffersUserInitiatedAccessibilityAuthorization() throws {
        let source = try sourceFile(named: "Settings/ServiceSettingsView.swift")

        XCTAssertTrue(
            source.contains("SettingsRow(\"辅助功能\""),
            "设置页必须提供用户主动请求辅助功能授权的入口。"
        )
        XCTAssertTrue(
            source.contains("model.requestAccessibilityPermission()"),
            "辅助功能授权必须只由设置页的用户操作发起。"
        )
    }

    private func sourceFile(named name: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Sources/\(name)"), encoding: .utf8)
    }
}

private extension String {
    func between(_ start: String, and end: String) -> String? {
        guard let startRange = range(of: start),
              let endRange = range(of: end, range: startRange.upperBound..<endIndex) else {
            return nil
        }
        return String(self[startRange.lowerBound..<endRange.lowerBound])
    }
}
