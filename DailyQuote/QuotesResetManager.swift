import Foundation
import UserNotifications

/// Resets quote history + clears scheduled notifications once (for migration to a new Quotes.json).
enum QuotesResetManager {

    /// Bump this whenever you ship a new quotes.json or fix the selection logic
    /// so existing users get a clean slate (pointer reset to 0, history cleared).
    private static let quotesDataVersion = "quotes-v4"

    /// Stores the last reset version so it runs only once.
    private static let resetVersionKey = "quotes.reset.version"

    /// Must match the actual key used by ContentView / selectTodayQuote.
    private static let shownQuotesKey = "shownQuotes"

    /// The sequential pointer key (must match PersistKey.nextQuoteIndex).
    private static let nextIndexKey = "quotes.nextIndex"

    /// If you store AskAI recents or other caches, add keys here.
    private static let askAIRecentKey = "askai.recentQuotes"

    static func resetIfNeeded() {
        let ud = UserDefaults.standard

        // If already reset for this quotes version, do nothing.
        let already = ud.string(forKey: resetVersionKey)
        guard already != quotesDataVersion else { return }

        // 1) Clear the shown list
        ud.removeObject(forKey: shownQuotesKey)

        // 2) Reset the sequential pointer back to the first quote
        ud.set(0, forKey: nextIndexKey)

        // 3) Clear date-stamped stored quotes (keys like "yyyy-MM-dd")
        clearDateStampedQuotesFromUserDefaults()

        // 4) Optional: clear AskAI recents cache
        ud.removeObject(forKey: askAIRecentKey)

        // 5) Clear notifications that were scheduled using old data
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        // 6) Mark reset completed for this version
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
