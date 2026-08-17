import Foundation
import SwiftUI

enum SettingsField: Hashable {
    case model
    case prompt
    case instructions
    case captureShortcut
    case selectionShortcut
    case panelShortcut
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var draft: ConfigDraft
    @Published private(set) var lastAppliedDraft: ConfigDraft
    @Published private(set) var state: SettingsState
    @Published private(set) var fieldErrors: [SettingsField: String] = [:]

    private let draftProvider: () -> ConfigDraft
    private let stateProvider: () -> SettingsState
    private let applyDraft: (ConfigDraft, SettingsUpdateScope) throws -> Void
    private let debounceNanoseconds: UInt64
    private var pendingTextTasks: [SettingsField: Task<Void, Never>] = [:]

    init(
        initialDraft: ConfigDraft,
        draftProvider: (() -> ConfigDraft)? = nil,
        stateProvider: @escaping () -> SettingsState,
        applyDraft: @escaping (ConfigDraft, SettingsUpdateScope) throws -> Void,
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        draft = initialDraft
        lastAppliedDraft = initialDraft
        self.draftProvider = draftProvider ?? { initialDraft }
        self.stateProvider = stateProvider
        self.applyDraft = applyDraft
        self.debounceNanoseconds = debounceNanoseconds
        state = stateProvider()
    }

    func reload() {
        state = stateProvider()
        guard pendingTextTasks.isEmpty, fieldErrors.isEmpty else { return }
        let latest = draftProvider()
        draft = latest
        lastAppliedDraft = latest
    }

    func binding<Value: Equatable>(
        _ keyPath: WritableKeyPath<ConfigDraft, Value>,
        scope: SettingsUpdateScope
    ) -> Binding<Value> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.set($0, at: keyPath, scope: scope) }
        )
    }

    func set<Value: Equatable>(
        _ value: Value,
        at keyPath: WritableKeyPath<ConfigDraft, Value>,
        scope: SettingsUpdateScope
    ) {
        guard draft[keyPath: keyPath] != value else { return }

        draft[keyPath: keyPath] = value
        var candidate = lastAppliedDraft
        candidate[keyPath: keyPath] = value

        do {
            try applyDraft(candidate, scope)
            lastAppliedDraft = candidate
        } catch {
            draft[keyPath: keyPath] = lastAppliedDraft[keyPath: keyPath]
        }
    }

    func textBinding(
        _ keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) -> Binding<String> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.setText($0, at: keyPath, field: field) }
        )
    }

    func setText(
        _ value: String,
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        draft[keyPath: keyPath] = value
        fieldErrors[field] = nil
        pendingTextTasks[field]?.cancel()
        pendingTextTasks[field] = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            applyText(at: keyPath, field: field)
            pendingTextTasks[field] = nil
        }
    }

    func shortcutBinding(
        _ keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) -> Binding<String> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { self.setShortcut($0, at: keyPath, field: field) }
        )
    }

    func setShortcut(
        _ value: String,
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        do {
            _ = try Shortcut.parse(value)

            var candidate = lastAppliedDraft
            candidate[keyPath: keyPath] = value
            let shortcuts = [
                try Shortcut.parse(candidate.hotKeyText).displayText,
                try Shortcut.parse(candidate.selectionHotKeyText).displayText,
                try Shortcut.parse(candidate.panelHotKeyText).displayText
            ]
            guard Set(shortcuts).count == shortcuts.count else {
                throw SettingsValidationError.duplicateShortcut
            }

            try applyDraft(candidate, .shortcuts)
            draft[keyPath: keyPath] = value
            lastAppliedDraft = candidate
            fieldErrors[field] = nil
        } catch {
            draft[keyPath: keyPath] = lastAppliedDraft[keyPath: keyPath]
            fieldErrors[field] = error.localizedDescription
        }
    }

    func error(for field: SettingsField) -> String? {
        fieldErrors[field]
    }

    private func applyText(
        at keyPath: WritableKeyPath<ConfigDraft, String>,
        field: SettingsField
    ) {
        let value = draft[keyPath: keyPath]
        if field == .model && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors[field] = "模型不能为空。"
            return
        }

        var candidate = lastAppliedDraft
        candidate[keyPath: keyPath] = field == .model
            ? value.trimmingCharacters(in: .whitespacesAndNewlines)
            : value

        do {
            try applyDraft(candidate, .client)
            lastAppliedDraft = candidate
            draft[keyPath: keyPath] = candidate[keyPath: keyPath]
            fieldErrors[field] = nil
        } catch {
            fieldErrors[field] = error.localizedDescription
        }
    }
}

enum SettingsValidationError: LocalizedError {
    case duplicateShortcut

    var errorDescription: String? {
        switch self {
        case .duplicateShortcut:
            return "不能与其他 CatWatch 快捷键重复。"
        }
    }
}
