# CatGPT Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 CatGPT 设置窗口重构为已确认的原生 macOS 分栏卡片界面，并以经过验证、按作用域应用的即时保存替代手动保存。

**Architecture:** 继续使用 AppKit 窗口承载 SwiftUI，但把窗口、状态模型、通用组件、五个页面和快捷键录制器拆为独立文件。`SettingsViewModel` 同时维护编辑草稿与最后应用草稿，文本输入经过 300 ms 去抖；`SettingsApplication` 在设置持久化之前只调用相关运行时动作，并在快捷键应用失败时恢复旧配置。

**Tech Stack:** Swift 5.9、SwiftUI、AppKit、ServiceManagement、Carbon、XCTest、Swift Package Manager，最低系统 macOS 14.0。

---

## 执行前基线

当前主工作区已有两项经过测试、尚未提交的 macOS 15 回答文字兼容修复：

- `Sources/main.swift`
- `Tests/CatGPTTests/ResultPanelCompatibilityTests.swift`

执行本计划前先把这两项作为独立提交保留下来；不得把 `.superpowers/` 视觉原型加入 Git。随后从包含该修复和本计划的提交创建独立工作树。建议工作树路径为 `.worktrees/settings-redesign`，分支为 `codex/settings-redesign`。

## 文件职责映射

- Modify: `Sources/Config.swift` — 让 `ConfigDraft` 可比较，供草稿和作用域测试使用。
- Create: `Sources/Settings/SettingsUpdateScope.swift` — 定义字段到运行时作用域的唯一映射。
- Create: `Sources/Settings/SettingsApplication.swift` — 负责合并面板几何、按作用域应用、持久化和失败回滚。
- Create: `Sources/Settings/SettingsSection.swift` — 设置分区的稳定标识、标题和 SF Symbol。
- Create: `Sources/Settings/SettingsViewModel.swift` — 草稿、即时保存、去抖、验证、行内错误和页面动作。
- Create: `Sources/Settings/SettingsWindowController.swift` — 标准窗口、位置恢复和生命周期。
- Create: `Sources/Settings/SettingsRootView.swift` — 紧凑分组侧栏和页面路由。
- Create: `Sources/Settings/SettingsComponents.swift` — 页面标题、分区、卡片、设置行、状态行和滑块行。
- Create: `Sources/Settings/ShortcutsSettingsView.swift` — 快捷键与固定截图区域。
- Create: `Sources/Settings/PromptSettingsView.swift` — 预设、默认提示词与系统指令。
- Create: `Sources/Settings/ModelSettingsView.swift` — 模型、Thinking 与输出。
- Create: `Sources/Settings/AppearanceSettingsView.swift` — 悬浮窗与 Touch Bar 外观。
- Create: `Sources/Settings/ServiceSettingsView.swift` — 账号、权限、运行和关于。
- Create: `Sources/Settings/ShortcutRecorder.swift` — `NSViewRepresentable` 和 AppKit 录制按钮。
- Modify: `Sources/main.swift` — 将统一 `reloadRuntime()` 拆为外观、快捷键、客户端和纯存储入口。
- Delete: `Sources/SettingsWindowController.swift` — 所有职责迁移完成后删除旧的 1100 行单文件实现。
- Create: `Tests/CatGPTTests/SettingsUpdateScopeTests.swift` — 字段到作用域的映射回归。
- Create: `Tests/CatGPTTests/SettingsViewModelTests.swift` — 即时保存、文本去抖和无效值行为。
- Create: `Tests/CatGPTTests/SettingsApplicationTests.swift` — 运行时隔离和失败回滚。
- Create: `Tests/CatGPTTests/ShortcutSettingsTests.swift` — 格式错误、重复和注册失败回退。

### Task 1: 固化现有 macOS 15 修复并建立隔离工作树

**Files:**
- Modify: `Sources/main.swift`
- Create: `Tests/CatGPTTests/ResultPanelCompatibilityTests.swift`
- Ignore: `.superpowers/`

- [ ] **Step 1: 复验已有兼容修复**

Run:

```bash
swift test --filter ResultPanelCompatibilityTests/testAnswerTextAdoptsDarkHUDMaterialAppearance
```

Expected: PASS；回答 `NSTextView` 的有效外观与 HUD `NSVisualEffectView` 一致。

- [ ] **Step 2: 单独提交兼容修复**

Run:

```bash
git add Sources/main.swift Tests/CatGPTTests/ResultPanelCompatibilityTests.swift
git diff --cached --check
git commit -m "fix: keep result text visible on macOS 15"
```

Expected: 提交只包含上述两个文件，`.superpowers/` 仍未跟踪。

- [ ] **Step 3: 创建隔离工作树**

Run:

```bash
git worktree add .worktrees/settings-redesign -b codex/settings-redesign
```

Expected: 新工作树从包含兼容修复、设计规格和本计划的提交开始，`git status --short` 为空。

### Task 2: 建立字段到更新作用域的单一映射

**Files:**
- Modify: `Sources/Config.swift:28`
- Create: `Sources/Settings/SettingsUpdateScope.swift`
- Test: `Tests/CatGPTTests/SettingsUpdateScopeTests.swift`

- [ ] **Step 1: 写作用域映射失败测试**

Create `Tests/CatGPTTests/SettingsUpdateScopeTests.swift`:

```swift
import XCTest
@testable import CatGPT

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
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `swift test --filter SettingsUpdateScopeTests`

Expected: FAIL，`SettingsUpdateScope` 尚不存在，`ConfigDraft` 也尚未声明 `Equatable`。

- [ ] **Step 3: 实现完整映射**

把 `Sources/Config.swift` 的声明改为：

```swift
struct ConfigDraft: Equatable {
```

Create `Sources/Settings/SettingsUpdateScope.swift`:

```swift
import Foundation

enum SettingsUpdateScope: Hashable {
    case appearance
    case shortcuts
    case client
    case storageOnly

    static func changed(from old: ConfigDraft, to new: ConfigDraft) -> Set<Self> {
        var result: Set<Self> = []

        if old.outputDisplayMode != new.outputDisplayMode
            || old.panelOpacity != new.panelOpacity
            || old.panelTextOpacity != new.panelTextOpacity
            || old.panelTextColor != new.panelTextColor
            || old.panelFontSize != new.panelFontSize
            || old.touchBarFontSize != new.touchBarFontSize
            || old.touchBarTextColor != new.touchBarTextColor
            || old.touchBarTextIntensity != new.touchBarTextIntensity
            || old.touchBarTextAlignment != new.touchBarTextAlignment {
            result.insert(.appearance)
        }

        if old.hotKeyText != new.hotKeyText
            || old.selectionHotKeyText != new.selectionHotKeyText
            || old.panelHotKeyText != new.panelHotKeyText {
            result.insert(.shortcuts)
        }

        if old.model != new.model
            || old.thinkingEnabled != new.thinkingEnabled
            || old.reasoningEffort != new.reasoningEffort
            || old.reasoningSummary != new.reasoningSummary
            || old.textVerbosity != new.textVerbosity
            || old.serviceTier != new.serviceTier
            || old.maxOutputTokens != new.maxOutputTokens
            || old.prompt != new.prompt
            || old.instructions != new.instructions
            || old.maxImageEdge != new.maxImageEdge {
            result.insert(.client)
        }

        if old.captureRegionEnabled != new.captureRegionEnabled
            || old.captureRegionX != new.captureRegionX
            || old.captureRegionY != new.captureRegionY
            || old.captureRegionWidth != new.captureRegionWidth
            || old.captureRegionHeight != new.captureRegionHeight
            || old.panelWidth != new.panelWidth
            || old.panelHeight != new.panelHeight
            || old.panelOriginX != new.panelOriginX
            || old.panelOriginY != new.panelOriginY {
            result.insert(.storageOnly)
        }

        return result
    }
}
```

- [ ] **Step 4: 验证 GREEN 并提交**

Run:

```bash
swift test --filter SettingsUpdateScopeTests
git add Sources/Config.swift Sources/Settings/SettingsUpdateScope.swift Tests/CatGPTTests/SettingsUpdateScopeTests.swift
git commit -m "refactor: classify settings update scopes"
```

Expected: 5 个测试全部 PASS。

### Task 3: 用双草稿模型实现即时保存、去抖和行内验证

**Files:**
- Create: `Sources/Settings/SettingsSection.swift`
- Create: `Sources/Settings/SettingsViewModel.swift`
- Test: `Tests/CatGPTTests/SettingsViewModelTests.swift`
- Test: `Tests/CatGPTTests/ShortcutSettingsTests.swift`
- Modify: `Sources/SettingsWindowController.swift` — 删除旧 `SettingsState`、`SettingsViewModel`、关窗确认和 `SaveBar`，页面继续通过新模型编译。

- [ ] **Step 1: 写即时保存和去抖失败测试**

Create `Tests/CatGPTTests/SettingsViewModelTests.swift`:

```swift
import XCTest
@testable import CatGPT

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testImmediateChangeAppliesOnlyItsScope() throws {
        let initial = ConfigDraft.load()
        var calls: [(ConfigDraft, SettingsUpdateScope)] = []
        let model = makeModel(initial: initial) { calls.append(($0, $1)) }

        model.set(0.52, at: \ConfigDraft.panelOpacity, scope: .appearance)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.1, .appearance)
        XCTAssertEqual(model.lastAppliedDraft.panelOpacity, 0.52)
    }

    func testTextChangeWaitsForDebounceThenApplies() async throws {
        let initial = ConfigDraft.load()
        let applied = expectation(description: "debounced apply")
        var calls: [(ConfigDraft, SettingsUpdateScope)] = []
        let model = makeModel(initial: initial, debounceNanoseconds: 10_000_000) {
            calls.append(($0, $1))
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
        let model = makeModel(initial: initial, debounceNanoseconds: 1_000_000) { _, _ in calls += 1 }

        model.setText("   ", at: \ConfigDraft.model, field: .model)
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(model.draft.model, "   ")
        XCTAssertEqual(model.lastAppliedDraft.model, initial.model)
        XCTAssertEqual(model.error(for: .model), "模型不能为空。")
        XCTAssertEqual(calls, 0)
    }

    private func makeModel(
        initial: ConfigDraft,
        debounceNanoseconds: UInt64 = 300_000_000,
        apply: @escaping (ConfigDraft, SettingsUpdateScope) throws -> Void
    ) -> SettingsViewModel {
        SettingsViewModel(
            initialDraft: initial,
            stateProvider: { .init(signedIn: false, accountId: "", screenPermission: false, statusText: "就绪", hotKeyStatus: "已启用") },
            applyDraft: apply,
            debounceNanoseconds: debounceNanoseconds
        )
    }
}
```

- [ ] **Step 2: 写快捷键恢复失败测试**

Create `Tests/CatGPTTests/ShortcutSettingsTests.swift`:

```swift
import XCTest
@testable import CatGPT

@MainActor
final class ShortcutSettingsTests: XCTestCase {
    func testInvalidShortcutRestoresLastAppliedValue() {
        let initial = ConfigDraft.load()
        var applyCount = 0
        let model = makeModel(initial: initial) { _, _ in applyCount += 1 }

        model.setShortcut("j", at: \ConfigDraft.hotKeyText, field: .captureShortcut)

        XCTAssertEqual(model.draft.hotKeyText, initial.hotKeyText)
        XCTAssertNotNil(model.error(for: .captureShortcut))
        XCTAssertEqual(applyCount, 0)
    }

    func testDuplicateShortcutRestoresLastAppliedValue() {
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in XCTFail("不应应用重复快捷键") }

        model.setShortcut(initial.selectionHotKeyText, at: \ConfigDraft.hotKeyText, field: .captureShortcut)

        XCTAssertEqual(model.draft.hotKeyText, initial.hotKeyText)
        XCTAssertEqual(model.error(for: .captureShortcut), "不能与其他 CatGPT 快捷键重复。")
    }

    func testRegistrationFailureRestoresLastAppliedValue() {
        struct RegistrationError: LocalizedError { var errorDescription: String? { "快捷键已被其他应用占用。" } }
        let initial = ConfigDraft.load()
        let model = makeModel(initial: initial) { _, _ in throw RegistrationError() }

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
            stateProvider: { .init(signedIn: false, accountId: "", screenPermission: false, statusText: "就绪", hotKeyStatus: "已启用") },
            applyDraft: apply
        )
    }
}
```

- [ ] **Step 3: 运行测试确认 RED**

Run: `swift test --filter 'SettingsViewModelTests|ShortcutSettingsTests'`

Expected: FAIL，新模型 API 尚不存在。

- [ ] **Step 4: 实现模型的核心 API**

先把旧文件中的分区枚举替换为 `Sources/Settings/SettingsSection.swift`：

```swift
import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case shortcuts
    case prompt
    case model
    case appearance
    case service

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortcuts: return "快捷键"
        case .prompt: return "提示词"
        case .model: return "模型"
        case .appearance: return "外观"
        case .service: return "服务"
        }
    }

    var symbolName: String {
        switch self {
        case .shortcuts: return "keyboard"
        case .prompt: return "text.alignleft"
        case .model: return "brain.head.profile"
        case .appearance: return "macwindow"
        case .service: return "person.crop.circle"
        }
    }
}
```

然后 Create `Sources/Settings/SettingsViewModel.swift`，用以下状态与更新 API 替换约 30 个独立 `@Published` 字段：

```swift
import AppKit
import Foundation
import ServiceManagement
import SwiftUI

struct SettingsState: Equatable {
    let signedIn: Bool
    let accountId: String
    let screenPermission: Bool
    let statusText: String
    let hotKeyStatus: String
}

enum SettingsField: Hashable {
    case model, prompt, instructions
    case captureShortcut, selectionShortcut, panelShortcut
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .shortcuts
    @Published private(set) var draft: ConfigDraft
    @Published private(set) var lastAppliedDraft: ConfigDraft
    @Published private(set) var state: SettingsState
    @Published private(set) var fieldErrors: [SettingsField: String] = [:]
    @Published var presets: [PromptPreset]
    @Published var newPresetName = ""
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginError: String?

    let launchAtLoginAvailable = Bundle.main.bundlePath.hasSuffix(".app")

    private let draftProvider: () -> ConfigDraft
    private let stateProvider: () -> SettingsState
    private let applyDraft: (ConfigDraft, SettingsUpdateScope) throws -> Void
    private let onLogin: () -> Void
    private let onLogout: () -> Void
    private let onPermission: () -> Void
    private let debounceNanoseconds: UInt64
    private var pendingTextTasks: [SettingsField: Task<Void, Never>] = [:]

    init(
        initialDraft: ConfigDraft,
        draftProvider: (() -> ConfigDraft)? = nil,
        stateProvider: @escaping () -> SettingsState,
        applyDraft: @escaping (ConfigDraft, SettingsUpdateScope) throws -> Void,
        onLogin: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {},
        onPermission: @escaping () -> Void = {},
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        draft = initialDraft
        lastAppliedDraft = initialDraft
        self.draftProvider = draftProvider ?? { initialDraft }
        self.stateProvider = stateProvider
        self.applyDraft = applyDraft
        self.onLogin = onLogin
        self.onLogout = onLogout
        self.onPermission = onPermission
        self.debounceNanoseconds = debounceNanoseconds
        state = stateProvider()
        presets = PromptPresetStore.load()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func binding<Value: Equatable>(
        _ keyPath: WritableKeyPath<ConfigDraft, Value>,
        scope: SettingsUpdateScope
    ) -> Binding<Value> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.set($0, at: keyPath, scope: scope) }
        )
    }

    func set<Value: Equatable>(
        _ value: Value,
        at keyPath: WritableKeyPath<ConfigDraft, Value>,
        scope: SettingsUpdateScope
    ) {
        guard draft[keyPath: keyPath] != value else { return }
        draft[keyPath: keyPath] = value
        var candidate = lastAppliedDraft
        candidate[keyPath: keyPath] = value
        do {
            try applyDraft(candidate, scope)
            lastAppliedDraft = candidate
        } catch {
            draft[keyPath: keyPath] = lastAppliedDraft[keyPath: keyPath]
        }
    }

    func textBinding(
        _ keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) -> Binding<String> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.setText($0, at: keyPath, field: field) }
        )
    }

    func setText(
        _ value: String,
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        draft[keyPath: keyPath] = value
        fieldErrors[field] = nil
        pendingTextTasks[field]?.cancel()
        pendingTextTasks[field] = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            applyText(at: keyPath, field: field)
            pendingTextTasks[field] = nil
        }
    }

    private func applyText(
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        let value = draft[keyPath: keyPath]
        if field == .model && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors[field] = "模型不能为空。"
            return
        }
        var candidate = lastAppliedDraft
        candidate[keyPath: keyPath] = field == .model
            ? value.trimmingCharacters(in: .whitespacesAndNewlines)
            : value
        do {
            try applyDraft(candidate, .client)
            lastAppliedDraft = candidate
            draft[keyPath: keyPath] = candidate[keyPath: keyPath]
            fieldErrors[field] = nil
        } catch {
            fieldErrors[field] = error.localizedDescription
        }
    }

    func shortcutBinding(
        _ keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) -> Binding<String> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.setShortcut($0, at: keyPath, field: field) }
        )
    }

    func setShortcut(
        _ value: String,
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        do {
            _ = try Shortcut.parse(value)
            var candidate = lastAppliedDraft
            candidate[keyPath: keyPath] = value
            let values = [candidate.hotKeyText, candidate.selectionHotKeyText, candidate.panelHotKeyText]
            let canonical = try values.map { try Shortcut.parse($0).displayText }
            guard Set(canonical).count == canonical.count else {
                throw SettingsValidationError.duplicateShortcut
            }
            try applyDraft(candidate, .shortcuts)
            draft[keyPath: keyPath] = value
            lastAppliedDraft = candidate
            fieldErrors[field] = nil
        } catch {
            draft[keyPath: keyPath] = lastAppliedDraft[keyPath: keyPath]
            fieldErrors[field] = error.localizedDescription
        }
    }

    func error(for field: SettingsField) -> String? { fieldErrors[field] }
}

enum SettingsValidationError: LocalizedError {
    case duplicateShortcut

    var errorDescription: String? {
        switch self {
        case .duplicateShortcut: return "不能与其他 CatGPT 快捷键重复。"
        }
    }
}
```

在旧控制器中把模型初始化替换为下面的过渡接线；Task 4 再把兼容 `onSave` 包装升级为真正的作用域回调：

```swift
let initialDraft = draftProvider()
model = SettingsViewModel(
    initialDraft: initialDraft,
    draftProvider: draftProvider,
    stateProvider: stateProvider,
    applyDraft: { candidate, _ in onSave(candidate) },
    onLogin: onLogin,
    onLogout: onLogout,
    onPermission: onPermission
)
```

同时删除旧 `SettingsState`、旧 `SettingsViewModel`、整个 `NSWindowDelegate` 关窗确认 extension、`window.delegate = self`、`SaveBar` 类型，以及根视图的 `.safeAreaInset`。即时保存后这些入口不能继续存在。

在同一类型中加入以下完整页面动作；它们是旧模型行为的即时保存版本：

```swift
func reload() {
    state = stateProvider()
    presets = PromptPresetStore.load()
    launchAtLogin = SMAppService.mainApp.status == .enabled
    guard pendingTextTasks.isEmpty, fieldErrors.isEmpty else { return }
    let latest = draftProvider()
    draft = latest
    lastAppliedDraft = latest
}

func resetShortcuts() {
    var candidate = lastAppliedDraft
    candidate.hotKeyText = ConfigDraft.defaultHotKey
    candidate.selectionHotKeyText = ConfigDraft.defaultSelectionHotKey
    candidate.panelHotKeyText = ConfigDraft.defaultPanelHotKey
    do {
        try applyDraft(candidate, .shortcuts)
        draft.hotKeyText = candidate.hotKeyText
        draft.selectionHotKeyText = candidate.selectionHotKeyText
        draft.panelHotKeyText = candidate.panelHotKeyText
        lastAppliedDraft = candidate
        fieldErrors[.captureShortcut] = nil
        fieldErrors[.selectionShortcut] = nil
        fieldErrors[.panelShortcut] = nil
    } catch {
        fieldErrors[.captureShortcut] = error.localizedDescription
    }
}

func setCaptureRegion(_ rect: CGRect) {
    var candidate = lastAppliedDraft
    candidate.captureRegionEnabled = true
    candidate.captureRegionX = rect.origin.x.rounded()
    candidate.captureRegionY = rect.origin.y.rounded()
    candidate.captureRegionWidth = rect.width.rounded()
    candidate.captureRegionHeight = rect.height.rounded()
    do {
        try applyDraft(candidate, .storageOnly)
        draft.captureRegionEnabled = candidate.captureRegionEnabled
        draft.captureRegionX = candidate.captureRegionX
        draft.captureRegionY = candidate.captureRegionY
        draft.captureRegionWidth = candidate.captureRegionWidth
        draft.captureRegionHeight = candidate.captureRegionHeight
        lastAppliedDraft = candidate
    } catch {
        draft.captureRegionEnabled = lastAppliedDraft.captureRegionEnabled
    }
}

func chooseCaptureRegion() {
    Task { @MainActor in
        let previousWindow = NSApp.keyWindow
        previousWindow?.orderOut(nil)
        try? await Task.sleep(nanoseconds: 120_000_000)
        defer {
            NSApp.activate(ignoringOtherApps: true)
            previousWindow?.makeKeyAndOrderFront(nil)
        }
        guard let rect = try? await SelectionCapture.selectRegion() else { return }
        setCaptureRegion(rect)
    }
}

func login() { onLogin() }

func logout() {
    onLogout()
    reload()
}

func applyPreset(_ preset: PromptPreset) {
    setText(preset.text, at: \ConfigDraft.prompt, field: .prompt)
}

func addPreset() {
    let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    presets.append(PromptPreset(id: UUID(), name: name, text: draft.prompt))
    PromptPresetStore.save(presets)
    newPresetName = ""
}

func deletePreset(_ preset: PromptPreset) {
    presets.removeAll { $0.id == preset.id }
    PromptPresetStore.save(presets)
}

func setLaunchAtLogin(_ enabled: Bool) {
    do {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        launchAtLogin = enabled
        launchAtLoginError = nil
    } catch {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        launchAtLoginError = error.localizedDescription
    }
}

func requestScreenPermission() {
    onPermission()
    reload()
}

var accountText: String {
    state.signedIn ? "已登录 · \(state.accountId.isEmpty ? "Codex" : state.accountId)" : "未登录"
}

var permissionText: String {
    state.screenPermission ? "屏幕录制已授权" : "屏幕录制未授权"
}
```

- [ ] **Step 5: 验证测试和现有代码编译**

在旧页面临时存续期间，按下面的唯一映射替换旧属性；不得重新引入独立 `@Published` 副本：

- 文本：`modelName`、`prompt`、`instructions` 分别改为 `textBinding(\ConfigDraft.model, field: .model)`、`textBinding(\ConfigDraft.prompt, field: .prompt)`、`textBinding(\ConfigDraft.instructions, field: .instructions)`。
- 快捷键：三个字符串分别改为 `shortcutBinding`，字段错误分别对应 `.captureShortcut`、`.selectionShortcut`、`.panelShortcut`。
- 客户端即时值依次改为 `binding(\ConfigDraft.thinkingEnabled, scope: .client)`、`binding(\ConfigDraft.reasoningEffort, scope: .client)`、`binding(\ConfigDraft.reasoningSummary, scope: .client)`、`binding(\ConfigDraft.textVerbosity, scope: .client)`、`binding(\ConfigDraft.serviceTier, scope: .client)`、`binding(\ConfigDraft.maxOutputTokens, scope: .client)` 和 `binding(\ConfigDraft.maxImageEdge, scope: .client)`。
- 外观即时值依次使用 `outputDisplayMode`、`panelOpacity`、`panelTextOpacity`、`panelTextColor`、`panelFontSize`、`touchBarFontSize`、`touchBarTextColor`、`touchBarTextIntensity`、`touchBarTextAlignment` 的 key path，并统一传 `.appearance`；只读显示值从 `model.draft` 读取。
- 存储即时值依次使用 `captureRegionEnabled`、`captureRegionX`、`captureRegionY`、`captureRegionWidth`、`captureRegionHeight` 的 key path，并统一传 `.storageOnly`；临时 `regionField` 接收 `Binding<Double>`。
- 运行状态和页面动作继续读取 `state`、`presets`、`launchAtLogin`、`launchAtLoginError`，并调用新模型中同名动作。

Run:

```bash
swift test --filter 'SettingsViewModelTests|ShortcutSettingsTests'
swift build
```

Expected: 两组新测试全部 PASS；旧页面在替换为 `model.binding`、`model.textBinding` 和 `model.shortcutBinding` 后编译通过。

- [ ] **Step 6: 提交双草稿状态模型**

Run:

```bash
git add Sources/Settings/SettingsSection.swift Sources/Settings/SettingsViewModel.swift Sources/SettingsWindowController.swift Tests/CatGPTTests/SettingsViewModelTests.swift Tests/CatGPTTests/ShortcutSettingsTests.swift
git commit -m "feat: apply settings changes immediately"
```

### Task 4: 建立可测试的按作用域运行时应用器

**Files:**
- Create: `Sources/Settings/SettingsApplication.swift`
- Modify: `Sources/main.swift:289-405,664-706`
- Test: `Tests/CatGPTTests/SettingsApplicationTests.swift`

- [ ] **Step 1: 写隔离和回滚失败测试**

Create `Tests/CatGPTTests/SettingsApplicationTests.swift`:

```swift
import XCTest
@testable import CatGPT

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

    func testShortcutChangeDoesNotTouchAppearanceOrClient() throws {
        var current = ConfigDraft.load()
        var events: [String] = []
        let application = SettingsApplication(
            persist: { _ in events.append("persist") },
            appearance: { _ in events.append("appearance") },
            shortcuts: { _ in events.append("shortcuts") },
            client: { _ in events.append("client") }
        )
        var proposed = current
        proposed.hotKeyText = "cmd+shift+j"

        try application.apply(proposed, to: &current, scope: .shortcuts)

        XCTAssertEqual(events, ["shortcuts", "persist"])
    }

    func testClientChangeDoesNotTouchAppearanceOrShortcuts() throws {
        var current = ConfigDraft.load()
        var events: [String] = []
        let application = SettingsApplication(
            persist: { _ in events.append("persist") },
            appearance: { _ in events.append("appearance") },
            shortcuts: { _ in events.append("shortcuts") },
            client: { _ in events.append("client") }
        )
        var proposed = current
        proposed.prompt += " 更简洁"

        try application.apply(proposed, to: &current, scope: .client)

        XCTAssertEqual(events, ["client", "persist"])
    }

    func testShortcutFailureRestoresPreviousRegistrationAndDraft() {
        struct Conflict: Error {}
        var current = ConfigDraft.load()
        let previous = current
        var registered: [String] = []
        let application = SettingsApplication(
            persist: { _ in XCTFail("失败配置不应持久化") },
            appearance: { _ in },
            shortcuts: {
                registered.append($0.hotKeyText)
                if $0.hotKeyText != previous.hotKeyText { throw Conflict() }
            },
            client: { _ in }
        )
        var proposed = current
        proposed.hotKeyText = "cmd+shift+j"

        XCTAssertThrowsError(try application.apply(proposed, to: &current, scope: .shortcuts))
        XCTAssertEqual(current, previous)
        XCTAssertEqual(registered, ["cmd+shift+j", previous.hotKeyText])
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
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `swift test --filter SettingsApplicationTests`

Expected: FAIL，`SettingsApplication` 尚不存在。

- [ ] **Step 3: 实现作用域应用器**

Create `Sources/Settings/SettingsApplication.swift`:

```swift
import Foundation

struct SettingsApplication {
    let persist: (ConfigDraft) -> Void
    let appearance: (ConfigDraft) throws -> Void
    let shortcuts: (ConfigDraft) throws -> Void
    let client: (ConfigDraft) throws -> Void

    func apply(
        _ proposed: ConfigDraft,
        to current: inout ConfigDraft,
        scope: SettingsUpdateScope
    ) throws {
        let previous = current
        var merged = proposed
        merged.panelWidth = previous.panelWidth
        merged.panelHeight = previous.panelHeight
        merged.panelOriginX = previous.panelOriginX
        merged.panelOriginY = previous.panelOriginY

        do {
            switch scope {
            case .appearance:
                try appearance(merged)
            case .shortcuts:
                try shortcuts(merged)
            case .client:
                try client(merged)
            case .storageOnly:
                break
            }
            persist(merged)
            current = merged
        } catch {
            if scope == .shortcuts {
                try? shortcuts(previous)
            }
            current = previous
            throw error
        }
    }
}
```

- [ ] **Step 4: 把 AppDelegate 接到作用域入口**

在 `Sources/main.swift` 中：

1. 把 `applyPanelSettings()` 改为 `applyPanelSettings(from candidate: ConfigDraft)`，所有配置值从 `candidate` 读取。
2. 把 `registerHotKeys()` 改为 `registerHotKeys(from candidate: ConfigDraft) throws`；任何一个注册失败时抛出包含失败名称的 `AppError.hotKey`，不再把部分失败吞掉。
3. 把 `reloadRuntime()` 中创建 `LLMClient` 的部分提取为 `rebuildClient(from candidate: ConfigDraft)`；无登录凭证时保持现有状态提示，但不把合法设置视为保存失败。
4. 保留 `reloadRuntime()` 作为启动、登录和登出时的全量入口，依次调用三个提取后的函数。
5. 用下列入口替换 `saveDraftFromSettings(_:)`：

```swift
private func applyDraftFromSettings(
    _ proposed: ConfigDraft,
    scope: SettingsUpdateScope
) throws {
    let application = SettingsApplication(
        persist: { $0.save() },
        appearance: { [weak self] in self?.applyPanelSettings(from: $0) },
        shortcuts: { [weak self] candidate in
            guard let self else { return }
            try self.registerHotKeys(from: candidate)
        },
        client: { [weak self] in self?.rebuildClient(from: $0) }
    )
    try application.apply(proposed, to: &draft, scope: scope)
}
```

6. `SettingsWindowController` 的保存回调改为 `onApply: (ConfigDraft, SettingsUpdateScope) throws -> Void`，并传入 `applyDraftFromSettings`。
7. 菜单栏 `selectPreset(_:)` 构造新的 `proposed` 草稿后调用 `applyDraftFromSettings(proposed, scope: .client)`，不再调用全量 `reloadRuntime()`；失败时沿用当前状态提示。

- [ ] **Step 5: 验证作用域行为并提交**

Run:

```bash
swift test --filter SettingsApplicationTests
swift test
git add Sources/main.swift Sources/Settings/SettingsApplication.swift Sources/SettingsWindowController.swift Tests/CatGPTTests/SettingsApplicationTests.swift
git commit -m "refactor: isolate settings runtime updates"
```

Expected: 新测试全部 PASS，完整测试无回归。

### Task 5: 搭建新窗口、侧栏和卡片视觉系统

**Files:**
- Create: `Sources/Settings/SettingsWindowController.swift`
- Create: `Sources/Settings/SettingsRootView.swift`
- Create: `Sources/Settings/SettingsComponents.swift`
- Create: `Sources/Settings/ShortcutRecorder.swift`
- Modify: `Sources/SettingsWindowController.swift` — 仅暂留尚未迁移的五个旧页面。

- [ ] **Step 1: 创建标准设置窗口**

`Sources/Settings/SettingsWindowController.swift` 使用以下完整实现：

```swift
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: SettingsViewModel

    init(
        draftProvider: @escaping () -> ConfigDraft,
        stateProvider: @escaping () -> SettingsState,
        onApply: @escaping (ConfigDraft, SettingsUpdateScope) throws -> Void,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onPermission: @escaping () -> Void
    ) {
        model = SettingsViewModel(
            initialDraft: draftProvider(),
            draftProvider: draftProvider,
            stateProvider: stateProvider,
            applyDraft: onApply,
            onLogin: onLogin,
            onLogout: onLogout,
            onPermission: onPermission
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CatGPT 设置"
        window.minSize = NSSize(width: 760, height: 520)
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false

        let hosting = NSHostingController(rootView: SettingsRootView(model: model))
        if #available(macOS 14.0, *) {
            hosting.sceneBridgingOptions = [.toolbars]
        }
        window.contentViewController = hosting

        super.init(window: window)

        if !window.setFrameUsingName("CatGPTSettings") {
            window.center()
        }
        window.setFrameAutosaveName("CatGPTSettings")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        model.reload()
    }

    func reload() { model.reload() }

    func select(sectionRaw: String) {
        if let section = SettingsSection(rawValue: sectionRaw) {
            model.selectedSection = section
        }
    }
}
```

旧文件中对应的控制器、根视图和录制器定义在新文件编译通过后删除，只保留尚未迁移的页面。

- [ ] **Step 2: 创建分组紧凑侧栏**

Create `Sources/Settings/SettingsRootView.swift`，定义顺序为“工作流：快捷键、提示词；智能：模型；应用：外观、服务”：

```swift
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: selectionBinding) {
                Section("工作流") {
                    SidebarRow(section: .shortcuts).tag(SettingsSection.shortcuts)
                    SidebarRow(section: .prompt).tag(SettingsSection.prompt)
                }
                Section("智能") {
                    SidebarRow(section: .model).tag(SettingsSection.model)
                }
                Section("应用") {
                    SidebarRow(section: .appearance).tag(SettingsSection.appearance)
                    SidebarRow(section: .service).tag(SettingsSection.service)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 148, ideal: 160, max: 176)
        } detail: {
            detailView
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var selectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { model.selectedSection },
            set: { if let value = $0 { model.selectedSection = value } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSection {
        case .shortcuts: ShortcutsPane(model: model)
        case .prompt: PromptPane(model: model)
        case .model: ModelPane(model: model)
        case .appearance: AppearancePane(model: model)
        case .service: ServicePane(model: model)
        }
    }
}

private struct SidebarRow: View {
    let section: SettingsSection

    var body: some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.symbolName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
        }
    }
}
```

`SidebarRow` 使用单色 SF Symbol 与系统强调色，不绘制彩色图标磁贴；侧栏顶部不得添加 “CatGPT” 文本。

- [ ] **Step 3: 创建共享卡片组件**

Create `Sources/Settings/SettingsComponents.swift`，实现这些确定接口：

```swift
import AppKit
import SwiftUI

struct SettingsPage<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.system(size: 21, weight: .semibold))
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    accessory
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

extension SettingsPage where Accessory == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) { content }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let control: Control

    init(_ title: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct SettingsDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

struct InlineSettingsMessage: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
    }
}
```

- [ ] **Step 4: 提取快捷键录制器并建立辅助功能**

把旧文件当前 `952-1163` 行的 `ShortcutRecorder` 与 `ShortcutCaptureButton` 原样迁入 `Sources/Settings/ShortcutRecorder.swift`；`SettingsSection` 使用 Task 3 已创建的文件，不复制旧枚举。录制器继续设置 `accessibilityLabel`；开始录制显示“按下快捷键…”，Escape 取消并恢复旧值。

给 `ShortcutCaptureButton` 增加窗口失焦清理，避免录制 monitor 在窗口关闭或切换应用后残留：

```swift
private var resignKeyObserver: NSObjectProtocol?

override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let resignKeyObserver {
        NotificationCenter.default.removeObserver(resignKeyObserver)
    }
    resignKeyObserver = window.map { window in
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.cancelRecording() }
    }
}

deinit {
    if let resignKeyObserver {
        NotificationCenter.default.removeObserver(resignKeyObserver)
    }
    stopRecording()
}
```

- [ ] **Step 5: 编译视觉骨架并提交**

Run:

```bash
swift build
CATGPT_OPEN_SETTINGS=shortcuts swift run CatGPT
```

Expected: 窗口标题固定为“CatGPT 设置”；侧栏没有品牌标题，宽度约 160 pt；详情内容随窗口铺满且无底部保存栏。关闭应用后提交：

```bash
git add Sources/Settings Sources/SettingsWindowController.swift
git commit -m "feat: add native settings window shell"
```

### Task 6: 重做快捷键和提示词页面

**Files:**
- Create: `Sources/Settings/ShortcutsSettingsView.swift`
- Create: `Sources/Settings/PromptSettingsView.swift`
- Modify: `Sources/Settings/SettingsRootView.swift`
- Modify: `Sources/SettingsWindowController.swift` — 删除已迁移的两个旧页面。

- [ ] **Step 1: 实现快捷键页面**

使用下列标题区，第一张 `SettingsGroup("全局操作")` 按顺序放置立即截图、框选截图、显示/隐藏结果：

```swift
SettingsPage(
    title: "快捷键",
    subtitle: "设置随时可用的全局操作与固定截图区域。",
    accessory: {
        Button("恢复默认快捷键") { model.resetShortcuts() }
            .buttonStyle(.borderless)
    }
) {
    VStack(spacing: 24) {
        SettingsGroup("全局操作") {
            shortcutRow(
                title: "立即截图",
                subtitle: "静默截取全屏；开启固定区域后自动裁切",
                keyPath: \ConfigDraft.hotKeyText,
                field: .captureShortcut
            )
            SettingsDivider()
            shortcutRow(
                title: "框选截图",
                subtitle: "拖动选取屏幕区域后发送",
                keyPath: \ConfigDraft.selectionHotKeyText,
                field: .selectionShortcut
            )
            SettingsDivider()
            shortcutRow(
                title: "显示/隐藏结果",
                subtitle: "呼出或隐藏上一次回答",
                keyPath: \ConfigDraft.panelHotKeyText,
                field: .panelShortcut
            )
        }

        SettingsGroup("固定截图区域") {
            SettingsRow("启用固定区域", subtitle: "立即截图时只发送保存的区域") {
                Toggle("", isOn: model.binding(\ConfigDraft.captureRegionEnabled, scope: .storageOnly))
                    .labelsHidden()
            }
            SettingsDivider()
            SettingsRow("区域坐标", subtitle: regionSummary) {
                HStack(spacing: 6) {
                    coordinateField("X", \ConfigDraft.captureRegionX)
                    coordinateField("Y", \ConfigDraft.captureRegionY)
                    coordinateField("宽", \ConfigDraft.captureRegionWidth)
                    coordinateField("高", \ConfigDraft.captureRegionHeight)
                }
            }
            .disabled(!model.draft.captureRegionEnabled)
            SettingsDivider()
            SettingsRow("从屏幕选择", subtitle: "框选一次并立即保存") {
                Button("选择区域…") { model.chooseCaptureRegion() }
            }
        }
    }
}
```

其中 `shortcutRow` 每行右侧使用：

```swift
ShortcutRecorder(
    text: model.shortcutBinding(\ConfigDraft.hotKeyText, field: .captureShortcut),
    accessibilityLabel: "立即截图快捷键"
)
.frame(width: 158, height: 24)
```

同一页面加入以下完整辅助实现：

```swift
@ViewBuilder
private func shortcutRow(
    title: String,
    subtitle: String,
    keyPath: WritableKeyPath<ConfigDraft, String>,
    field: SettingsField
) -> some View {
    SettingsRow(title, subtitle: subtitle) {
        ShortcutRecorder(
            text: model.shortcutBinding(keyPath, field: field),
            accessibilityLabel: "\(title)快捷键"
        )
        .frame(width: 158, height: 24)
    }
    if let error = model.error(for: field) {
        InlineSettingsMessage(text: error, systemImage: "exclamationmark.triangle.fill", color: .red)
    }
}

private func coordinateField(
    _ label: String,
    _ keyPath: WritableKeyPath<ConfigDraft, Double>
) -> some View {
    HStack(spacing: 3) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        TextField("0", value: model.binding(keyPath, scope: .storageOnly), format: .number.grouping(.never))
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .frame(width: 54)
    }
}

private var regionSummary: String {
    let value = model.draft
    return "X \(Int(value.captureRegionX)) · Y \(Int(value.captureRegionY)) · \(Int(value.captureRegionWidth)) × \(Int(value.captureRegionHeight))"
}
```

其他两行分别绑定 `selectionHotKeyText/.selectionShortcut` 和 `panelHotKeyText/.panelShortcut`。每个录制器下方若 `model.error(for:)` 非空，显示红色 `InlineSettingsMessage`。

第二张 `SettingsGroup("固定截图区域")` 包含：启用 Toggle、区域坐标摘要、从屏幕选择按钮。坐标四个数字字段分别使用 `.storageOnly` binding；选择成功后通过一次 `model.setCaptureRegion(_:)` 更新五个相关字段，不能连续触发五次保存。

- [ ] **Step 2: 实现提示词页面**

使用 `SettingsPage(title: "提示词", subtitle: "管理截图分析时发送给模型的默认内容。")`，并实现三张卡片：

1. `预设`：逐行显示名称和单行摘要，尾部按钮“使用”和垃圾桶；底部一行包含预设名称字段与“存为预设”。
2. `默认提示词`：`TextEditor(text: model.textBinding(\ConfigDraft.prompt, field: .prompt))`，最小高度 120。
3. `系统指令`：`TextEditor(text: model.textBinding(\ConfigDraft.instructions, field: .instructions))`，最小高度 88。

应用预设必须调用 `model.setText(preset.text, at: \ConfigDraft.prompt, field: .prompt)`，从而沿用 300 ms 去抖和客户端作用域；预设本身的添加、删除继续直接写 `PromptPresetStore`。

- [ ] **Step 3: 路由到新页面并验证**

在 `SettingsRootView.detailView` 中把 `.shortcuts` 和 `.prompt` 分别切到 `ShortcutsSettingsView(model:)` 与 `PromptSettingsView(model:)`。

Run:

```bash
swift build
CATGPT_OPEN_SETTINGS=shortcuts swift run CatGPT
CATGPT_OPEN_SETTINGS=prompt swift run CatGPT
```

Expected: 卡片铺满详情宽度；快捷键错误显示在对应行；提示词停止输入约 300 ms 后应用；没有保存按钮。

- [ ] **Step 4: 提交两页改造**

Run:

```bash
git add Sources/Settings Sources/SettingsWindowController.swift
git commit -m "feat: redesign workflow settings"
```

### Task 7: 重做模型页面并覆盖输入边界

**Files:**
- Create: `Sources/Settings/ModelSettingsView.swift`
- Modify: `Sources/Settings/SettingsRootView.swift`
- Modify: `Sources/SettingsWindowController.swift` — 删除旧模型页。
- Modify: `Tests/CatGPTTests/SettingsViewModelTests.swift`

- [ ] **Step 1: 增加数字归一化测试**

在 `SettingsViewModelTests` 增加：

```swift
func testImageEdgeIsClampedBeforeImmediateApply() {
    let initial = ConfigDraft.load()
    var applied: ConfigDraft?
    let model = makeModel(initial: initial) { draft, _ in applied = draft }

    model.setMaxImageEdge(320)

    XCTAssertEqual(applied?.maxImageEdge, 640)
    XCTAssertEqual(model.draft.maxImageEdge, 640)
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `swift test --filter SettingsViewModelTests/testImageEdgeIsClampedBeforeImmediateApply`

Expected: FAIL，因为 `setMaxImageEdge(_:)` 尚不存在。

- [ ] **Step 3: 实现数字边界**

给模型新增以下方法；页面不得直接把无效数字传给通用 `set`：

```swift
func setMaxImageEdge(_ value: Int) {
    set(max(640, value), at: \ConfigDraft.maxImageEdge, scope: .client)
}

func setMaxOutputTokens(_ value: Int) {
    set(max(0, value), at: \ConfigDraft.maxOutputTokens, scope: .client)
}
```

- [ ] **Step 4: 实现模型和输出卡片**

`ModelSettingsView` 使用标题“模型”和说明“配置 Codex 模型、推理强度与回答输出。”，包含：

- `模型` 卡片：模型 ID 文本框与建议模型 Menu、Thinking Toggle、智能程度 segmented Picker、思考摘要 Picker。
- `输出` 卡片：输出详略、服务层级、输出 token 上限、图片最大边长。

模型字段使用：

```swift
TextField("模型 ID", text: model.textBinding(\ConfigDraft.model, field: .model))
    .textFieldStyle(.roundedBorder)
    .multilineTextAlignment(.trailing)
    .frame(width: 190)
```

若模型为空，在同一行下显示 `InlineSettingsMessage(text: error, systemImage: "exclamationmark.triangle.fill", color: .red)`。Thinking 关闭时智能程度和摘要行整体 `.disabled(true)`。Thinking、智能程度、摘要、输出详略和服务层级分别使用对应 `ConfigDraft` key path 调用 `model.binding`，作用域全部为 `.client`；输出上限和图片边长使用调用 `setMaxOutputTokens`、`setMaxImageEdge` 的显式 `Binding`。

- [ ] **Step 5: 验证模型页并提交**

Run:

```bash
swift test --filter SettingsViewModelTests
swift build
CATGPT_OPEN_SETTINGS=model swift run CatGPT
git add Sources/Settings Sources/SettingsWindowController.swift Tests/CatGPTTests/SettingsViewModelTests.swift
git commit -m "feat: redesign model settings"
```

Expected: 测试 PASS；模型为空时保持编辑内容并显示行内错误；Thinking 依赖控件正确禁用。

### Task 8: 重做外观页面并保证实时预览

**Files:**
- Create: `Sources/Settings/AppearanceSettingsView.swift`
- Modify: `Sources/Settings/SettingsRootView.swift`
- Modify: `Sources/SettingsWindowController.swift` — 删除旧外观页。

- [ ] **Step 1: 实现回答显示卡片**

创建 `AppearanceSettingsView`，页面标题“外观”，说明“调整回答在悬浮窗或 Touch Bar 中的显示方式。”。第一张 `SettingsGroup("回答显示")` 放悬浮窗/Touch Bar segmented Picker；本机无 Touch Bar 且选择该模式时，在卡片内显示橙色回退提示。

- [ ] **Step 2: 实现模式相关卡片**

悬浮窗模式显示背景透明度、文字透明度、字体大小、文字颜色和尺寸说明；Touch Bar 模式显示字号、文字强度、文字颜色和对齐方式。所有控件绑定 `.appearance`，滑块通过下列完整辅助方法显示等宽数字：

```swift
private func sliderRow(
    _ title: String,
    keyPath: WritableKeyPath<ConfigDraft, Double>,
    range: ClosedRange<Double>,
    step: Double,
    displayValue: String
) -> some View {
    SettingsRow(title) {
        HStack(spacing: 10) {
            Slider(
                value: model.binding(keyPath, scope: .appearance),
                in: range,
                step: step
            )
            Text(displayValue)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .frame(width: 270)
    }
}
```

模式切换使用 `.animation(.default, value: model.draft.outputDisplayMode)`；不得硬编码深色背景或文字色。

- [ ] **Step 3: 验证实时应用并提交**

Run:

```bash
swift build
CATGPT_OPEN_SETTINGS=appearance swift run CatGPT
git add Sources/Settings Sources/SettingsWindowController.swift
git commit -m "feat: redesign appearance settings"
```

Expected: 拖动滑块时输出视图立即更新，既不重新注册快捷键也不重建客户端；浅色和深色下均可读。

### Task 9: 重做服务页面并完成旧单文件删除

**Files:**
- Create: `Sources/Settings/ServiceSettingsView.swift`
- Modify: `Sources/Settings/SettingsRootView.swift`
- Delete: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: 实现四张服务卡片**

创建 `ServiceSettingsView`，页面标题“服务”，说明“管理账号、系统权限和 CatGPT 的运行状态。”，完整包含：

- `Codex 账号`：登录状态、登录/重新登录、退出登录。
- `权限`：屏幕录制授权状态与“打开系统设置…”。
- `运行`：当前状态、快捷键状态、开机自启；失败原因以卡片内红色/橙色信息显示。
- `关于`：版本号和“菜单栏常驻，截图、框选与浮窗均由快捷键触发”。

登录、退出、权限和开机自启继续调用模型的专用动作，不进入配置作用域。状态图标仅使用 `.green` 表示成功、`.orange` 表示需处理，其余文字保持语义色。

- [ ] **Step 2: 切换最终路由并删除旧文件**

把 `.service` 路由改为 `ServiceSettingsView(model:)`。确认旧文件已经没有任何唯一实现后，通过补丁删除 `Sources/SettingsWindowController.swift`；SwiftPM 最终只从 `Sources/Settings/` 加载设置实现。

- [ ] **Step 3: 做完整功能清单核对**

逐项核对：三个快捷键、固定区域五项、预设增删用、两个提示词字段、模型与四项推理设置、四项输出设置、显示模式、悬浮窗五项、Touch Bar 四项、账号登录退出、权限、状态、开机自启、版本信息。任何旧功能都不得遗漏。

- [ ] **Step 4: 构建并提交结构收尾**

Run:

```bash
swift test
swift build
git add Sources/Settings Sources/SettingsWindowController.swift
git commit -m "feat: complete settings window redesign"
```

Expected: 完整测试 PASS，旧 1100 行设置文件已删除。

### Task 10: 做跨外观、窗口尺寸、辅助功能和发布验证

**Files:**
- Verify: `Sources/Settings/*.swift`
- Verify: `Tests/CatGPTTests/*.swift`
- Generate locally: `.build/`, `dist/CatGPT.app`

- [ ] **Step 1: 运行完整自动化验证**

Run:

```bash
swift test
swift build -c release
```

Expected: `ConfigDefaultsTests`、`ResultPanelCompatibilityTests`、`SettingsUpdateScopeTests`、`SettingsViewModelTests`、`SettingsApplicationTests` 和 `ShortcutSettingsTests` 全部 PASS，Release 构建成功。

- [ ] **Step 2: 验证五个页面和三种窗口宽度**

依次用 `CATGPT_OPEN_SETTINGS=shortcuts|prompt|model|appearance|service` 启动。每页检查默认 `880×620`、最小 `760×520` 和放大窗口；确认侧栏范围为 `148/160/176`，右侧卡片铺满内容区、没有横向裁切和底部保存栏。

- [ ] **Step 3: 验证浅色、深色和提高对比度**

分别在系统浅色、深色、提高对比度下检查：主/次文字、分隔线、Material 卡片、焦点环、禁用状态和错误消息。确认 macOS 15 兼容测试对应的回答文字仍可见，并且没有 `.preferredColorScheme(.dark)` 或固定黑灰背景。

- [ ] **Step 4: 验证键盘与辅助功能**

用 Tab/Shift-Tab 遍历侧栏、文本框、Picker、Toggle、Button 和快捷键录制器；确认录制器与纯图标删除按钮具有可读标签，Escape 能退出快捷键录制。

- [ ] **Step 5: 构建 app 并检查最低系统版本**

Run:

```bash
Scripts/build-app.sh
otool -l dist/CatGPT.app/Contents/MacOS/CatGPT | sed -n '/LC_BUILD_VERSION/,/sdk/p'
```

Expected: `minos 14.0`；app 可在 macOS 15.6.1 上打开设置并显示回答文字。

- [ ] **Step 6: 检查提交范围与工作树**

Run:

```bash
git diff --check main...HEAD
git status --short
git log --oneline --decorate main..HEAD
```

Expected: 无空白错误，源码工作树干净，`.superpowers/`、`.build/` 和 `dist/` 未被提交；提交历史按任务分层。

- [ ] **Step 7: 最终审查提交**

Run:

```bash
git add -u
git commit -m "test: verify redesigned settings window"
```

仅当视觉或辅助功能验证产生了必要修正时创建该提交；若没有文件变化，跳过此提交并保留干净工作树。
