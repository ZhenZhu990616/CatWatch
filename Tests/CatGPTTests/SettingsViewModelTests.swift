import XCTest
@testable import CatGPT

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testImmediateChangeAppliesOnlyItsScope() throws {
        let initial = ConfigDraft.load()
        var calls: [(ConfigDraft, SettingsUpdateScope)] = []
        let model = makeModel(initial: initial) { draft, scope in
            calls.append((draft, scope))
        }

        model.set(0.52, at: \ConfigDraft.panelOpacity, scope: .appearance)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.1, .appearance)
        XCTAssertEqual(model.lastAppliedDraft.panelOpacity, 0.52)
    }

    func testTextChangeWaitsForDebounceThenApplies() async throws {
        let initial = ConfigDraft.load()
        let applied = expectation(description: "debounced apply")
        var calls: [(ConfigDraft, SettingsUpdateScope)] = []
        let model = makeModel(initial: initial, debounceNanoseconds: 10_000_000) { draft, scope in
            calls.append((draft, scope))
            applied.fulfill()
        }

        model.setText("gpt-5.6-sol", at: \ConfigDraft.model, field: .model)
        XCTAssertTrue(calls.isEmpty)
        await fulfillment(of: [applied], timeout: 1)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].0.model, "gpt-5.6-sol")
        XCTAssertEqual(calls[0].1, .client)
    }

    func testInvalidModelStaysVisibleButDoesNotApply() async throws {
        let initial = ConfigDraft.load()
        var calls = 0
        let model = makeModel(initial: initial, debounceNanoseconds: 1_000_000) { _, _ in
            calls += 1
        }

        model.setText("   ", at: \ConfigDraft.model, field: .model)
        try await waitForModelError(in: model)

        XCTAssertEqual(model.draft.model, "   ")
        XCTAssertEqual(model.lastAppliedDraft.model, initial.model)
        XCTAssertEqual(model.error(for: .model), "模型不能为空。")
        XCTAssertEqual(calls, 0)
    }

    func testUnknownModelStaysVisibleButDoesNotApply() async throws {
        let initial = ConfigDraft.load()
        var calls = 0
        let model = makeModel(initial: initial, debounceNanoseconds: 1_000_000) { _, _ in
            calls += 1
        }

        model.setText("gpt-not-a-real-model", at: \ConfigDraft.model, field: .model)
        try await waitForModelError(in: model)

        XCTAssertEqual(model.draft.model, "gpt-not-a-real-model")
        XCTAssertEqual(model.lastAppliedDraft.model, initial.model)
        XCTAssertEqual(model.error(for: .model), "模型输入有误。")
        XCTAssertEqual(calls, 0)
    }

    func testImageEdgeIsClampedBeforeImmediateApply() {
        let initial = ConfigDraft.load()
        var applied: ConfigDraft?
        let model = makeModel(initial: initial) { draft, _ in
            applied = draft
        }

        model.setMaxImageEdge(320)

        XCTAssertEqual(applied?.maxImageEdge, 640)
        XCTAssertEqual(model.draft.maxImageEdge, 640)
    }

    func testOutputTokensAreClampedBeforeImmediateApply() {
        var initial = ConfigDraft.load()
        initial.maxOutputTokens = 128
        var applied: ConfigDraft?
        let model = makeModel(initial: initial) { draft, _ in
            applied = draft
        }

        model.setMaxOutputTokens(-1)

        XCTAssertEqual(applied?.maxOutputTokens, 0)
        XCTAssertEqual(model.draft.maxOutputTokens, 0)
    }

    private func makeModel(
        initial: ConfigDraft,
        debounceNanoseconds: UInt64 = 300_000_000,
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
            applyDraft: apply,
            debounceNanoseconds: debounceNanoseconds
        )
    }

    private func waitForModelError(in model: SettingsViewModel) async throws {
        for _ in 0..<100 {
            if model.error(for: .model) != nil {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
