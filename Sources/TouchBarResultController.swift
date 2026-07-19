import AppKit

final class TouchBarResultController: NSObject, NSTouchBarDelegate {
    private static let resultIdentifier = NSTouchBarItem.Identifier("CatWatch.touchBar.result")

    private let touchBar = NSTouchBar()
    private let indicatorView = PhaseIndicatorView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
    private let textLabel = NSTextField(labelWithString: "")
    private lazy var contentView = makeContentView()

    private var fontSize = ConfigDraft.defaultTouchBarFontSize
    private var textColor = ConfigDraft.defaultTouchBarTextColor
    private var textIntensity = ConfigDraft.defaultTouchBarTextIntensity
    private var textAlignment = ConfigDraft.defaultTouchBarTextAlignment
    private var isVisible = false

    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("CatWatch.touchBar")
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
        item.customizationLabel = "CatWatch 回答"
        item.view = contentView
        return item
    }

    private func present() {
        guard !isVisible else { return }
        // system modal 方式（Pock 同款，DFRFoundation 私有 API）不需要激活应用
        // 即可显示：不抢用户当前应用的焦点，用户切换应用后结果也不会消失。
        // 私有 API 不可用时降级为旧方案（设置应用级 touchBar 并激活自身）。
        if Self.performSystemModal(selectorName: "presentSystemModalTouchBar:systemTrayItemIdentifier:", touchBar: touchBar) {
            isVisible = true
            return
        }
        NSApp.touchBar = touchBar
        isVisible = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismiss() {
        guard isVisible else { return }
        if !Self.performSystemModal(selectorName: "dismissSystemModalTouchBar:", touchBar: touchBar) {
            if NSApp.touchBar === touchBar {
                NSApp.touchBar = nil
            }
        }
        isVisible = false
    }

    private static let dfrFoundationHandle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY)

    private static var dfrFoundationLoaded: Bool { dfrFoundationHandle != nil }

    /// 本机是否有可用的 Touch Bar（实体或模拟器）。
    /// 用 DFRFoundation 的 DFRSupportsTouchBar() 判断，供上层在无 Touch Bar 时
    /// 回退到悬浮窗，避免答案落入黑洞。
    static let isAvailable: Bool = {
        guard let handle = dfrFoundationHandle,
              let symbol = dlsym(handle, "DFRSupportsTouchBar") else {
            return false
        }
        typealias SupportsFn = @convention(c) () -> Bool
        return unsafeBitCast(symbol, to: SupportsFn.self)()
    }()

    @discardableResult
    private static func performSystemModal(selectorName: String, touchBar: NSTouchBar) -> Bool {
        guard dfrFoundationLoaded else { return false }
        let selector = NSSelectorFromString(selectorName)
        let target = NSTouchBar.self as AnyObject
        guard target.responds(to: selector) else { return false }
        if selectorName.contains("present") {
            _ = target.perform(selector, with: touchBar, with: nil)
        } else {
            _ = target.perform(selector, with: touchBar)
        }
        return true
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
