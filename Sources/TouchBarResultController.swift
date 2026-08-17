import AppKit
import Darwin

final class TouchBarResultController: NSObject, NSTouchBarDelegate {
    private static let resultIdentifier = NSTouchBarItem.Identifier("CatGPT.touchBar.result")

    private let touchBar = NSTouchBar()
    private let indicatorView = PhaseIndicatorView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
    private let textLabel = NSTextField(labelWithString: "")
    private lazy var contentView = makeContentView()

    private var fontSize = ConfigDraft.defaultTouchBarFontSize
    private var textColor = ConfigDraft.defaultTouchBarTextColor
    private var textIntensity = ConfigDraft.defaultTouchBarTextIntensity
    private var textAlignment = ConfigDraft.defaultTouchBarTextAlignment
    private var isVisible = false

    /// 展示与可用性判断均不使用私有 API 或私有 Framework。
    static let usesPrivatePresentationAPI = false
    static let usesPrivateAvailabilityProbe = false

    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("CatGPT.touchBar")
        configure(
            fontSize: ConfigDraft.defaultTouchBarFontSize,
            textColor: ConfigDraft.defaultTouchBarTextColor,
            textIntensity: ConfigDraft.defaultTouchBarTextIntensity,
            textAlignment: ConfigDraft.defaultTouchBarTextAlignment
        )
    }

    func configure(
        fontSize: Double,
        textColor: TouchBarTextColor,
        textIntensity: Double,
        textAlignment: TouchBarTextAlignment
    ) {
        self.fontSize = min(24, max(10, fontSize))
        self.textColor = textColor
        self.textIntensity = min(1.0, max(0.35, textIntensity))
        self.textAlignment = textAlignment
        rebuildPlacement()
        updateAppearance()
    }

    func show(text: String, kind: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(text: text, kind: kind)
            }
            return
        }

        indicatorView.isHidden = true
        textLabel.stringValue = oneLine(text)
        updateAppearance()
        present()
    }

    func showPhase(_ phase: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showPhase(phase)
            }
            return
        }

        textLabel.stringValue = ""
        indicatorView.isHidden = false
        indicatorView.setPhase(phase)
        present()
    }

    func toggle(text: String, kind: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.toggle(text: text, kind: kind)
            }
            return
        }

        if isVisible {
            dismiss()
        } else {
            show(text: text, kind: kind)
        }
    }

    func hideForCapture() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hideForCapture()
            }
            return
        }
        dismiss()
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Self.resultIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "CatGPT 回答"
        item.view = contentView
        return item
    }

    private func present() {
        guard !isVisible else { return }
        // 公开 NSTouchBar API 需要应用成为当前上下文，可安全分发。
        NSApp.touchBar = touchBar
        isVisible = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismiss() {
        guard isVisible else { return }
        if NSApp.touchBar === touchBar {
            NSApp.touchBar = nil
        }
        isVisible = false
    }

    /// 没有公开的 API 可以直接询问“此 Mac 是否带实体 Touch Bar”。
    /// 因此只使用公开的 `hw.model` 标识，识别 Apple 曾销售的 Touch Bar
    /// MacBook Pro；未知型号保守回退为悬浮窗，避免把回答显示到不存在的硬件上。
    static let isAvailable = isKnownTouchBarModel(hardwareModelIdentifier())

    static func isKnownTouchBarModel(_ identifier: String) -> Bool {
        [
            "MacBookPro13,2", "MacBookPro13,3",
            "MacBookPro14,2", "MacBookPro14,3",
            "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4",
            "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4",
            "MacBookPro17,1"
        ].contains(identifier)
    }

    private static func hardwareModelIdentifier() -> String {
        var length = 0
        guard sysctlbyname("hw.model", nil, &length, nil, 0) == 0, length > 1 else {
            return ""
        }

        var buffer = [CChar](repeating: 0, count: length)
        guard sysctlbyname("hw.model", &buffer, &length, nil, 0) == 0 else {
            return ""
        }
        return String(cString: buffer)
    }

    private func rebuildPlacement() {
        switch textAlignment {
        case .leading:
            touchBar.defaultItemIdentifiers = [Self.resultIdentifier, .flexibleSpace]
            touchBar.principalItemIdentifier = nil
        case .center:
            touchBar.defaultItemIdentifiers = [.flexibleSpace, Self.resultIdentifier, .flexibleSpace]
            touchBar.principalItemIdentifier = Self.resultIdentifier
        case .trailing:
            touchBar.defaultItemIdentifiers = [.flexibleSpace, Self.resultIdentifier]
            touchBar.principalItemIdentifier = nil
        }
    }

    private func makeContentView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 30))
        view.translatesAutoresizingMaskIntoConstraints = false

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.isHidden = true

        textLabel.font = .systemFont(ofSize: CGFloat(fontSize), weight: .semibold)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.allowsDefaultTighteningForTruncation = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [indicatorView, textLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 720),
            view.heightAnchor.constraint(equalToConstant: 30),
            indicatorView.widthAnchor.constraint(equalToConstant: 18),
            indicatorView.heightAnchor.constraint(equalToConstant: 18),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }

    private func updateAppearance() {
        textLabel.font = .systemFont(ofSize: CGFloat(fontSize), weight: .semibold)
        textLabel.textColor = resolvedTextColor().withAlphaComponent(CGFloat(textIntensity))
        switch textAlignment {
        case .leading:
            textLabel.alignment = .left
        case .center:
            textLabel.alignment = .center
        case .trailing:
            textLabel.alignment = .right
        }
    }

    private func resolvedTextColor() -> NSColor {
        switch textColor {
        case .system: return .labelColor
        case .white: return .white
        case .black: return .black
        case .gray: return .systemGray
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .red: return .systemRed
        }
    }

    private func oneLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
