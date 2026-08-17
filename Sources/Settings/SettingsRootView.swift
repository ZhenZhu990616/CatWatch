import SwiftUI

struct SettingsRootView: View {
    private enum Layout {
        static let sidebarWidth: CGFloat = 148
        static let sidebarBrandTopPadding: CGFloat = 36
        static let sidebarNavigationTopPadding: CGFloat = 9
        static let sidebarNavigationLeadingInset: CGFloat = 6
    }

    @ObservedObject var model: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Layout.sidebarWidth)
                .safeAreaPadding(.top)
                .background {
                    ZStack {
                        Rectangle().fill(.thinMaterial)
                        Color.black.opacity(colorScheme == .dark ? 0.055 : 0.025)
                    }
                }
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.top)
                .background {
                    ZStack {
                        Rectangle().fill(.thinMaterial)
                        Color(nsColor: .windowBackgroundColor).opacity(0.06)
                    }
                }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(.clear)
        .buttonStyle(SettingsControlButtonStyle())
        .frame(minWidth: 760, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Text("CatGPT")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, Layout.sidebarBrandTopPadding)

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
            .padding(.leading, Layout.sidebarNavigationLeadingInset)
            .padding(.top, Layout.sidebarNavigationTopPadding)
            .scrollContentBackground(.hidden)
            .background(.clear)

            SidebarBrandMark()
                .padding(.top, 8)
                .padding(.bottom, 80)
        }
    }

    private var selectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { model.selectedSection },
            set: { if let section = $0 { model.selectedSection = section } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSection {
        case .shortcuts:
            ShortcutsSettingsView(model: model)
        case .prompt:
            PromptSettingsView(model: model)
        case .model:
            ModelSettingsView(model: model)
        case .appearance:
            AppearanceSettingsView(model: model)
        case .service:
            ServiceSettingsView(model: model)
        }
    }
}

private struct SidebarRow: View {
    let section: SettingsSection

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: section.symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 18)
            Text(section.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}
