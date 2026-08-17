import SwiftUI

struct PromptSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        SettingsPage(
            title: "提示词",
            subtitle: "管理截图分析时发送给模型的默认内容。"
        ) {
            VStack(spacing: 24) {
                SettingsGroup("预设") {
                    ForEach(model.presets) { preset in
                        SettingsRow(preset.name, subtitle: preset.text, subtitleLineLimit: 1) {
                            HStack(spacing: 8) {
                                Button("使用") { model.applyPreset(preset) }
                                Button {
                                    model.deletePreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("删除预设 \(preset.name)")
                                .accessibilityLabel("删除预设 \(preset.name)")
                            }
                        }
                        if preset.id != model.presets.last?.id {
                            SettingsDivider()
                        }
                    }

                    SettingsDivider()
                    SettingsRow("存为预设", subtitle: "将当前默认提示词保存为可复用条目") {
                        HStack(spacing: 8) {
                            TextField("预设名称", text: $model.newPresetName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .settingsInputSurface()
                                .frame(width: 150)
                            Button("存为预设") { model.addPreset() }
                                .disabled(model.newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                SettingsGroup("默认提示词") {
                    VStack(alignment: .leading, spacing: 8) {
                        promptEditor(
                            text: model.textBinding(\ConfigDraft.prompt, field: .prompt),
                            minimumHeight: 120,
                            accessibilityLabel: "默认提示词"
                        )
                        Text("每次截图都会把这段提示词和图片一起发送。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }

                SettingsGroup("系统指令") {
                    VStack(alignment: .leading, spacing: 8) {
                        promptEditor(
                            text: model.textBinding(\ConfigDraft.instructions, field: .instructions),
                            minimumHeight: 88,
                            accessibilityLabel: "系统指令"
                        )
                        Text("作为 Responses API 的 instructions 字段发送；留空会恢复默认。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
            }
        }
    }

    private func promptEditor(
        text: Binding<String>,
        minimumHeight: CGFloat,
        accessibilityLabel: String
    ) -> some View {
        TextEditor(text: text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: minimumHeight)
            .settingsInputSurface(cornerRadius: 8)
            .accessibilityLabel(accessibilityLabel)
    }
}
