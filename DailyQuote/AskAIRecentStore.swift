import Foundation

final class AskAIRecentStore {
    static let shared = AskAIRecentStore()
    private let key = "askai.recent.quotes"
    private let maxCount = 20

    private init() {}

    var recent: [String] {
        (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
    }

    func add(_ quote: String) {
        var set = recent.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // Keep newest first; prevent duplicates
        set.removeAll { $0.caseInsensitiveCompare(quote) == .orderedSame }
        set.insert(quote, at: 0)
        if set.count > maxCount { set = Array(set.prefix(maxCount)) }
        UserDefaults.standard.set(set, forKey: key)
    }

    func contains(_ quote: String) -> Bool {
        recent.contains { $0.caseInsensitiveCompare(quote) == .orderedSame }
    }
}
