import SwiftUI

struct ServiceSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        SettingsPage(
            title: "服务",
            subtitle: "管理账号、系统权限和 CatGPT 的运行状态。"
        ) {
            VStack(spacing: 24) {
                SettingsGroup("Codex 账号") {
                    SettingsRow("账号", subtitle: model.accountText) {
                        HStack(spacing: 8) {
                            if model.state.signedIn {
                                Button("退出登录", role: .destructive) { model.logout() }
                            }
                            Button(model.state.signedIn ? "重新登录…" : "登录 ChatGPT…") { model.login() }
                        }
                    }
                }

                SettingsGroup("权限") {
                    SettingsRow("屏幕录制", subtitle: model.permissionText) {
                        HStack(spacing: 8) {
                            Image(systemName: model.state.screenPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(model.state.screenPermission ? .green : .orange)
                            Button("打开系统设置…") { model.requestScreenPermission() }
                        }
                    }
                }

                SettingsGroup("运行") {
                    SettingsRow("状态", subtitle: model.state.statusText) {
                        EmptyView()
                    }
                    SettingsDivider()
                    SettingsRow("快捷键", subtitle: model.state.hotKeyStatus) {
                        EmptyView()
                    }
                    SettingsDivider()
                    SettingsRow(
                        "开机自启",
                        subtitle: model.launchAtLoginAvailable
                            ? (model.launchAtLoginError ?? "登录系统后自动运行 CatGPT")
                            : "需要以 .app 打包运行后才能启用"
                    ) {
                        SettingsCheckbox(
                            isOn: launchAtLoginBinding,
                            accessibilityLabel: "开机自启"
                        )
                    }
                    .disabled(!model.launchAtLoginAvailable)
                    if let error = model.launchAtLoginError {
                        SettingsInlineMessage(text: error, systemImage: "exclamationmark.triangle.fill", color: .orange)
                    }
                }

                SettingsGroup("关于") {
                    SettingsRow("版本", subtitle: versionText) {
                        EmptyView()
                    }
                    SettingsDivider()
                    SettingsRow("运行方式", subtitle: "菜单栏常驻，截图、框选与浮窗均由快捷键触发") {
                        EmptyView()
                    }
                }
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppVersion.marketing
    }
}
