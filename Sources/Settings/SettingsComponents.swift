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
                        Text(title)
                            .font(.system(size: 21, weight: .semibold))
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    accessory
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.thinMaterial)
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
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                content
            }
            .background {
                let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
                ZStack {
                    shape.fill(.regularMaterial)
                    shape.fill(cardFill)
                }
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.035), radius: 1, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardFill: Color {
        colorScheme == .dark ? .black.opacity(0.08) : .white.opacity(0.28)
    }

}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let subtitleLineLimit: Int?
    let control: Control

    init(
        _ title: String,
        subtitle: String? = nil,
        subtitleLineLimit: Int? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleLineLimit = subtitleLineLimit
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(subtitleLineLimit)
                        .truncationMode(.tail)
                }
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.12))
            .frame(height: 1 / max(displayScale, 1))
            .padding(.horizontal, 14)
    }
}

enum SettingsControlSurfaceMetrics {
    static let inputCornerRadius: CGFloat = 6
    static let inputBorderWidth: CGFloat = 0.5
}

enum SettingsControlSurfacePalette {
    static func fill(isDark: Bool) -> NSColor {
        isDark ? .black.withAlphaComponent(0.18) : .white.withAlphaComponent(0.56)
    }

    static func border(isDark: Bool) -> NSColor {
        .labelColor.withAlphaComponent(isDark ? 0.28 : 0.18)
    }

    static func fill(for colorScheme: ColorScheme) -> Color {
        Color(nsColor: fill(isDark: colorScheme == .dark))
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        Color(nsColor: border(isDark: colorScheme == .dark))
    }
}

private struct SettingsInputSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .settingsControlSurface(cornerRadius: cornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(inputBorder, lineWidth: SettingsControlSurfaceMetrics.inputBorderWidth)
            }
    }

    private var inputBorder: Color { SettingsControlSurfacePalette.border(for: colorScheme) }
}

extension View {
    func settingsControlSurface(cornerRadius: CGFloat = 7) -> some View {
        modifier(SettingsControlSurface(cornerRadius: cornerRadius))
    }

    func settingsInputSurface(cornerRadius: CGFloat = SettingsControlSurfaceMetrics.inputCornerRadius) -> some View {
        modifier(SettingsInputSurface(cornerRadius: cornerRadius))
    }
}

private struct SettingsControlSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(SettingsControlSurfacePalette.fill(for: colorScheme))
                }
            }
    }
}

struct SettingsControlButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .settingsControlSurface()
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct SettingsCheckbox: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                if isOn {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 18, height: 18)
            .settingsInputSurface(cornerRadius: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "已启用" : "已关闭")
    }
}

struct SettingsSegmentedPicker<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button(title(option)) {
                    selection = option
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(selection == option ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background {
                    if selection == option {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }

                if option.id != options.last?.id {
                    Rectangle()
                        .fill(Color.primary.opacity(0.14))
                        .frame(width: 0.5)
                        .padding(.vertical, 5)
                }
            }
        }
        .padding(2)
        .settingsControlSurface()
        .accessibilityLabel(accessibilityLabel)
    }
}

struct SettingsMenuPicker<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    let accessibilityLabel: String

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(title(option)) {
                    selection = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title(selection))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title(selection))
    }
}

struct SettingsInlineMessage: View {
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
