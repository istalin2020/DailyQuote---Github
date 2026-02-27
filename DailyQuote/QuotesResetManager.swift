import Foundation
import UserNotifications

/// Resets quote history + clears scheduled notifications once (for migration to a new Quotes.json).
enum QuotesResetManager {

    /// Change this value whenever you ship a new quotes.json and want to force-reset history.
    /// Example: "quotes-v3", "quotes-2026-02", etc.
    private static let quotesDataVersion = "quotes-v3"

    /// Stores the last reset version so it runs only once.
    private static let resetVersionKey = "quotes.reset.version"

    /// Your existing key that stores shown quote texts.
    /// Update this if your project uses a different constant name.
    private static let shownQuotesKey = "kShownQuotes"

    /// If you store AskAI recents or other caches, add keys here.
    private static let askAIRecentKey = "askai.recentQuotes"   // optional (safe to remove if unused)

    static func resetIfNeeded() {
        let ud = UserDefaults.standard

        // If already reset for this quotes version, do nothing.
        let already = ud.string(forKey: resetVersionKey)
        guard already != quotesDataVersion else { return }

        // 1) Clear the shown list
        ud.removeObject(forKey: shownQuotesKey)

        // 2) Clear date-stamped stored quotes (keys like "yyyy-MM-dd")
        clearDateStampedQuotesFromUserDefaults()

        // 3) Optional: clear AskAI recents cache if you want
        // (remove this line if you don't want to wipe AskAI recents)
        ud.removeObject(forKey: askAIRecentKey)

        // 4) Clear notifications that were scheduled using old data
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        // 5) Mark reset completed for this version
        ud.set(quotesDataVersion, forKey: resetVersionKey)

        print("✅ QuotesResetManager: reset done for version:", quotesDataVersion)
    }

    private static func clearDateStampedQuotesFromUserDefaults() {
        let ud = UserDefaults.standard
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let allKeys = ud.dictionaryRepresentation().keys

        for k in allKeys {
            if df.date(from: k) != nil {
                ud.removeObject(forKey: k)
            }
        }
    }
}
