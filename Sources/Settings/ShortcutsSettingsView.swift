import SwiftUI

struct ShortcutsSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
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
                        title: "批量截图",
                        subtitle: "每次缓存一张；再次按立即截图一次性发送（最多 8 张）",
                        keyPath: \ConfigDraft.batchCaptureHotKeyText,
                        field: .batchCaptureShortcut
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
                        SettingsCheckbox(
                            isOn: model.binding(\ConfigDraft.captureRegionEnabled, scope: .storageOnly),
                            accessibilityLabel: "启用固定区域"
                        )
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
                    SettingsRow("从屏幕选择", subtitle: "快捷键或按钮均可，框选一次并立即保存") {
                        HStack(spacing: 10) {
                            SettingsShortcutRecorder(
                                text: model.shortcutBinding(
                                    \ConfigDraft.captureRegionHotKeyText,
                                    field: .captureRegionShortcut
                                ),
                                accessibilityLabel: "从屏幕选择快捷键"
                            )
                            .frame(width: 158, height: 24)
                            .settingsInputSurface()

                            Button("选择区域…") { model.chooseCaptureRegion() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(
        title: String,
        subtitle: String,
        keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) -> some View {
        SettingsRow(title, subtitle: subtitle) {
            SettingsShortcutRecorder(
                text: model.shortcutBinding(keyPath, field: field),
                accessibilityLabel: "\(title)快捷键"
            )
            .frame(width: 158, height: 24)
            .settingsInputSurface()
        }
        if let error = model.error(for: field) {
            SettingsInlineMessage(text: error, systemImage: "exclamationmark.triangle.fill", color: .red)
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
                .textFieldStyle(.plain)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .settingsInputSurface()
                .multilineTextAlignment(.trailing)
                .frame(width: 54)
        }
    }

    private var regionSummary: String {
        let value = model.draft
        return "X \(Int(value.captureRegionX)) · Y \(Int(value.captureRegionY)) · \(Int(value.captureRegionWidth)) × \(Int(value.captureRegionHeight))"
    }
}
