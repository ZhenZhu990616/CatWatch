import AppKit
import Carbon
import Foundation
import ServiceManagement
import SwiftUI

struct SettingsState {
    let signedIn: Bool
    let accountId: String
    let screenPermission: Bool
    let statusText: String
    let hotKeyStatus: String
}

final class SettingsWindowController: NSWindowController {
    private let model: LegacySettingsViewModel

    init(
        draftProvider: @escaping () -> ConfigDraft,
        stateProvider: @escaping () -> SettingsState,
        onSave: @escaping (ConfigDraft) -> Void,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onPermission: @escaping () -> Void
    ) {
        model = LegacySettingsViewModel(
            draftProvider: draftProvider,
            stateProvider: stateProvider,
            onSave: onSave,
            onLogin: onLogin,
            onLogout: onLogout,
            onPermission: onPermission
        )

        // 标准系统窗口镶边（System Settings 风格）：不隐藏标题栏、不透明背景，
        // 标题随所选分区变化（经 sceneBridgingOptions 桥接 navigationTitle）。
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CatWatch 设置"
        window.minSize = NSSize(width: 640, height: 440)
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        let hosting = NSHostingController(rootView: SettingsRootView(model: model))
        if #available(macOS 14.0, *) {
            // 让 navigationTitle 桥接为窗口标题（随所选分区变化），
            // 并接管标题栏工具条（侧栏折叠按钮）。
            hosting.sceneBridgingOptions = [.title, .toolbars]
        }
        window.contentViewController = hosting

        super.init(window: window)

        window.delegate = self
        // 记住用户摆放的位置；只有第一次（没有记录时）才居中。
        if !window.setFrameUsingName("CatWatchSettings") {
            window.center()
        }
        window.setFrameAutosaveName("CatWatchSettings")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        reload()
    }

    func reload() {
        model.reload()
    }

    /// 开发辅助：按 rawValue 定位到某个设置分区（无效值忽略）。
    func select(sectionRaw: String) {
        if let section = SettingsSection(rawValue: sectionRaw) {
            model.selectedSection = section
        }
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 数字 TextField(value:format:) 只在失焦时提交绑定，
        // 先结束编辑会话再做脏检查，否则正在编辑的字段会被漏掉。
        sender.makeFirstResponder(nil)
        guard model.hasUnsavedChanges() else { return true }

        let alert = NSAlert()
        alert.messageText = "有未保存的更改"
        alert.informativeText = "关闭窗口前要保存这些修改吗？"
        alert.addButton(withTitle: "保存并关闭")
        alert.addButton(withTitle: "放弃更改")
        alert.addButton(withTitle: "取消")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            model.save()
            return true
        case .alertSecondButtonReturn:
            model.reload()
            return true
        default:
            return false
        }
    }
}

private final class LegacySettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .shortcuts
    @Published var modelName: String
    @Published var thinkingEnabled: Bool
    @Published var reasoningEffort: ReasoningEffort
    @Published var reasoningSummary: ReasoningSummary
    @Published var textVerbosity: TextVerbosity
    @Published var serviceTier: ServiceTier
    @Published var maxOutputTokens: Int
    @Published var prompt: String
    @Published var maxImageEdge: Int
    @Published var panelOpacity: Double
    @Published var panelTextOpacity: Double
    @Published var panelTextColor: TouchBarTextColor
    @Published var panelFontSize: Double
    @Published var outputDisplayMode: OutputDisplayMode
    @Published var touchBarFontSize: Double
    @Published var touchBarTextColor: TouchBarTextColor
    @Published var touchBarTextIntensity: Double
    @Published var touchBarTextAlignment: TouchBarTextAlignment
    @Published var captureShortcut: String
    @Published var selectionShortcut: String
    @Published var panelShortcut: String
    @Published var instructions: String
    @Published var captureRegionEnabled: Bool
    @Published var captureRegionX: Int
    @Published var captureRegionY: Int
    @Published var captureRegionWidth: Int
    @Published var captureRegionHeight: Int
    @Published var state: SettingsState
    @Published var presets: [PromptPreset]
    @Published var newPresetName = ""
    @Published var launchAtLogin: Bool
    @Published var launchAtLoginError: String?

    /// SMAppService 只对 .app bundle 生效，swift run 裸二进制无法注册。
    let launchAtLoginAvailable = Bundle.main.bundlePath.hasSuffix(".app")

    private let draftProvider: () -> ConfigDraft
    private let stateProvider: () -> SettingsState
    private let onSave: (ConfigDraft) -> Void
    private let onLogin: () -> Void
    private let onLogout: () -> Void
    private let onPermission: () -> Void
    private var draft: ConfigDraft

    init(
        draftProvider: @escaping () -> ConfigDraft,
        stateProvider: @escaping () -> SettingsState,
        onSave: @escaping (ConfigDraft) -> Void,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onPermission: @escaping () -> Void
    ) {
        self.draftProvider = draftProvider
        self.stateProvider = stateProvider
        self.onSave = onSave
        self.onLogin = onLogin
        self.onLogout = onLogout
        self.onPermission = onPermission

        let initialDraft = draftProvider()
        draft = initialDraft
        state = stateProvider()
        presets = PromptPresetStore.load()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        modelName = initialDraft.model
        thinkingEnabled = initialDraft.thinkingEnabled
        reasoningEffort = initialDraft.reasoningEffort
        reasoningSummary = initialDraft.reasoningSummary
        textVerbosity = initialDraft.textVerbosity
        serviceTier = initialDraft.serviceTier
        maxOutputTokens = initialDraft.maxOutputTokens
        prompt = initialDraft.prompt
        maxImageEdge = initialDraft.maxImageEdge
        panelOpacity = initialDraft.normalizedPanelOpacity
        panelTextOpacity = initialDraft.normalizedPanelTextOpacity
        panelTextColor = initialDraft.panelTextColor
        panelFontSize = initialDraft.normalizedPanelFontSize
        outputDisplayMode = initialDraft.outputDisplayMode
        touchBarFontSize = initialDraft.normalizedTouchBarFontSize
        touchBarTextColor = initialDraft.touchBarTextColor
        touchBarTextIntensity = initialDraft.normalizedTouchBarTextIntensity
        touchBarTextAlignment = initialDraft.touchBarTextAlignment
        captureShortcut = initialDraft.hotKeyText
        selectionShortcut = initialDraft.selectionHotKeyText
        panelShortcut = initialDraft.panelHotKeyText
        instructions = initialDraft.instructions
        captureRegionEnabled = initialDraft.captureRegionEnabled
        captureRegionX = Int(initialDraft.captureRegionX.rounded())
        captureRegionY = Int(initialDraft.captureRegionY.rounded())
        captureRegionWidth = Int(initialDraft.captureRegionWidth.rounded())
        captureRegionHeight = Int(initialDraft.captureRegionHeight.rounded())
    }

    func reload() {
        let latestDraft = draftProvider()
        // 非编辑字段（运行状态、预设、开机自启）总是刷新。
        state = stateProvider()
        presets = PromptPresetStore.load()
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // 若用户正有未保存编辑（外部触发的 reload：菜单切预设、登出、请求权限），
        // 不要用磁盘快照覆盖正在编辑的字段，避免静默丢失编辑。
        if hasUnsavedChanges() {
            return
        }

        draft = latestDraft
        modelName = latestDraft.model
        thinkingEnabled = latestDraft.thinkingEnabled
        reasoningEffort = latestDraft.reasoningEffort
        reasoningSummary = latestDraft.reasoningSummary
        textVerbosity = latestDraft.textVerbosity
        serviceTier = latestDraft.serviceTier
        maxOutputTokens = latestDraft.maxOutputTokens
        prompt = latestDraft.prompt
        maxImageEdge = latestDraft.maxImageEdge
        panelOpacity = latestDraft.normalizedPanelOpacity
        panelTextOpacity = latestDraft.normalizedPanelTextOpacity
        panelTextColor = latestDraft.panelTextColor
        panelFontSize = latestDraft.normalizedPanelFontSize
        outputDisplayMode = latestDraft.outputDisplayMode
        touchBarFontSize = latestDraft.normalizedTouchBarFontSize
        touchBarTextColor = latestDraft.touchBarTextColor
        touchBarTextIntensity = latestDraft.normalizedTouchBarTextIntensity
        touchBarTextAlignment = latestDraft.touchBarTextAlignment
        captureShortcut = latestDraft.hotKeyText
        selectionShortcut = latestDraft.selectionHotKeyText
        panelShortcut = latestDraft.panelHotKeyText
        instructions = latestDraft.instructions
        captureRegionEnabled = latestDraft.captureRegionEnabled
        captureRegionX = Int(latestDraft.captureRegionX.rounded())
        captureRegionY = Int(latestDraft.captureRegionY.rounded())
        captureRegionWidth = Int(latestDraft.captureRegionWidth.rounded())
        captureRegionHeight = Int(latestDraft.captureRegionHeight.rounded())
    }

    func save() {
        // 先结束当前编辑会话，让数字字段（value:format: 绑定）把
        // 正在输入的值提交到 model，否则会把旧值写进配置。
        NSApp.keyWindow?.makeFirstResponder(nil)

        draft.model = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.thinkingEnabled = thinkingEnabled
        draft.reasoningEffort = reasoningEffort
        draft.reasoningSummary = reasoningSummary
        draft.textVerbosity = textVerbosity
        draft.serviceTier = serviceTier
        draft.maxOutputTokens = maxOutputTokens
        draft.prompt = prompt
        draft.hotKeyText = captureShortcut
        draft.selectionHotKeyText = selectionShortcut
        draft.panelHotKeyText = panelShortcut
        draft.instructions = instructions
        draft.captureRegionEnabled = captureRegionEnabled
        draft.captureRegionX = Double(captureRegionX)
        draft.captureRegionY = Double(captureRegionY)
        draft.captureRegionWidth = Double(captureRegionWidth)
        draft.captureRegionHeight = Double(captureRegionHeight)
        draft.maxImageEdge = maxImageEdge
        draft.panelOpacity = panelOpacity
        draft.panelTextOpacity = panelTextOpacity
        draft.panelTextColor = panelTextColor
        draft.panelFontSize = panelFontSize
        draft.outputDisplayMode = outputDisplayMode
        draft.touchBarFontSize = touchBarFontSize
        draft.touchBarTextColor = touchBarTextColor
        draft.touchBarTextIntensity = touchBarTextIntensity
        draft.touchBarTextAlignment = touchBarTextAlignment
        onSave(draft)
    }

    func resetShortcuts() {
        captureShortcut = ConfigDraft.defaultHotKey
        selectionShortcut = ConfigDraft.defaultSelectionHotKey
        panelShortcut = ConfigDraft.defaultPanelHotKey
    }

    func chooseCaptureRegion() {
        Task { @MainActor in
            let previousWindow = NSApp.keyWindow
            previousWindow?.orderOut(nil)
            try? await Task.sleep(nanoseconds: 120_000_000)
            defer {
                NSApp.activate(ignoringOtherApps: true)
                // 恢复原位即可，不要把窗口重新居中搬家。
                previousWindow?.makeKeyAndOrderFront(nil)
            }

            guard let rect = try? await SelectionCapture.selectRegion() else { return }
            captureRegionEnabled = true
            captureRegionX = Int(rect.origin.x.rounded())
            captureRegionY = Int(rect.origin.y.rounded())
            captureRegionWidth = Int(rect.width.rounded())
            captureRegionHeight = Int(rect.height.rounded())
        }
    }

    func login() {
        onLogin()
    }

    func logout() {
        onLogout()
        reload()
    }

    func applyPreset(_ preset: PromptPreset) {
        prompt = preset.text
    }

    func addPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        presets.append(PromptPreset(id: UUID(), name: name, text: prompt))
        PromptPresetStore.save(presets)
        newPresetName = ""
    }

    func deletePreset(_ preset: PromptPreset) {
        presets.removeAll { $0.id == preset.id }
        PromptPresetStore.save(presets)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
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

    /// 与 save() 的写回字段一一对应，用于关窗时的脏状态判断。
    func hasUnsavedChanges() -> Bool {
        modelName.trimmingCharacters(in: .whitespacesAndNewlines) != draft.model
            || thinkingEnabled != draft.thinkingEnabled
            || reasoningEffort != draft.reasoningEffort
            || reasoningSummary != draft.reasoningSummary
            || textVerbosity != draft.textVerbosity
            || serviceTier != draft.serviceTier
            || maxOutputTokens != draft.maxOutputTokens
            || prompt != draft.prompt
            || instructions != draft.instructions
            || captureShortcut != draft.hotKeyText
            || selectionShortcut != draft.selectionHotKeyText
            || panelShortcut != draft.panelHotKeyText
            || captureRegionEnabled != draft.captureRegionEnabled
            || Double(captureRegionX) != draft.captureRegionX
            || Double(captureRegionY) != draft.captureRegionY
            || Double(captureRegionWidth) != draft.captureRegionWidth
            || Double(captureRegionHeight) != draft.captureRegionHeight
            || maxImageEdge != draft.maxImageEdge
            || abs(panelOpacity - draft.normalizedPanelOpacity) > 0.001
            || abs(panelTextOpacity - draft.normalizedPanelTextOpacity) > 0.001
            || panelTextColor != draft.panelTextColor
            || abs(panelFontSize - draft.normalizedPanelFontSize) > 0.001
            || outputDisplayMode != draft.outputDisplayMode
            || abs(touchBarFontSize - draft.normalizedTouchBarFontSize) > 0.001
            || touchBarTextColor != draft.touchBarTextColor
            || abs(touchBarTextIntensity - draft.normalizedTouchBarTextIntensity) > 0.001
            || touchBarTextAlignment != draft.touchBarTextAlignment
    }
}

// MARK: - System Settings 风格的设置界面
// 原生 NavigationSplitView 侧栏（彩色图标磁贴）+ 分组 Form 详情页，
// 控件、字号、间距全部使用系统默认，跟随浅色/深色与强调色。

private struct SettingsRootView: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    private var sidebar: some View {
        List(selection: selectionBinding) {
            ForEach(SettingsSection.allCases) { section in
                SidebarRow(section: section)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 230)
    }

    private var selectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { model.selectedSection },
            set: { newValue in
                if let newValue {
                    model.selectedSection = newValue
                }
            }
        )
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch model.selectedSection {
            case .shortcuts:
                ShortcutsPane(model: model)
            case .service:
                ServicePane(model: model)
            case .model:
                ModelPane(model: model)
            case .appearance:
                AppearancePane(model: model)
            case .prompt:
                PromptPane(model: model)
            }
        }
        .navigationTitle(model.selectedSection.title)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SaveBar(model: model)
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    section.tint.gradient,
                    in: RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                )
        }
    }
}

private struct SaveBar: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        HStack(spacing: 12) {
            if model.selectedSection == .shortcuts {
                Button("恢复默认快捷键") {
                    model.resetShortcuts()
                }
            }

            Spacer()

            Button("保存更改") {
                model.save()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - 快捷键

private struct ShortcutsPane: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        Form {
            Section {
                shortcutRow("立即截图", subtitle: "静默截取全屏；开启固定区域后自动裁切", text: $model.captureShortcut)
                shortcutRow("框选截图", subtitle: "拖动选取屏幕区域后发送", text: $model.selectionShortcut)
                shortcutRow("呼出/隐藏结果", subtitle: "按当前显示模式呼出或隐藏上次结果", text: $model.panelShortcut)
            } header: {
                Text("全局快捷键")
            } footer: {
                Text("支持常规组合键，也支持 ⌘ / ⌃ / ⌥ / ⇧ 连按两下。")
            }

            Section("固定静默区域") {
                Toggle(isOn: $model.captureRegionEnabled) {
                    Text("启用固定区域")
                    Text("为「立即截图」预设裁切范围；关闭时截取全屏")
                }

                LabeledContent("区域坐标") {
                    HStack(spacing: 6) {
                        regionField("X", value: $model.captureRegionX)
                        regionField("Y", value: $model.captureRegionY)
                        regionField("宽", value: $model.captureRegionWidth)
                        regionField("高", value: $model.captureRegionHeight)
                    }
                }
                .disabled(!model.captureRegionEnabled)
                .foregroundStyle(model.captureRegionEnabled ? .primary : .secondary)

                LabeledContent {
                    Button("从屏幕选择…") {
                        model.chooseCaptureRegion()
                    }
                } label: {
                    Text("选择区域")
                    Text("框选一次并保存；之后按快捷键会静默按此区域裁切")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ title: String, subtitle: String, text: Binding<String>) -> some View {
        LabeledContent {
            ShortcutRecorder(text: text, accessibilityLabel: "\(title)快捷键")
                .frame(width: 158, height: 24)
        } label: {
            Text(title)
            Text(subtitle)
        }
    }

    private func regionField(_ title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: .number.grouping(.never))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
        }
    }
}

// MARK: - 服务

private struct ServicePane: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        Form {
            Section("Codex 账号") {
                LabeledContent {
                    HStack(spacing: 8) {
                        if model.state.signedIn {
                            Button("退出登录", role: .destructive) {
                                model.logout()
                            }
                        }
                        Button(model.state.signedIn ? "重新登录…" : "登录 ChatGPT…") {
                            model.login()
                        }
                    }
                } label: {
                    Text("账号")
                    Text(model.accountText)
                }
            }

            Section("权限") {
                LabeledContent {
                    HStack(spacing: 8) {
                        Image(systemName: model.state.screenPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(model.state.screenPermission ? .green : .orange)
                        Button("打开系统设置…") {
                            model.requestScreenPermission()
                        }
                    }
                } label: {
                    Text("屏幕录制")
                    Text(model.permissionText)
                }
            }

            Section("运行") {
                LabeledContent("状态") {
                    Text(model.state.statusText)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("快捷键") {
                    Text(model.state.hotKeyStatus)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Toggle(isOn: launchAtLoginBinding) {
                    Text("开机自启")
                    Text(model.launchAtLoginAvailable
                        ? (model.launchAtLoginError ?? "登录系统后自动运行 CatWatch")
                        : "需要以 .app 打包运行后才能启用")
                }
                .disabled(!model.launchAtLoginAvailable)
            }

            Section("关于") {
                LabeledContent("版本") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("运行方式") {
                    Text("菜单栏常驻，截图、框选与浮窗均由快捷键触发")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }
}

// MARK: - 模型

private struct ModelPane: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        Form {
            Section("模型") {
                LabeledContent {
                    HStack(spacing: 6) {
                        TextField("模型 ID", text: $model.modelName)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 170)

                        Menu {
                            ForEach(ConfigDraft.suggestedModels, id: \.id) { entry in
                                Button("\(entry.id)　\(entry.hint)") {
                                    model.modelName = entry.id
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .accessibilityLabel("选择模型")
                    }
                } label: {
                    Text("模型 ID")
                    Text("发送给 Codex Responses 的 model 字段")
                }

                Toggle(isOn: $model.thinkingEnabled) {
                    Text("Thinking")
                    Text("关闭时发送 reasoning.effort = none")
                }

                LabeledContent {
                    Picker("智能程度", selection: $model.reasoningEffort) {
                        ForEach(ReasoningEffort.allCases) { effort in
                            Text(effort.title).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280)
                } label: {
                    Text("智能程度")
                    Text("对应 reasoning.effort；超高仅部分模型支持")
                }
                .disabled(!model.thinkingEnabled)

                Picker(selection: $model.reasoningSummary) {
                    ForEach(ReasoningSummary.allCases) { summary in
                        Text(summary.title).tag(summary)
                    }
                } label: {
                    Text("思考摘要")
                    Text("对应 reasoning.summary；关闭时不传该字段")
                }
                .disabled(!model.thinkingEnabled)
            }

            Section("输出") {
                Picker("输出详略", selection: $model.textVerbosity) {
                    ForEach(TextVerbosity.allCases) { verbosity in
                        Text(verbosity.title).tag(verbosity)
                    }
                }

                Picker(selection: $model.serviceTier) {
                    ForEach(ServiceTier.allCases) { tier in
                        Text(tier.title).tag(tier)
                    }
                } label: {
                    Text("服务层级")
                    Text("「系统默认」表示不传 service_tier 字段")
                }

                LabeledContent {
                    TextField("0", value: $model.maxOutputTokens, format: .number.grouping(.never))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                } label: {
                    Text("输出上限")
                    Text("max_output_tokens；0 表示不设置")
                }

                LabeledContent {
                    TextField("1600", value: $model.maxImageEdge, format: .number.grouping(.never))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                } label: {
                    Text("图片最大边长")
                    Text("截图等比压缩到该边长以内，最小 640")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 外观

private struct AppearancePane: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("显示模式", selection: $model.outputDisplayMode) {
                        ForEach(OutputDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 220)
                } label: {
                    Text("显示模式")
                    Text("回答显示在悬浮窗或 Touch Bar")
                }

                if model.outputDisplayMode == .touchBar && !TouchBarResultController.isAvailable {
                    Label("本机没有 Touch Bar，回答会自动改用悬浮窗显示。", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            if model.outputDisplayMode == .floatingPanel {
                Section("悬浮窗") {
                    sliderRow("浮窗透明度", value: $model.panelOpacity, in: 0...1, display: percentText(model.panelOpacity))
                    sliderRow("文字透明度", value: $model.panelTextOpacity, in: 0...1, display: percentText(model.panelTextOpacity))
                    sliderRow("字体大小", value: $model.panelFontSize, in: 10...28, step: 1, display: "\(Int(model.panelFontSize.rounded())) pt")

                    Picker("文字颜色", selection: $model.panelTextColor) {
                        ForEach(TouchBarTextColor.allCases) { color in
                            Text(color.title).tag(color)
                        }
                    }

                    LabeledContent {
                        Text("直接拖动浮窗边缘调整，会自动记忆")
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("浮窗尺寸")
                    }
                }
            } else {
                Section("Touch Bar") {
                    sliderRow("字号", value: $model.touchBarFontSize, in: 10...24, step: 1, display: "\(Int(model.touchBarFontSize.rounded())) pt")
                    sliderRow("文字深浅", value: $model.touchBarTextIntensity, in: 0.35...1, display: percentText(model.touchBarTextIntensity))

                    Picker("文字颜色", selection: $model.touchBarTextColor) {
                        ForEach(TouchBarTextColor.allCases) { color in
                            Text(color.title).tag(color)
                        }
                    }

                    LabeledContent {
                        Picker("对齐", selection: $model.touchBarTextAlignment) {
                            ForEach(TouchBarTextAlignment.allCases) { alignment in
                                Text(alignment.title).tag(alignment)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                    } label: {
                        Text("对齐位置")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: model.outputDisplayMode)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        display: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }

                Text(display)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
            .frame(maxWidth: 250)
        }
    }
}

// MARK: - 提示词

private struct PromptPane: View {
    @ObservedObject var model: LegacySettingsViewModel

    var body: some View {
        Form {
            Section {
                ForEach(model.presets) { preset in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Button("使用") {
                                model.applyPreset(preset)
                            }

                            Button {
                                model.deletePreset(preset)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("删除预设 \(preset.name)")
                        }
                    } label: {
                        Text(preset.name)
                        Text(preset.text)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    TextField("预设名称", text: $model.newPresetName)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)

                    Button("把当前提示词存为预设") {
                        model.addPreset()
                    }
                    .disabled(model.newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
            } header: {
                Text("预设")
            } footer: {
                Text("「使用」把预设填入下方编辑器，保存后生效；菜单栏的「提示词预设」子菜单可随时切换。")
            }

            Section {
                TextEditor(text: $model.prompt)
                    .font(.body)
                    .frame(minHeight: 110)
                    .accessibilityLabel("默认提示词")
            } header: {
                Text("默认提示词")
            } footer: {
                Text("每次截图都会把这段提示词和图片一起发送。")
            }

            Section {
                TextEditor(text: $model.instructions)
                    .font(.body)
                    .frame(minHeight: 72)
                    .accessibilityLabel("系统指令")
            } header: {
                Text("系统指令")
            } footer: {
                Text("作为 Responses API 的 instructions 字段发送，定义助手整体行为与回答语言；留空恢复默认。")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 快捷键录制（AppKit 桥接）

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var text: String
    let accessibilityLabel: String

    func makeNSView(context: Context) -> ShortcutCaptureButton {
        let button = ShortcutCaptureButton()
        button.setAccessibilityLabel(accessibilityLabel)
        button.onChange = { newText in
            text = newText
        }
        return button
    }

    func updateNSView(_ nsView: ShortcutCaptureButton, context: Context) {
        nsView.setAccessibilityLabel(accessibilityLabel)
        if nsView.shortcutText != text {
            nsView.shortcutText = text
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case shortcuts
    case service
    case model
    case appearance
    case prompt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortcuts: return "快捷键"
        case .service: return "服务"
        case .model: return "模型"
        case .appearance: return "外观"
        case .prompt: return "提示词"
        }
    }

    var symbolName: String {
        switch self {
        case .shortcuts: return "keyboard"
        case .service: return "person.crop.circle"
        case .model: return "brain.head.profile"
        case .appearance: return "macwindow"
        case .prompt: return "text.alignleft"
        }
    }

    var tint: Color {
        switch self {
        case .shortcuts: return .indigo
        case .service: return .green
        case .model: return .purple
        case .appearance: return .blue
        case .prompt: return .orange
        }
    }
}

final class ShortcutCaptureButton: NSButton {
    var onChange: ((String) -> Void)?

    var shortcutText: String = "" {
        didSet {
            if !isRecording {
                title = formattedShortcut(shortcutText)
            }
            if oldValue != shortcutText {
                onChange?(shortcutText)
            }
        }
    }

    private var monitors: [Any] = []
    private var isRecording = false
    private var previousFlags: NSEvent.ModifierFlags = []
    private var lastPressTimes: [DoubleTapKey: TimeInterval] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        target = self
        action = #selector(startRecording)
        bezelStyle = .rounded
        controlSize = .regular
        alignment = .center
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        focusRingType = .default
        setButtonType(.momentaryPushIn)
        title = formattedShortcut(shortcutText)
    }

    @objc private func startRecording() {
        stopRecording()
        isRecording = true
        title = "按下快捷键..."
        window?.makeFirstResponder(self)

        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self else { return event }
            self.recordKeyDown(event)
            return nil
        }) {
            monitors.append(keyMonitor)
        }

        if let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.recordFlags(event)
            return event
        }) {
            monitors.append(flagsMonitor)
        }

        if let mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] event in
                guard let self else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                if !self.bounds.contains(point) {
                    self.cancelRecording()
                }
                return event
            }
        ) {
            monitors.append(mouseMonitor)
        }

        if let globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in
                self?.cancelRecording()
            }
        ) {
            monitors.append(globalMouseMonitor)
        }
    }

    private func recordKeyDown(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isEmpty, let key = rawKeyName(for: event) else { return }

        var parts: [String] = []
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option) { parts.append("opt") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.command) { parts.append("cmd") }
        parts.append(key)
        shortcutText = parts.joined(separator: "+")
        stopRecording()
        title = formattedShortcut(shortcutText)
    }

    private func recordFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        for key in DoubleTapKey.allCases {
            let wasDown = previousFlags.contains(key.modifierFlag)
            let isDown = flags.contains(key.modifierFlag)
            guard isDown, !wasDown else { continue }

            let now = Date().timeIntervalSince1970
            if let last = lastPressTimes[key], now - last <= 0.42 {
                shortcutText = rawText(for: key)
                stopRecording()
                title = formattedShortcut(shortcutText)
                return
            }
            lastPressTimes[key] = now
        }
        previousFlags = flags
    }

    private func rawText(for key: DoubleTapKey) -> String {
        switch key {
        case .command: return "cmd double tap"
        case .control: return "ctrl double tap"
        case .option: return "opt double tap"
        case .shift: return "shift double tap"
        }
    }

    private func stopRecording() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isRecording = false
        previousFlags = []
        lastPressTimes.removeAll()
    }

    private func cancelRecording() {
        stopRecording()
        title = formattedShortcut(shortcutText)
    }

    deinit {
        stopRecording()
    }
}
