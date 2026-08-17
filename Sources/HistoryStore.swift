import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let prompt: String
    let answer: String
}

/// 问答历史：JSON 持久化到 ~/Library/Application Support/CatGPT/history.json，
/// 上限 50 条，新的在前。所有调用都在主线程（AppDelegate）。
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let limit = 50
    private let fileURL: URL
    /// 串行写盘：保证"添加"与"清空"的快照按发起顺序落盘，
    /// 不会出现旧快照晚到覆盖新快照。
    private let writeQueue = DispatchQueue(label: "CatGPT.HistoryStore", qos: .utility)

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("CatGPT", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    func add(prompt: String, answer: String) {
        entries.insert(HistoryEntry(id: UUID(), date: Date(), prompt: prompt, answer: answer), at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        persist()
    }

    func entry(withId id: UUID) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    func clear() {
        entries = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        let snapshot = entries
        let url = fileURL
        writeQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
