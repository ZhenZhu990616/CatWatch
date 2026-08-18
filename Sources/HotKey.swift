import AppKit
import ApplicationServices
import Carbon
import Foundation

struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayText: String
    let keyEquivalent: String

    var menuModifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        return mask
    }

    static func parse(_ rawValue: String) throws -> HotKey {
        let tokens = rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map(String.init)

        guard !tokens.isEmpty else {
            throw AppError.hotKey("快捷键不能为空。")
        }

        var modifiers: UInt32 = 0
        var keyToken: String?

        for token in tokens {
            switch token {
            case "cmd", "command", "meta", "⌘":
                modifiers |= UInt32(cmdKey)
            case "ctrl", "control", "^", "⌃":
                modifiers |= UInt32(controlKey)
            case "opt", "option", "alt", "⌥":
                modifiers |= UInt32(optionKey)
            case "shift", "⇧":
                modifiers |= UInt32(shiftKey)
            default:
                guard keyToken == nil else {
                    throw AppError.hotKey("快捷键只能包含一个主按键。")
                }
                keyToken = token
            }
        }

        guard let keyToken, let keyCode = keyCodes[keyToken] else {
            throw AppError.hotKey("不支持这个快捷键按键：\(keyToken ?? rawValue)。")
        }

        if modifiers == 0 {
            throw AppError.hotKey("快捷键至少需要包含一个修饰键。")
        }

        return HotKey(
            keyCode: UInt32(keyCode),
            modifiers: modifiers,
            displayText: formatChord(modifiers: modifiers, key: keyToken),
            keyEquivalent: menuKeyEquivalent(for: keyToken)
        )
    }
}

enum DoubleTapKey: String, CaseIterable {
    case command
    case control
    case option
    case shift

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        }
    }

    var displayText: String {
        switch self {
        case .command: return "⌘ double tap"
        case .control: return "⌃ double tap"
        case .option: return "⌥ double tap"
        case .shift: return "⇧ double tap"
        }
    }
}

enum Shortcut {
    case chord(HotKey)
    case doubleTap(DoubleTapKey)

    var displayText: String {
        switch self {
        case .chord(let hotKey): return hotKey.displayText
        case .doubleTap(let key): return key.displayText
        }
    }

    static func parse(_ rawValue: String) throws -> Shortcut {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "double-tap", with: "double tap")
            .replacingOccurrences(of: "doubletap", with: "double tap")
            .replacingOccurrences(of: "双击", with: "double tap")
            .replacingOccurrences(of: "连按", with: "double tap")

        if normalized.contains("double tap") {
            let keyPart = normalized
                .replacingOccurrences(of: "double tap", with: "")
                .replacingOccurrences(of: "+", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch keyPart {
            case "cmd", "command", "meta", "⌘":
                return .doubleTap(.command)
            case "ctrl", "control", "^", "⌃":
                return .doubleTap(.control)
            case "opt", "option", "alt", "⌥":
                return .doubleTap(.option)
            case "shift", "⇧":
                return .doubleTap(.shift)
            default:
                throw AppError.hotKey("双击快捷键目前支持 ⌘、⌃、⌥、⇧。")
            }
        }

        return .chord(try HotKey.parse(rawValue))
    }
}

final class ShortcutRegistry {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var callbacks: [UInt32: () -> Void] = [:]
    private var doubleTapCallbacks: [(DoubleTapKey, () -> Void)] = []
    private var monitors: [Any] = []
    private var previousFlags: NSEvent.ModifierFlags = []
    private var lastPressTimes: [DoubleTapKey: TimeInterval] = [:]
    private let signature = fourCharCode("SLLM")

    func register(shortcut: Shortcut, id: UInt32, callback: @escaping () -> Void) throws {
        switch shortcut {
        case .chord(let hotKey):
            try ensureHandler()
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: id)
            let status = RegisterEventHotKey(
                hotKey.keyCode,
                hotKey.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

            guard status == noErr, let ref else {
                throw AppError.hotKey("快捷键注册失败：\(status)。")
            }

            hotKeyRefs.append(ref)
            callbacks[id] = callback
        case .doubleTap(let key):
            doubleTapCallbacks.append((key, callback))
            installDoubleTapMonitorsIfNeeded()
        }
    }

    /// 仅由用户主动操作触发系统授权提示。注册快捷键时不能调用它，
    /// 否则用户拒绝后每次重载快捷键都会再次弹窗。
    func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func unregisterAll() {
        hotKeyRefs.forEach { _ = UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        callbacks.removeAll()

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        doubleTapCallbacks.removeAll()
        lastPressTimes.removeAll()
        previousFlags = []
    }

    deinit {
        unregisterAll()
    }

    private func ensureHandler() throws {
        guard handlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let registry = Unmanaged<ShortcutRegistry>.fromOpaque(userData).takeUnretainedValue()
                registry.handle(event)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard status == noErr else {
            throw AppError.hotKey("快捷键事件监听安装失败：\(status)。")
        }
    }

    private func handle(_ event: EventRef?) {
        guard let event else { return }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == signature,
              let callback = callbacks[hotKeyID.id] else {
            return
        }

        DispatchQueue.main.async(execute: callback)
    }

    private func installDoubleTapMonitorsIfNeeded() {
        guard monitors.isEmpty else { return }

        let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event.modifierFlags)
        }
        if let global {
            monitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlags(event.modifierFlags)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let normalized = flags.intersection([.command, .control, .option, .shift])

        for (key, callback) in doubleTapCallbacks {
            let wasDown = previousFlags.contains(key.modifierFlag)
            let isDown = normalized.contains(key.modifierFlag)
            guard isDown, !wasDown else { continue }

            let now = Date().timeIntervalSince1970
            if let last = lastPressTimes[key], now - last <= 0.42 {
                lastPressTimes[key] = nil
                DispatchQueue.main.async(execute: callback)
            } else {
                lastPressTimes[key] = now
            }
        }

        previousFlags = normalized
    }

}

private let keyCodes: [String: Int] = [
    "a": 0,
    "s": 1,
    "d": 2,
    "f": 3,
    "h": 4,
    "g": 5,
    "z": 6,
    "x": 7,
    "c": 8,
    "v": 9,
    "b": 11,
    "q": 12,
    "w": 13,
    "e": 14,
    "r": 15,
    "y": 16,
    "t": 17,
    "1": 18,
    "2": 19,
    "3": 20,
    "4": 21,
    "6": 22,
    "5": 23,
    "=": 24,
    "9": 25,
    "7": 26,
    "-": 27,
    "8": 28,
    "0": 29,
    "]": 30,
    "o": 31,
    "u": 32,
    "[": 33,
    "i": 34,
    "p": 35,
    "return": 36,
    "enter": 36,
    "l": 37,
    "j": 38,
    "'": 39,
    "k": 40,
    ";": 41,
    "\\": 42,
    ",": 43,
    "/": 44,
    "n": 45,
    "m": 46,
    ".": 47,
    "tab": 48,
    "space": 49,
    "delete": 51,
    "backspace": 51,
    "escape": 53,
    "esc": 53,
    "left": 123,
    "right": 124,
    "down": 125,
    "up": 126
]

private func formatChord(modifiers: UInt32, key: String) -> String {
    var parts: [String] = []
    if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
    if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
    if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
    if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
    parts.append(key.uppercased())
    return parts.joined(separator: " ")
}

private func menuKeyEquivalent(for key: String) -> String {
    switch key {
    case "return", "enter":
        return "\r"
    case "tab":
        return "\t"
    case "space":
        return " "
    case "delete", "backspace":
        return "\u{8}"
    case "escape", "esc":
        return "\u{1b}"
    case "left":
        return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
    case "right":
        return String(UnicodeScalar(NSRightArrowFunctionKey)!)
    case "down":
        return String(UnicodeScalar(NSDownArrowFunctionKey)!)
    case "up":
        return String(UnicodeScalar(NSUpArrowFunctionKey)!)
    default:
        return key.lowercased()
    }
}

func formattedShortcut(_ rawValue: String) -> String {
    (try? Shortcut.parse(rawValue).displayText) ?? rawValue
}

func rawKeyName(for event: NSEvent) -> String? {
    if let character = event.charactersIgnoringModifiers?.lowercased(), keyCodes[character] != nil {
        return character
    }

    return keyCodes.first { $0.value == Int(event.keyCode) }?.key
}

private func fourCharCode(_ value: String) -> OSType {
    var result: OSType = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}
