# Batch Screenshot Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow CatGPT to cache up to eight screenshots in memory and submit them as one ordered multi-image Codex request, with explicit batch feedback and Escape cancellation.

**Architecture:** A `@MainActor` queue owns the ordered in-memory JPEG data and the one in-flight cache state. `AppDelegate` remains the runtime coordinator: it registers the fifth shortcut, captures with the existing `Screenshotter`, transfers the queue only after all pre-send checks pass, and drives the result panel. `LLMClient` receives a single multi-image request builder so single-image and batch requests cannot diverge.

**Tech Stack:** Swift 5.9, macOS 14+, AppKit, SwiftUI, ScreenCaptureKit, XCTest, URLSession.

---

## File structure

- Create: `Sources/BatchCaptureQueue.swift` — main-actor state machine for ordered, in-memory screenshot data.
- Create: `Sources/BatchCaptureIndicatorView.swift` — AppKit drawing view for the six-point-star-only batch indicator.
- Create: `Tests/CatGPTTests/BatchCaptureQueueTests.swift` — queue and immediate-dispatch behavior.
- Create: `Tests/CatGPTTests/LLMClientRequestTests.swift` — JSON request body ordering tests.
- Modify: `Sources/Config.swift` — fifth shortcut persistence/default, batch environment variable, and one-time capture-region migration.
- Modify: `Sources/Settings/SettingsUpdateScope.swift` — classify the fifth shortcut as a live shortcut update.
- Modify: `Sources/Settings/SettingsViewModel.swift` — validate, reset, and report the fifth shortcut.
- Modify: `Sources/Settings/ShortcutsSettingsView.swift` — display the batch shortcut recorder.
- Modify: `Sources/LLMClient.swift` — create one request body for one or more images.
- Modify: `Sources/main.swift` — batch shortcut registration, queue capture/submit lifecycle, controlled Escape monitor, result-panel integration, and logout/quit cleanup.
- Modify: `Tests/CatGPTTests/ConfigDefaultsTests.swift`, `Tests/CatGPTTests/SettingsUpdateScopeTests.swift`, `Tests/CatGPTTests/ShortcutSettingsTests.swift`, and `Tests/CatGPTTests/ResultPanelCompatibilityTests.swift` — regression coverage for settings and panel state.
- Modify: `README.md` — document the fifth shortcut, its environment variable, the queue limit, and Escape behavior.

### Task 1: Add the main-actor batch queue and its state-machine tests

**Files:**
- Create: `Sources/BatchCaptureQueue.swift`
- Create: `Tests/CatGPTTests/BatchCaptureQueueTests.swift`

- [ ] **Step 1: Write the failing queue tests**

Create `Tests/CatGPTTests/BatchCaptureQueueTests.swift` with these exact behavioral tests:

```swift
import XCTest
@testable import CatGPT

@MainActor
final class BatchCaptureQueueTests: XCTestCase {
    func testCompletedCapturesKeepTheirOriginalOrder() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertTrue(queue.completeCapture(Data([0x01])))
        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertTrue(queue.completeCapture(Data([0x02])))

        XCTAssertEqual(queue.immediateCaptureAction, .sendQueuedImages([Data([0x01]), Data([0x02])]))
        XCTAssertEqual(queue.takeAllForSending(), [Data([0x01]), Data([0x02])])
        XCTAssertEqual(queue.count, 0)
    }

    func testNinthCaptureIsRejectedWithoutChangingEightCachedImages() {
        let queue = BatchCaptureQueue()
        for byte in UInt8(0)..<UInt8(BatchCaptureQueue.maximumImageCount) {
            XCTAssertEqual(queue.beginCapture(), .started)
            XCTAssertTrue(queue.completeCapture(Data([byte])))
        }

        XCTAssertEqual(queue.beginCapture(), .full)
        XCTAssertEqual(queue.count, BatchCaptureQueue.maximumImageCount)
        XCTAssertEqual(queue.takeAllForSending(), (0..<BatchCaptureQueue.maximumImageCount).map { Data([UInt8($0)]) })
    }

    func testSecondCacheStartIsBusyUntilTheFirstCaptureFinishesOrIsCancelled() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertEqual(queue.beginCapture(), .busy)
        queue.cancelInFlightCapture()
        XCTAssertEqual(queue.beginCapture(), .started)
    }

    func testEscapeDuringCaptureCancelsOnlyTheInFlightItem() {
        let queue = BatchCaptureQueue()
        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertTrue(queue.completeCapture(Data([0x01])))
        XCTAssertEqual(queue.beginCapture(), .started)

        queue.cancelInFlightCapture()

        XCTAssertFalse(queue.isCapturing)
        XCTAssertEqual(queue.count, 1)
        XCTAssertFalse(queue.completeCapture(Data([0x02])))
        XCTAssertEqual(queue.takeAllForSending(), [Data([0x01])])
    }

    func testEscapeWhenReadyRemovesOnlyTheNewestCachedImage() {
        let queue = BatchCaptureQueue()
        for byte in [UInt8(0x01), 0x02] {
            XCTAssertEqual(queue.beginCapture(), .started)
            XCTAssertTrue(queue.completeCapture(Data([byte])))
        }

        XCTAssertEqual(queue.removeLast(), Data([0x02]))
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.takeAllForSending(), [Data([0x01])])
    }

    func testImmediateCaptureActionPreservesQueueUntilTheCallerTakesItAfterPreflight() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.immediateCaptureAction, .captureCurrentScreen)
        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertTrue(queue.completeCapture(Data([0x42])))
        XCTAssertEqual(queue.immediateCaptureAction, .sendQueuedImages([Data([0x42])]))
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.takeAllForSending(), [Data([0x42])])
    }

    func testImmediateCaptureActionWaitsForAnInFlightBatchCapture() {
        let queue = BatchCaptureQueue()

        XCTAssertEqual(queue.beginCapture(), .started)
        XCTAssertEqual(queue.immediateCaptureAction, .waitForBatchCapture)
        XCTAssertEqual(queue.takeAllForSending(), nil)
    }
}
```

- [ ] **Step 2: Run the new tests and verify compilation fails because the queue does not exist**

Run: `swift test --filter BatchCaptureQueueTests`

Expected: compilation failure mentioning `cannot find 'BatchCaptureQueue' in scope`.

- [ ] **Step 3: Implement the minimal explicit state machine**

Create `Sources/BatchCaptureQueue.swift`:

```swift
import Foundation

@MainActor
enum BatchCaptureStartResult: Equatable {
    case started
    case busy
    case full
}

@MainActor
enum ImmediateCaptureAction: Equatable {
    case captureCurrentScreen
    case sendQueuedImages([Data])
    case waitForBatchCapture
}

@MainActor
final class BatchCaptureQueue {
    static let maximumImageCount = 8

    private(set) var images: [Data] = []
    private(set) var isCapturing = false

    var count: Int { images.count }
    var isEmpty: Bool { images.isEmpty }
    var immediateCaptureAction: ImmediateCaptureAction {
        if isCapturing { return .waitForBatchCapture }
        if images.isEmpty { return .captureCurrentScreen }
        return .sendQueuedImages(images)
    }

    func beginCapture() -> BatchCaptureStartResult {
        if isCapturing { return .busy }
        if images.count >= Self.maximumImageCount { return .full }
        isCapturing = true
        return .started
    }

    @discardableResult
    func completeCapture(_ image: Data) -> Bool {
        guard isCapturing, images.count < Self.maximumImageCount else { return false }
        isCapturing = false
        images.append(image)
        return true
    }

    func cancelInFlightCapture() {
        isCapturing = false
    }

    @discardableResult
    func removeLast() -> Data? {
        guard !isCapturing else { return nil }
        return images.popLast()
    }

    func takeAllForSending() -> [Data]? {
        guard !isCapturing, !images.isEmpty else { return nil }
        defer { images.removeAll(keepingCapacity: false) }
        return images
    }

    func clear() {
        isCapturing = false
        images.removeAll(keepingCapacity: false)
    }
}
```

- [ ] **Step 4: Run the queue tests and verify they pass**

Run: `swift test --filter BatchCaptureQueueTests`

Expected: all seven `BatchCaptureQueueTests` pass.

- [ ] **Step 5: Commit the isolated state machine**

```bash
git add Sources/BatchCaptureQueue.swift Tests/CatGPTTests/BatchCaptureQueueTests.swift
git commit -m "feat: add in-memory batch capture queue"
```

### Task 2: Add the batch shortcut, defaults, migration, and settings controls

**Files:**
- Modify: `Sources/Config.swift:25-390, 574-600`
- Modify: `Sources/Settings/SettingsUpdateScope.swift:17-39`
- Modify: `Sources/Settings/SettingsViewModel.swift:14-22, 147-202`
- Modify: `Sources/Settings/ShortcutsSettingsView.swift:5-100`
- Modify: `Tests/CatGPTTests/ConfigDefaultsTests.swift`
- Modify: `Tests/CatGPTTests/SettingsUpdateScopeTests.swift`
- Modify: `Tests/CatGPTTests/ShortcutSettingsTests.swift`

- [ ] **Step 1: Extend the settings regression tests before changing configuration**

Add these methods to `ConfigDefaultsTests` and preserve/restore every touched `UserDefaults` key in `defer`:

```swift
func testBatchCaptureDefaultsToShiftDoubleTapAndCaptureRegionDefaultsToCommandE() throws {
    XCTAssertEqual(ConfigDraft.defaultCaptureRegionHotKey, "cmd+e")
    XCTAssertEqual(ConfigDraft.defaultBatchCaptureHotKey, "shift double tap")
    XCTAssertEqual(try Shortcut.parse(ConfigDraft.defaultCaptureRegionHotKey).displayText, "⌘E")
    XCTAssertEqual(try Shortcut.parse(ConfigDraft.defaultBatchCaptureHotKey).displayText, "⇧ double tap")
}

func testOldCaptureRegionDefaultMigratesToCommandEWithoutOverwritingCustomValue() {
    let defaults = UserDefaults.standard
    let keys = [
        "catGPT.captureRegionHotKey",
        "catGPT.captureRegionShortcutMigrationVersion"
    ]
    let previous = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
    defer {
        for (key, value) in previous {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }

    defaults.removeObject(forKey: "catGPT.captureRegionShortcutMigrationVersion")
    defaults.set("shift double tap", forKey: "catGPT.captureRegionHotKey")
    XCTAssertEqual(ConfigDraft.load().captureRegionHotKeyText, "cmd+e")

    defaults.removeObject(forKey: "catGPT.captureRegionShortcutMigrationVersion")
    defaults.set("cmd+shift+r", forKey: "catGPT.captureRegionHotKey")
    XCTAssertEqual(ConfigDraft.load().captureRegionHotKeyText, "cmd+shift+r")
}

func testBatchCaptureShortcutUsesStoredValueBeforeEnvironmentAndDefault() {
    let defaults = UserDefaults.standard
    let key = "catGPT.batchCaptureHotKey"
    let previous = defaults.object(forKey: key)
    defer {
        if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    defaults.set("cmd+shift+b", forKey: key)
    XCTAssertEqual(ConfigDraft.load().batchCaptureHotKeyText, "cmd+shift+b")
}
```

Add the following test methods to the settings test files:

```swift
// SettingsUpdateScopeTests
func testBatchCaptureShortcutOnlyRequestsShortcutUpdate() {
    var changed = base
    changed.batchCaptureHotKeyText = "cmd+shift+b"
    XCTAssertEqual(SettingsUpdateScope.changed(from: base, to: changed), [.shortcuts])
}

// ShortcutSettingsTests
func testBatchShortcutCannotDuplicateAnotherShortcut() {
    let initial = ConfigDraft.load()
    let model = makeModel(initial: initial) { _, _ in XCTFail("不应应用重复快捷键") }

    model.setShortcut(initial.hotKeyText, at: \ConfigDraft.batchCaptureHotKeyText, field: .batchCaptureShortcut)

    XCTAssertEqual(model.draft.batchCaptureHotKeyText, initial.batchCaptureHotKeyText)
    XCTAssertEqual(model.error(for: .batchCaptureShortcut), "不能与其他 CatGPT 快捷键重复。")
}

func testResetShortcutsRestoresBatchShortcutDefault() {
    let initial = ConfigDraft.load()
    let model = makeModel(initial: initial) { _, _ in }

    model.setShortcut("cmd+shift+b", at: \ConfigDraft.batchCaptureHotKeyText, field: .batchCaptureShortcut)
    model.resetShortcuts()

    XCTAssertEqual(model.draft.batchCaptureHotKeyText, ConfigDraft.defaultBatchCaptureHotKey)
    XCTAssertEqual(model.draft.captureRegionHotKeyText, ConfigDraft.defaultCaptureRegionHotKey)
}
```

- [ ] **Step 2: Run the focused test group and verify it fails for the missing fields and defaults**

Run: `swift test --filter 'ConfigDefaultsTests|SettingsUpdateScopeTests|ShortcutSettingsTests'`

Expected: compilation failure for `defaultBatchCaptureHotKey`, `batchCaptureHotKeyText`, and `.batchCaptureShortcut`.

- [ ] **Step 3: Add persistence and one-time migration in `ConfigDraft`**

Make the configuration changes as one coherent patch:

```swift
// ConfigDraft stored property, next to captureRegionHotKeyText
var batchCaptureHotKeyText: String

// defaults
static let defaultCaptureRegionHotKey = "cmd+e"
static let defaultBatchCaptureHotKey = "shift double tap"
private static let captureRegionShortcutMigrationVersion = 1
private static let legacyDefaultCaptureRegionHotKey = "shift double tap"

// At the beginning of load(), immediately after migrateLegacyShortcutDefaultsIfNeeded(defaults)
migrateCaptureRegionShortcutDefaultIfNeeded(defaults)

// ConfigDraft(...) construction
batchCaptureHotKeyText: defaults.string(forKey: Keys.batchCaptureHotKey)
    ?? env["SCREEN_LLM_BATCH_CAPTURE_HOTKEY"]
    ?? defaultBatchCaptureHotKey,

private static func migrateCaptureRegionShortcutDefaultIfNeeded(_ defaults: UserDefaults) {
    guard defaults.integer(forKey: Keys.captureRegionShortcutMigrationVersion) < captureRegionShortcutMigrationVersion else {
        return
    }
    if defaults.string(forKey: Keys.captureRegionHotKey) == legacyDefaultCaptureRegionHotKey {
        defaults.set(defaultCaptureRegionHotKey, forKey: Keys.captureRegionHotKey)
    }
    defaults.set(captureRegionShortcutMigrationVersion, forKey: Keys.captureRegionShortcutMigrationVersion)
}

// save()
defaults.set(batchCaptureHotKeyText, forKey: Keys.batchCaptureHotKey)

// shortcut factories
func makeBatchCaptureShortcut() throws -> Shortcut {
    try Shortcut.parse(batchCaptureHotKeyText)
}

// Keys
static let batchCaptureHotKey = "catGPT.batchCaptureHotKey"
static let captureRegionShortcutMigrationVersion = "catGPT.captureRegionShortcutMigrationVersion"
```

Update all explicit `ConfigDraft(...)` fixtures and equality-sensitive construction sites to include `batchCaptureHotKeyText`. Do not fold the capture-region migration into `shortcutDefaultsMigrationVersion`: it must run separately so machines that have already completed the older migration still receive `cmd+e` while custom values remain unchanged.

- [ ] **Step 4: Include the fifth value in live settings handling and render it in the UI**

Make these concrete updates:

```swift
// SettingsUpdateScope.changed(...)
|| old.batchCaptureHotKeyText != new.batchCaptureHotKeyText

// SettingsField
case batchCaptureShortcut

// SettingsViewModel.setShortcut(...)
let shortcuts = [
    try Shortcut.parse(candidate.hotKeyText).displayText,
    try Shortcut.parse(candidate.selectionHotKeyText).displayText,
    try Shortcut.parse(candidate.panelHotKeyText).displayText,
    try Shortcut.parse(candidate.captureRegionHotKeyText).displayText,
    try Shortcut.parse(candidate.batchCaptureHotKeyText).displayText
]

// SettingsViewModel.resetShortcuts()
candidate.batchCaptureHotKeyText = ConfigDraft.defaultBatchCaptureHotKey
draft.batchCaptureHotKeyText = candidate.batchCaptureHotKeyText
fieldErrors[.batchCaptureShortcut] = nil
```

In `ShortcutsSettingsView`, add the following row in `SettingsGroup("全局操作")` after the existing immediate-screenshot row and before the first `SettingsDivider()`:

```swift
shortcutRow(
    title: "批量截图",
    subtitle: "每次缓存一张；再按立即截图一次性发送（最多 8 张）",
    keyPath: \ConfigDraft.batchCaptureHotKeyText,
    field: .batchCaptureShortcut
)
```

Keep “从屏幕选择” as its own fixed-region control; its changed default is `⌘E`, not the batch shortcut.

- [ ] **Step 5: Run all shortcut/settings tests and verify they pass**

Run: `swift test --filter 'ConfigDefaultsTests|SettingsUpdateScopeTests|ShortcutSettingsTests'`

Expected: all selected tests pass, including custom capture-region values remaining untouched by migration and five-way duplicate detection.

- [ ] **Step 6: Commit configuration and settings changes**

```bash
git add Sources/Config.swift Sources/Settings/SettingsUpdateScope.swift Sources/Settings/SettingsViewModel.swift Sources/Settings/ShortcutsSettingsView.swift Tests/CatGPTTests/ConfigDefaultsTests.swift Tests/CatGPTTests/SettingsUpdateScopeTests.swift Tests/CatGPTTests/ShortcutSettingsTests.swift
git commit -m "feat: configure batch capture shortcut"
```

### Task 3: Build one ordered request payload for one or many images

**Files:**
- Modify: `Sources/LLMClient.swift:63-110`
- Create: `Tests/CatGPTTests/LLMClientRequestTests.swift`

- [ ] **Step 1: Write the failing request-body tests**

Create `Tests/CatGPTTests/LLMClientRequestTests.swift`:

```swift
import XCTest
@testable import CatGPT

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
```

- [ ] **Step 2: Run the focused tests and verify the internal builder does not exist**

Run: `swift test --filter LLMClientRequestTests`

Expected: compilation failure that `LLMClient` has no member `makeRequestBody`.

- [ ] **Step 3: Replace the single-image request construction with one shared builder**

In `Sources/LLMClient.swift`, replace the current body assembly in `analyze(imageData:mimeType:onEvent:)` with this pair of public actor methods and this internal static builder:

```swift
func analyze(
    imageData: Data,
    mimeType: String = "image/png",
    onEvent: (@Sendable (LLMStreamEvent) -> Void)? = nil
) async throws -> String {
    try await analyze(imageDataList: [imageData], mimeType: mimeType, onEvent: onEvent)
}

func analyze(
    imageDataList: [Data],
    mimeType: String = "image/png",
    onEvent: (@Sendable (LLMStreamEvent) -> Void)? = nil
) async throws -> String {
    guard !imageDataList.isEmpty else {
        throw AppError.configuration("至少需要一张截图。")
    }
    return try await perform(
        body: Self.makeRequestBody(config: config, imageDataList: imageDataList, mimeType: mimeType),
        onEvent: onEvent
    )
}

nonisolated static func makeRequestBody(
    config: AppConfig,
    imageDataList: [Data],
    mimeType: String
) -> [String: Any] {
    var content: [[String: Any]] = [["type": "input_text", "text": config.prompt]]
    content.append(contentsOf: imageDataList.map { imageData in
        [
            "type": "input_image",
            "image_url": "data:\(mimeType);base64,\(imageData.base64EncodedString())"
        ]
    })
    return makeBody(config: config, input: [["role": "user", "content": content]])
}
```

Replace the existing instance `makeBody(input:)` with this complete static helper so the request builder remains independent of actor isolation while preserving every current request option:

```swift
nonisolated private static func makeBody(config: AppConfig, input: [[String: Any]]) -> [String: Any] {
    var body: [String: Any] = [
        "model": config.model,
        "store": false,
        "stream": true,
        "instructions": config.instructions,
        "input": input,
        "text": [
            "verbosity": config.textVerbosity.rawValue
        ]
    ]
    var reasoning: [String: Any] = [
        "effort": config.thinkingEnabled ? config.reasoningEffort.rawValue : "none"
    ]
    if config.thinkingEnabled, let summary = config.reasoningSummary.requestValue {
        reasoning["summary"] = summary
    }
    body["reasoning"] = reasoning
    if let serviceTier = config.serviceTier.requestValue {
        body["service_tier"] = serviceTier
    }
    if config.maxOutputTokens > 0 {
        body["max_output_tokens"] = config.maxOutputTokens
    }
    return body
}
```

This keeps exactly one request layout for both one-image and many-image calls. It also prevents an empty batch from ever reaching the network layer.

- [ ] **Step 4: Run the request tests and existing client-related tests**

Run: `swift test --filter 'LLMClientRequestTests|ConfigDefaultsTests'`

Expected: request tests prove prompt-first ordering, base64 image order, and single-image compatibility.

- [ ] **Step 5: Commit the multi-image client support**

```bash
git add Sources/LLMClient.swift Tests/CatGPTTests/LLMClientRequestTests.swift
git commit -m "feat: support ordered multi-image analysis"
```

### Task 4: Add the text-free six-point-star batch indicator to the result panel

**Files:**
- Create: `Sources/BatchCaptureIndicatorView.swift`
- Modify: `Sources/main.swift:892-1198`
- Modify: `Tests/CatGPTTests/ResultPanelCompatibilityTests.swift`

- [ ] **Step 1: Add failing panel-state and accessibility tests**

Add these `@MainActor` tests to `ResultPanelCompatibilityTests`:

```swift
func testBatchIndicatorShowsOnlyTheRequestedNumberOfSixPointStars() throws {
    let app = NSApplication.shared
    let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
    let controller = ResultPanelController()

    controller.showBatch(count: 3)

    let panel = try XCTUnwrap(app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) })
    defer { panel.close() }
    let batchView = try XCTUnwrap(firstSubview(of: BatchCaptureIndicatorView.self, in: panel.contentView))
    let textView = try XCTUnwrap(firstSubview(of: NSTextView.self, in: panel.contentView))

    XCTAssertFalse(batchView.isHidden)
    XCTAssertEqual(batchView.count, 3)
    XCTAssertEqual(batchView.accessibilityLabel(), "已缓存 3 张截图")
    XCTAssertTrue(textView.isHidden)
}

func testSendingPhaseHidesBatchIndicatorAndRestoresPhaseIndicator() throws {
    let app = NSApplication.shared
    let existingWindows = Set(app.windows.map(ObjectIdentifier.init))
    let controller = ResultPanelController()
    controller.showBatch(count: 2)

    let panel = try XCTUnwrap(app.windows.first { !existingWindows.contains(ObjectIdentifier($0)) })
    defer { panel.close() }
    controller.showPhase("sending")

    let batchView = try XCTUnwrap(firstSubview(of: BatchCaptureIndicatorView.self, in: panel.contentView))
    let phaseView = try XCTUnwrap(firstSubview(of: PhaseIndicatorView.self, in: panel.contentView))
    XCTAssertTrue(batchView.isHidden)
    XCTAssertFalse(phaseView.isHidden)
}
```

- [ ] **Step 2: Run the focused panel tests and verify compilation fails**

Run: `swift test --filter ResultPanelCompatibilityTests`

Expected: compilation failure for `BatchCaptureIndicatorView` and `ResultPanelController.showBatch(count:)`.

- [ ] **Step 3: Implement the reusable star-only AppKit view**

Create `Sources/BatchCaptureIndicatorView.swift`:

```swift
import AppKit

final class BatchCaptureIndicatorView: NSView {
    private let shapeLayer = CAShapeLayer()
    private var color = NSColor.labelColor
    private var opacity: CGFloat = 1
    private var starSize: CGFloat = 7
    private(set) var count = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
        shapeLayer.fillRule = .nonZero
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    func configure(color: NSColor, opacity: Double, starSize: CGFloat) {
        self.color = color
        self.opacity = CGFloat(opacity)
        self.starSize = starSize
        updateLayer()
    }

    func setCount(_ count: Int) {
        self.count = min(max(count, 0), BatchCaptureQueue.maximumImageCount)
        setAccessibilityLabel("已缓存 \(self.count) 张截图")
        invalidateIntrinsicContentSize()
        needsLayout = true
        updateLayer()
    }

    override var intrinsicContentSize: NSSize {
        guard count > 0 else { return .zero }
        let spacing = max(3, starSize * 0.45)
        return NSSize(width: CGFloat(count) * starSize + CGFloat(count - 1) * spacing, height: starSize)
    }

    override func layout() {
        super.layout()
        updateLayer()
    }

    private func updateLayer() {
        shapeLayer.fillColor = color.withAlphaComponent(opacity).cgColor
        shapeLayer.path = makePath().cgPath
        shapeLayer.frame = bounds
    }

    private func makePath() -> NSBezierPath {
        let path = NSBezierPath()
        guard count > 0 else { return path }
        let spacing = max(3, starSize * 0.45)
        for starIndex in 0..<count {
            let center = CGPoint(x: starSize / 2 + CGFloat(starIndex) * (starSize + spacing), y: starSize / 2)
            for pointIndex in 0..<12 {
                let angle = -CGFloat.pi / 2 + CGFloat(pointIndex) * CGFloat.pi / 6
                let radius = pointIndex.isMultiple(of: 2) ? starSize / 2 : starSize / 4
                let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if pointIndex == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            path.close()
        }
        return path
    }
}
```

The twelve alternating vertices form one concave, single-path regular six-point star for each cached image. Do not draw overlapping filled triangles; that produces the previously rejected hourglass/sandglass appearance.

- [ ] **Step 4: Extend `ResultPanelController` to switch between text, paw phase, and stars**

In `Sources/main.swift`, add `private let batchIndicatorView = BatchCaptureIndicatorView()` next to `indicatorView`, then add:

```swift
func showBatch(count: Int) {
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in self?.showBatch(count: count) }
        return
    }
    guard count > 0 else {
        hideForCapture()
        return
    }
    let panel = panel ?? makePanel()
    self.panel = panel
    currentText = ""
    textView.isHidden = true
    indicatorView.isHidden = true
    batchIndicatorView.isHidden = false
    batchIndicatorView.setCount(count)
    applyVisualSettings()
    place(panel)
    panel.orderFrontRegardless()
}
```

In `show(text:...)`, hide `batchIndicatorView`; in `showPhase(_:)`, hide `batchIndicatorView`; and in `makePanel()` add `batchIndicatorView` to `content` with the same leading/top anchors as `indicatorView`. Store `batchIndicatorWidthConstraint` and `batchIndicatorHeightConstraint`, and in `applyVisualSettings()` configure it with:

```swift
let batchStarSize = max(6, CGFloat(panelFontSize) * 0.5)
batchIndicatorView.appearance = materialAppearance
batchIndicatorView.configure(color: textColor, opacity: panelTextOpacity, starSize: batchStarSize)
batchIndicatorWidthConstraint?.constant = batchIndicatorView.intrinsicContentSize.width
batchIndicatorHeightConstraint?.constant = batchIndicatorView.intrinsicContentSize.height
```

Do not add a count label, explanatory text, or thumbnail preview to the panel.

- [ ] **Step 5: Run the focused panel tests and verify phase restoration works**

Run: `swift test --filter ResultPanelCompatibilityTests`

Expected: all panel tests pass; batch mode hides the text view and phase paw, and `showPhase("sending")` returns to the paw.

- [ ] **Step 6: Commit the result-panel indicator**

```bash
git add Sources/BatchCaptureIndicatorView.swift Sources/main.swift Tests/CatGPTTests/ResultPanelCompatibilityTests.swift
git commit -m "feat: show batch capture indicator"
```

### Task 5: Coordinate capture, send, Escape, Touch Bar behavior, and lifecycle in `AppDelegate`

**Files:**
- Modify: `Sources/main.swift:1-890`
- Modify: `Tests/CatGPTTests/BatchCaptureQueueTests.swift`

- [ ] **Step 1: Add a failing regression test for queue retention before a failed send preflight**

Append this test to `BatchCaptureQueueTests` to codify the non-destructive boundary AppDelegate must honor:

```swift
func testQueuedImagesRemainAvailableUntilTheCoordinatorExplicitlyTakesThem() {
    let queue = BatchCaptureQueue()
    XCTAssertEqual(queue.beginCapture(), .started)
    XCTAssertTrue(queue.completeCapture(Data([0xAA])))

    // A failed login/permission preflight must inspect this action and return without calling takeAllForSending().
    XCTAssertEqual(queue.immediateCaptureAction, .sendQueuedImages([Data([0xAA])]))
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.takeAllForSending(), [Data([0xAA])])
}
```

- [ ] **Step 2: Run the queue suite to lock the preflight contract before controller changes**

Run: `swift test --filter BatchCaptureQueueTests`

Expected: PASS. The new test documents that `takeAllForSending()` is the only mutation that clears the queue.

- [ ] **Step 3: Add state and register the fifth global shortcut**

At the top of `AppDelegate`, add these stored properties:

```swift
private let batchCaptureQueue = BatchCaptureQueue()
private var batchCaptureTask: Task<Void, Never>?
private var batchEscapeMonitor: Any?
private var batchProgressUsesFloatingPanel = false
```

Add `import Carbon.HIToolbox` beside the AppKit/Foundation imports. In `registerHotKeys(from:)`, parse `let batchCaptureShortcut = try candidate.makeBatchCaptureShortcut()`, then register id `5`:

```swift
try shortcutRegistry.register(shortcut: batchCaptureShortcut, id: 5) { [weak self] in
    Task { @MainActor in
        self?.launchBatchCapture()
    }
}
```

Change id `1` and the menu item method `captureFromMenu()` to call a new `launchImmediateCapture()` rather than `launchCapture(selection: false)`. Extend `hotKeyStatus` with ` / 批量 \(batchCaptureShortcut.displayText)`.

- [ ] **Step 4: Implement the immediate-capture dispatcher without clearing before preflight**

Add the following methods before the existing `launchCapture(selection:)`:

```swift
private func launchImmediateCapture() throws {
    switch batchCaptureQueue.immediateCaptureAction {
    case .captureCurrentScreen:
        try launchCapture(selection: false)
    case .waitForBatchCapture:
        setStatus("正在缓存截图，请稍候", kind: "warning")
    case .sendQueuedImages:
        try sendBatchCaptureQueue()
    }
}

private func sendBatchCaptureQueue() throws {
    guard !batchCaptureQueue.isCapturing else {
        setStatus("正在缓存截图，请稍候", kind: "warning")
        return
    }
    guard client != nil else {
        throw AppError.configuration("请先登录 ChatGPT/Codex。")
    }
    guard Screenshotter.hasPermission() else {
        Screenshotter.requestPermissionIfNeeded()
        throw AppError.screenshot("需要授予 CatGPT 屏幕录制权限。请点击菜单里的“打开屏幕录制权限设置”，启用后重新打开应用。")
    }
    guard let images = batchCaptureQueue.takeAllForSending() else { return }

    batchProgressUsesFloatingPanel = true
    syncBatchEscapeMonitor()
    try startRequestState(status: "正在发送到 Codex...", phase: "sending")
    touchBarResult.hideForCapture()
    resultPanel.showPhase("sending")
    let token = captureToken
    let generation = clientGeneration
    captureTask = Task { @MainActor in
        do {
            let answer = try await self.performBatchAnalysis(images: images, token: token)
            guard self.captureToken == token else { return }
            self.captureTask = nil
            self.lastResult = answer
            self.history.add(prompt: self.draft.prompt, answer: answer)
            self.setStatus("完成", kind: "ready", phase: "ready")
            self.showOutput(text: answer, kind: "ready")
            self.isRunning = false
            self.batchProgressUsesFloatingPanel = false
        } catch {
            if self.isCancellation(error) {
                if self.captureToken == token { self.finishCancelledCapture() }
                return
            }
            guard self.captureToken == token else { return }
            self.captureTask = nil
            self.isRunning = false
            self.batchProgressUsesFloatingPanel = false
            self.handleAuthExpiredIfNeeded(error, generation: generation)
            self.lastResult = error.localizedDescription
            self.setStatus(error.localizedDescription, kind: "error", phase: "error")
            self.showOutput(text: error.localizedDescription, kind: "error")
        }
    }
}

private func startRequestState(status: String, phase: String) throws {
    guard client != nil else { throw AppError.configuration("请先登录 ChatGPT/Codex。") }
    isRunning = true
    captureToken = UUID()
    lastResult = ""
    setStatus(status, kind: "working", phase: phase)
}

private func performBatchAnalysis(images: [Data], token: UUID) async throws -> String {
    guard let client else { throw AppError.configuration("请先登录 ChatGPT/Codex。") }
    let answer = try await client.analyze(
        imageDataList: images,
        mimeType: "image/jpeg",
        onEvent: streamEventHandler(token: token)
    )
    try Task.checkCancellation()
    guard captureToken == token else { throw CancellationError() }
    return answer
}
```

Refactor the existing `startCaptureState()` to call `try startRequestState(status: "正在截图...", phase: "capturing")`. The key order is intentional: login and screen-permission checks happen before `takeAllForSending()`, so those failures preserve the queue; once the network request is started the queue remains cleared by design.

- [ ] **Step 5: Implement cache capture, max handling, and Escape monitor lifecycle**

Add these methods to `AppDelegate`:

```swift
private func launchBatchCapture() {
    guard !isRunning else {
        setStatus("当前任务尚未完成", kind: "warning")
        return
    }
    guard Screenshotter.hasPermission() else {
        Screenshotter.requestPermissionIfNeeded()
        setStatus("需要授予 CatGPT 屏幕录制权限。", kind: "error")
        return
    }
    switch batchCaptureQueue.beginCapture() {
    case .busy:
        setStatus("正在缓存截图，请稍候", kind: "warning")
        return
    case .full:
        setStatus("最多缓存 8 张，请先发送", kind: "warning")
        return
    case .started:
        break
    }

    hideOutputForCapture()
    if batchCaptureQueue.count > 0 { resultPanel.showBatch(count: batchCaptureQueue.count) }
    syncBatchEscapeMonitor()
    let maxEdge = draft.normalizedMaxImageEdge
    let region = draft.captureRegion
    batchCaptureTask = Task { @MainActor in
        defer {
            self.batchCaptureTask = nil
            self.syncBatchEscapeMonitor()
        }
        do {
            let image = try await Screenshotter.captureImageData(maxEdge: maxEdge, region: region)
            try Task.checkCancellation()
            guard self.batchCaptureQueue.completeCapture(image) else { return }
            self.setStatus("已缓存 \(self.batchCaptureQueue.count) 张截图", kind: "ready")
            self.resultPanel.showBatch(count: self.batchCaptureQueue.count)
        } catch {
            if self.isCancellation(error) { return }
            self.batchCaptureQueue.cancelInFlightCapture()
            self.setStatus(error.localizedDescription, kind: "error")
            if self.batchCaptureQueue.count > 0 {
                self.resultPanel.showBatch(count: self.batchCaptureQueue.count)
            } else {
                self.resultPanel.hideForCapture()
            }
        }
    }
}

private func syncBatchEscapeMonitor() {
    let shouldMonitor = batchCaptureQueue.isCapturing || !batchCaptureQueue.isEmpty
    if shouldMonitor, batchEscapeMonitor == nil {
        batchEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            Task { @MainActor in self?.handleBatchEscape() }
        }
    } else if !shouldMonitor, let batchEscapeMonitor {
        NSEvent.removeMonitor(batchEscapeMonitor)
        self.batchEscapeMonitor = nil
    }
}

private func handleBatchEscape() {
    if batchCaptureQueue.isCapturing {
        batchCaptureTask?.cancel()
        batchCaptureQueue.cancelInFlightCapture()
        setStatus("已取消缓存截图", kind: "ready")
    } else if batchCaptureQueue.removeLast() != nil {
        setStatus(batchCaptureQueue.isEmpty ? "就绪" : "已缓存 \(batchCaptureQueue.count) 张截图", kind: "ready")
    } else {
        return
    }
    if batchCaptureQueue.isEmpty {
        resultPanel.hideForCapture()
    } else {
        resultPanel.showBatch(count: batchCaptureQueue.count)
    }
    syncBatchEscapeMonitor()
}

private func clearBatchCaptureState() {
    batchCaptureTask?.cancel()
    batchCaptureTask = nil
    batchCaptureQueue.clear()
    batchProgressUsesFloatingPanel = false
    resultPanel.hideForCapture()
    syncBatchEscapeMonitor()
}
```

Do not add a local key monitor. The global monitor is installed only while the queue exists or a cache capture is in flight, so it does not intercept Escape in SwiftUI text fields, the shortcut recorder, or the selection overlay.

- [ ] **Step 6: Keep batch progress on the floating panel even when final output uses Touch Bar**

Change `showOutputPhase(_:)` and the `.delta` branch of `streamEventHandler(token:)` as follows:

```swift
private func showOutputPhase(_ phase: String) {
    if usingTouchBar && !batchProgressUsesFloatingPanel {
        resultPanel.hideForCapture()
        touchBarResult.showPhase(phase)
    } else {
        touchBarResult.hideForCapture()
        resultPanel.showPhase(phase)
    }
}

case .delta(let text):
    self.batchProgressUsesFloatingPanel = false
    self.showOutput(text: text, kind: "working", autoScroll: true, isStreaming: true)
```

The explicit initial `resultPanel.showPhase("sending")` in `sendBatchCaptureQueue()` plus this branch keeps the paw on the floating panel during sending/reasoning. On the first response text, the existing final-output routing resumes, including Touch Bar when selected.

- [ ] **Step 7: Clear memory-only queue state on logout and app termination**

At the start of `logout()`, call `clearBatchCaptureState()` before clearing credentials. Add this delegate callback:

```swift
func applicationWillTerminate(_ notification: Notification) {
    clearBatchCaptureState()
}
```

Also call `batchProgressUsesFloatingPanel = false` in `finishCancelledCapture()` and in `cancelCaptureForReplacementIfNeeded()`. This guarantees no queue, monitor, or batch-only output state can survive logout, quit, or cancellation.

- [ ] **Step 8: Run unit tests and compile the executable with warnings treated as errors**

Run:

```bash
swift test
swift build -Xswiftc -warnings-as-errors
```

Expected: all tests pass and the debug build completes with no warnings. Do not run `Scripts/build-app.sh --release` or any release packaging command.

- [ ] **Step 9: Commit runtime coordination**

```bash
git add Sources/main.swift Tests/CatGPTTests/BatchCaptureQueueTests.swift
git commit -m "feat: capture and send screenshot batches"
```

### Task 6: Document, inspect, and provide a debug-only acceptance build

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document the new shortcut and queue rules**

Add a concise Chinese section to `README.md` containing these exact facts:

```markdown
### 批量截图

- `⇧` 连按两下（可在“快捷键”设置中修改）会缓存一张立即截图，最多 8 张；图片只保存在内存中。
- 缓存后按“立即截图”快捷键会一次发送全部缓存图片，不会额外截取当前屏幕。
- 缓存期间按 `Esc` 会先取消正在采集的一张；没有在途采集时删除最后一张缓存。
- 未登录或未授予屏幕录制权限时，发送前的失败不会清空缓存；请求已经开始后的网络/服务端失败不会恢复缓存。
- “从屏幕选择”的默认快捷键为 `⌘E`。

环境变量：`SCREEN_LLM_BATCH_CAPTURE_HOTKEY`。
```

- [ ] **Step 2: Run repository integrity checks**

Run:

```bash
git diff --check
swift test
swift build -Xswiftc -warnings-as-errors
git status --short
```

Expected: no whitespace errors, test/build success, and only intentional batch-feature plus pre-existing settings-redesign changes present.

- [ ] **Step 3: Commit the documentation**

```bash
git add README.md
git commit -m "docs: explain batch screenshot workflow"
```

- [ ] **Step 4: Start a debug-only manual acceptance session**

Run: `CATGPT_OPEN_SETTINGS=shortcuts swift run CatGPT`

Expected manual checks:

1. The Shortcuts pane shows five shortcuts, with “从屏幕选择” set to `⌘E` and “批量截图” set to `⇧ double tap`.
2. Cache one through eight screenshots: only one-to-eight small six-point stars appear in the floating panel, with no cat paw or text.
3. Press Escape while a cache screenshot is in flight: existing stars remain; press Escape again when idle: only the newest star disappears.
4. Press immediate screenshot with cached images: stars disappear, the cat-paw sending/thinking state appears, and the model receives only the cached pictures.
5. Select Touch Bar output, repeat cache/send, and confirm cache/sending feedback remains in the floating panel while the final answer uses Touch Bar.
6. Log out with queued screenshots and restart: no stars or cached screenshots remain.

Stop after debug acceptance. Do not create a release build, archive, notarization artifact, or distribution package until the user explicitly authorizes it.
