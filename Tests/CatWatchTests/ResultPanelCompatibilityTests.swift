import AppKit
import XCTest
@testable import CatWatch

final class ResultPanelCompatibilityTests: XCTestCase {
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
