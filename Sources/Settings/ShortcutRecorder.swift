import AppKit
import Carbon
import SwiftUI

struct SettingsShortcutRecorder: NSViewRepresentable {
    @Binding var text: String
    let accessibilityLabel: String

    func makeNSView(context: Context) -> SettingsShortcutCaptureButton {
        let button = SettingsShortcutCaptureButton()
        button.setAccessibilityLabel(accessibilityLabel)
        button.onChange = { text = $0 }
        return button
    }

    func updateNSView(_ nsView: SettingsShortcutCaptureButton, context: Context) {
        nsView.setAccessibilityLabel(accessibilityLabel)
        if nsView.shortcutText != text {
            nsView.shortcutText = text
        }
    }
}

final class SettingsShortcutCaptureButton: NSButton {
    var onChange: ((String) -> Void)?

    var shortcutText = "" {
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
    private var resignKeyObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateInputAppearance()
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        resignKeyObserver = window.map { window in
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.cancelRecording()
            }
        }
    }

    deinit {
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        stopRecording()
    }

    private func setup() {
        target = self
        action = #selector(startRecording)
        isBordered = false
        bezelStyle = .shadowlessSquare
        controlSize = .regular
        alignment = .center
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        wantsLayer = false
        updateInputAppearance()
        title = formattedShortcut(shortcutText)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateInputAppearance()
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        alphaValue = flag ? 0.72 : 1
    }

    private func updateInputAppearance() {
        contentTintColor = .controlAccentColor
    }

    @objc private func startRecording() {
        stopRecording()
        isRecording = true
        title = "按下快捷键…"
        window?.makeFirstResponder(self)

        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.recordKeyDown(event)
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
                if !bounds.contains(convert(event.locationInWindow, from: nil)) {
                    cancelRecording()
                }
                return event
            }
        ) {
            monitors.append(mouseMonitor)
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
    }

    private func recordFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        for key in DoubleTapKey.allCases {
            let wasDown = previousFlags.contains(key.modifierFlag)
            let isDown = flags.contains(key.modifierFlag)
            guard isDown, !wasDown else { continue }

            let now = Date().timeIntervalSince1970
            if let last = lastPressTimes[key], now - last <= 0.42 {
                shortcutText = "\(key.rawValue) double tap"
                stopRecording()
                return
            }
            lastPressTimes[key] = now
        }
        previousFlags = flags
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
}
