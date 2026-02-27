import Foundation
import SwiftUI

@MainActor
struct AskAIGate {
    let pro = ProAccess.shared

    func allowOrShowPaywall(triggerPaywall: () -> Void) -> Bool {
        if pro.canUseAskAI() { return true }
        triggerPaywall()
        return false
    }

    func markUsed() {
        // 🔧 use the method that actually exists
        pro.consumeOneFreeUseAskAIIfNeeded()
    }
}
