import Foundation
import UserNotifications

/// Resets quote history + clears scheduled notifications once per version bump.
/// After reset the deterministic anchor-based selection starts fresh from
/// quote index 0 on today's date.
enum QuotesResetManager {

    /// Bump this whenever you ship a new quotes.json or fix the selection logic
    /// so existing users get a clean slate.
    private static let quotesDataVersion = "quotes-v7"

    private static let resetVersionKey   = "quotes.reset.version"
    private static let shownQuotesKey    = "shownQuotes"
    private static let anchorDateKey     = "quotes.anchorDate"

    // Legacy keys to clean up from previous versions
    private static let legacyNextIndex   = "quotes.nextIndex"
    private static let legacyPickDate    = "quotes.lastPickDate"
    private static let legacyAdvanceDate = "quotes.lastAdvanceDate"
    private static let askAIRecentKey    = "askai.recentQuotes"

    static func resetIfNeeded() {
        let ud = UserDefaults.standard

        let already = ud.string(forKey: resetVersionKey)
        guard already != quotesDataVersion else { return }

        // 1) Clear shown history
        ud.removeObject(forKey: shownQuotesKey)

        // 2) Set anchor date to today so quote index 0 starts now
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        ud.set(f.string(from: Date()), forKey: anchorDateKey)

        // 3) Remove legacy pointer/tracking keys
        ud.removeObject(forKey: legacyNextIndex)
        ud.removeObject(forKey: legacyPickDate)
        ud.removeObject(forKey: legacyAdvanceDate)

        // 4) Clear ALL date-stamped stored quotes (keys like "yyyy-MM-dd")
        clearDateStampedQuotesFromUserDefaults()

        // 5) Clear AskAI recents cache
        ud.removeObject(forKey: askAIRecentKey)

        // 6) Clear stale notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        // 7) Mark reset completed
        ud.set(quotesDataVersion, forKey: resetVersionKey)

        print("✅ QuotesResetManager: reset done for \(quotesDataVersion)")
    }

    private static func clearDateStampedQuotesFromUserDefaults() {
        let ud = UserDefaults.standard
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for k in ud.dictionaryRepresentation().keys {
            if df.date(from: k) != nil {
                ud.removeObject(forKey: k)
            }
        }
    }
}
