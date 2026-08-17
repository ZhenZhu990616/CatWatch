import XCTest
@testable import CatWatch

final class LLMClientRequestTests: XCTestCase {
    func testMultiImageRequestStartsWithPromptThenPreservesImageOrder() throws {
        let body = LLMClient.makeRequestBody(
            config: makeConfig(),
            imageDataList: [Data([0x01]), Data([0x02])],
            mimeType: "image/jpeg"
        )
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])

        XCTAssertEqual(content.map { $0["type"] as? String }, ["input_text", "input_image", "input_image"])
        XCTAssertEqual(content[0]["text"] as? String, "测试提示词")
        XCTAssertEqual(content[1]["image_url"] as? String, "data:image/jpeg;base64,AQ==")
        XCTAssertEqual(content[2]["image_url"] as? String, "data:image/jpeg;base64,Ag==")
    }

    func testSingleImageBodyUsesTheSamePromptAndImageLayout() throws {
        let body = LLMClient.makeRequestBody(
            config: makeConfig(),
            imageDataList: [Data([0x0A])],
            mimeType: "image/png"
        )
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])

        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "input_text")
        XCTAssertEqual(content[1]["image_url"] as? String, "data:image/png;base64,Cg==")
    }

    private func makeConfig() -> AppConfig {
        AppConfig(
            codexCredentials: CodexOAuthCredentials(access: "access", refresh: "refresh", expires: 9_999_999_999, accountId: "account"),
            model: "gpt-5.6-terra", thinkingEnabled: true, reasoningEffort: .medium,
            reasoningSummary: .none, textVerbosity: .low, serviceTier: .systemDefault,
            maxOutputTokens: 0, outputDisplayMode: .floatingPanel, touchBarFontSize: 14,
            touchBarTextColor: .system, touchBarTextIntensity: 1, touchBarTextAlignment: .center,
            prompt: "测试提示词", instructions: "测试指令", maxImageEdge: 1600
        )
    }
}
