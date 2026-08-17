import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case shortcuts
    case prompt
    case model
    case appearance
    case service

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortcuts: return "快捷键"
        case .prompt: return "提示词"
        case .model: return "模型"
        case .appearance: return "外观"
        case .service: return "服务"
        }
    }

    var symbolName: String {
        switch self {
        case .shortcuts: return "command"
        case .prompt: return "text.bubble"
        case .model: return "cpu"
        case .appearance: return "slider.horizontal.3"
        case .service: return "person.crop.circle"
        }
    }
}
