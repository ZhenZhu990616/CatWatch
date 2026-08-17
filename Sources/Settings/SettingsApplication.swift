import Foundation

struct SettingsApplication {
    let persist: (ConfigDraft) -> Void
    let appearance: (ConfigDraft) throws -> Void
    let shortcuts: (ConfigDraft) throws -> Void
    let client: (ConfigDraft) throws -> Void

    func apply(
        _ proposed: ConfigDraft,
        to current: inout ConfigDraft,
        scope: SettingsUpdateScope
    ) throws {
        let previous = current
        var merged = proposed
        merged.panelWidth = previous.panelWidth
        merged.panelHeight = previous.panelHeight
        merged.panelOriginX = previous.panelOriginX
        merged.panelOriginY = previous.panelOriginY

        do {
            switch scope {
            case .appearance:
                try appearance(merged)
            case .shortcuts:
                try shortcuts(merged)
            case .client:
                try client(merged)
            case .storageOnly:
                break
            }

            persist(merged)
            current = merged
        } catch {
            if scope == .shortcuts {
                try? shortcuts(previous)
            }
            current = previous
            throw error
        }
    }
}
