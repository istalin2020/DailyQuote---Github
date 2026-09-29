// ProAccess.swift
import StoreKit

enum ProIDs {
    static let monthly = "askai.pro.monthly"
    static let yearly  = "askai.pro.yearly"
}

@MainActor
final class ProAccess: ObservableObject {
    static let shared = ProAccess()

    // MARK: – Testing override
    // Debug builds (Run from Xcode) are always PRO so every feature can be
    // tested. Archive uses the Release configuration, where DEBUG is not
    // defined, so App Store / TestFlight builds use real subscriptions only.
    #if DEBUG
    static let forceProForTesting = true
    #else
    static let forceProForTesting = false
    #endif

    // MARK: – Free-try constants
    static let initialFreeTriesAskAI   = 10
    static let initialFreeTriesCreate  = 10

    // Persisted keys (separate pools)
    private let keyAsk    = "askai.remainingFreeUses.ask"
    private let keyCreate = "askai.remainingFreeUses.create"

    // MARK: – Public state
    @Published private(set) var isPro: Bool = ProAccess.forceProForTesting
    /// The subscription the user currently owns (ProIDs.monthly / .yearly), nil if none.
    /// Not set by the Debug testing override — only by a real purchase.
    @Published private(set) var activeProductID: String?

    // 🔹 Separate counters
    @Published private(set) var remainingAskAI: Int = 0
    @Published private(set) var remainingCreateTheme: Int = 0

    @Published private(set) var products: [Product] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private var txUpdatesTask: Task<Void, Never>?

    // MARK: – Init
    init() {
        seedIfNeeded()                // ensure counters exist
        Task {
            await refreshProducts()
            await updateEntitlementFromTransactions()
            listenForTransactions()
        }
    }

    /// Ensure first-run defaults exist (10/10), then mirror them into @Published.
    func seedIfNeeded() {
            let ud = UserDefaults.standard

            if ud.object(forKey: keyAsk) == nil {
                ud.set(Self.initialFreeTriesAskAI, forKey: keyAsk)
            }
            if ud.object(forKey: keyCreate) == nil {
                ud.set(Self.initialFreeTriesCreate, forKey: keyCreate)
            }

            remainingAskAI       = ud.integer(forKey: keyAsk)
            remainingCreateTheme = ud.integer(forKey: keyCreate)
        }


    // MARK: - Helpers
        private func saveAsk(_ value: Int) {
            let v = max(0, value)
            remainingAskAI = v
            UserDefaults.standard.set(v, forKey: keyAsk)
        }
        private func saveCreate(_ value: Int) {
            let v = max(0, value)
            remainingCreateTheme = v
            UserDefaults.standard.set(v, forKey: keyCreate)
        }

        // MARK: - Gates
        func canUseAskAI() -> Bool          { isPro || remainingAskAI > 0 }
        func canUseCreateTheme() -> Bool    { isPro || remainingCreateTheme > 0 }

        // MARK: - Burn one credit (call AFTER a successful result)
        func consumeOneFreeUseAskAIIfNeeded() {
            guard !isPro, remainingAskAI > 0 else { return }
            saveAsk(remainingAskAI - 1)
        }
        func consumeCreateCreditIfNeeded() {
            guard !isPro, remainingCreateTheme > 0 else { return }
            saveCreate(remainingCreateTheme - 1)
        }
    
    // MARK: products / entitlement (unchanged logic)
    func refreshProducts() async {
        isLoading = true; defer { isLoading = false }
        let ids = [ProIDs.monthly, ProIDs.yearly]
        do {
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { $0.displayPrice < $1.displayPrice }
        } catch {
            lastError = error.localizedDescription
            products = []
        }
    }

    func listenForTransactions() {
        txUpdatesTask?.cancel()
        txUpdatesTask = Task.detached { [weak self] in
            for await _ in Transaction.updates {
                await self?.updateEntitlementFromTransactions()
            }
        }
    }

    func updateEntitlementFromTransactions() async {
        var latest: StoreKit.Transaction?
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.revocationDate == nil,
               [ProIDs.monthly, ProIDs.yearly].contains(tx.productID) {
                // If both show up (e.g. right after switching plans), the newest wins
                if latest == nil || tx.purchaseDate > latest!.purchaseDate { latest = tx }
            }
        }
        activeProductID = latest?.productID
        isPro = latest != nil || Self.forceProForTesting
    }

    // MARK: purchase/restore (unchanged)
    func purchase(product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let tx) = verification {
                await tx.finish()
                await updateEntitlementFromTransactions()
                return true
            }
            return false
        } catch { lastError = error.localizedDescription; return false }
    }

    func restore() async {
        do { try await AppStore.sync(); await updateEntitlementFromTransactions() }
        catch { lastError = error.localizedDescription }
    }
}
