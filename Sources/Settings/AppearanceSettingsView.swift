import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        SettingsPage(
            title: "外观",
            subtitle: "调整回答在悬浮窗或 Touch Bar 中的显示方式。"
        ) {
            VStack(spacing: 24) {
                SettingsGroup("回答显示") {
                    SettingsRow("显示模式", subtitle: "回答显示在悬浮窗或 Touch Bar") {
                        SettingsSegmentedPicker(
                            selection: model.binding(\ConfigDraft.outputDisplayMode, scope: .appearance),
                            options: OutputDisplayMode.allCases,
                            title: \.title,
                            accessibilityLabel: "显示模式"
                        )
                        .frame(width: 220)
                    }

                    if model.draft.outputDisplayMode == .touchBar && !TouchBarResultController.isAvailable {
                        SettingsDivider()
                        SettingsInlineMessage(
                            text: "本机没有 Touch Bar，回答会自动改用悬浮窗显示。",
                            systemImage: "exclamationmark.triangle.fill",
                            color: .orange
                        )
                    }
                }

                if model.draft.outputDisplayMode == .floatingPanel {
                    floatingPanelGroup
                } else {
                    touchBarGroup
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var floatingPanelGroup: some View {
        SettingsGroup("悬浮窗") {
            sliderRow(
                "浮窗透明度",
                keyPath: \ConfigDraft.panelOpacity,
                range: 0...1,
                step: 0.01,
                displayValue: percentText(model.draft.panelOpacity)
            )
            SettingsDivider()
            sliderRow(
                "文字透明度",
                keyPath: \ConfigDraft.panelTextOpacity,
                range: 0...1,
                step: 0.01,
                displayValue: percentText(model.draft.panelTextOpacity)
            )
            SettingsDivider()
            sliderRow(
                "字体大小",
                keyPath: \ConfigDraft.panelFontSize,
                range: 10...28,
                step: 1,
                displayValue: "\(Int(model.draft.panelFontSize.rounded())) pt"
            )
            SettingsDivider()
            SettingsRow("文字颜色") {
                textColorPicker(selection: model.binding(\ConfigDraft.panelTextColor, scope: .appearance))
            }
            SettingsDivider()
            SettingsRow("浮窗尺寸", subtitle: "直接拖动浮窗边缘调整，会自动记忆") {
                EmptyView()
            }
        }
    }

    private var touchBarGroup: some View {
        SettingsGroup("Touch Bar") {
            sliderRow(
                "字号",
                keyPath: \ConfigDraft.touchBarFontSize,
                range: 10...24,
                step: 1,
                displayValue: "\(Int(model.draft.touchBarFontSize.rounded())) pt"
            )
            SettingsDivider()
            sliderRow(
                "文字深浅",
                keyPath: \ConfigDraft.touchBarTextIntensity,
                range: 0.35...1,
                step: 0.01,
                displayValue: percentText(model.draft.touchBarTextIntensity)
            )
            SettingsDivider()
            SettingsRow("文字颜色") {
                textColorPicker(selection: model.binding(\ConfigDraft.touchBarTextColor, scope: .appearance))
            }
            SettingsDivider()
            SettingsRow("对齐位置") {
                SettingsSegmentedPicker(
                    selection: model.binding(\ConfigDraft.touchBarTextAlignment, scope: .appearance),
                    options: TouchBarTextAlignment.allCases,
                    title: \.title,
                    accessibilityLabel: "对齐位置"
                )
                .frame(width: 160)
            }
        }
    }

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

    private func textColorPicker(selection: Binding<TouchBarTextColor>) -> some View {
        SettingsMenuPicker(
            selection: selection,
            options: TouchBarTextColor.allCases,
            title: \.title,
            accessibilityLabel: "文字颜色"
        )
        .frame(width: 132)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
