import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var access = ProAccess.shared

    enum Plan: String { case monthly, yearly }
    @State private var selectedPlan: Plan = .yearly
    @State private var purchasing = false
    @State private var alertMessage: String?

    // MARK: - Quick lookup helpers (now use ProIDs)
    private var monthly: Product? { access.products.first { $0.id == ProIDs.monthly } }
    private var yearly:  Product? { access.products.first { $0.id == ProIDs.yearly  } }
    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly: return monthly
        case .yearly:  return yearly
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.10, green: 0.14, blue: 0.22, opacity: 1.0),
                    Color(.sRGB, red: 0.05, green: 0.09, blue: 0.16, opacity: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                // Header (Close on the right)
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Title + subtitle
                VStack(spacing: 10) {
                    Text("Go PRO to use **AI for Quote & Theme**")
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text("Unlimited AI-generated quotes & Theme. Priority server access. No daily limits.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 6)

                // Feature bullets (glass card)
                VStack(alignment: .leading, spacing: 10) {
                    labelRow("Unlimited AI Quote & Theme", system: "infinity")
                    labelRow("Fast responses", system: "bolt.fill")
                    labelRow("Priority during peak times", system: "speedometer")
                    labelRow("Supports future improvements", system: "heart.fill")
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))

                // Plan selector
                planCards

                // Big PRO button
                Button {
                    Task { await goProTapped() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill").imageScale(.medium)
                        Text(purchasing ? "Processing…" : "GO PRO")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [Color.purple, Color.blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.18), lineWidth: 1))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                }
                .disabled(purchasing || selectedProduct == nil)
                .opacity(selectedProduct == nil ? 0.6 : 1)

                // Restore + legal
                VStack(spacing: 8) {
                    Button("Restore Purchases") {
                        Task { await access.restore() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))

                    Text("Payment is processed by Apple using your Apple ID. Subscriptions auto-renew until cancelled in Settings.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .task {
            await access.refreshProducts() // load products on appear
        }
        .alert("Purchase unavailable", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Subviews
    private func labelRow(_ text: String, system: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .foregroundStyle(.white)
                .frame(width: 20)
            Text(text)
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            planCard(title: "Monthly",
                     price: monthly?.displayPrice ?? "INR 29/-",
                     blurb: "≈ less than 1 INR/day",
                     selected: selectedPlan == .monthly) { selectedPlan = .monthly }

            planCard(title: "Yearly",
                     price: yearly?.displayPrice ?? "INR 299/-",
                     blurb: "Best value • 2 months free*",
                     selected: selectedPlan == .yearly) { selectedPlan = .yearly }
        }
        .overlay(
            Group {
                if access.products.isEmpty {
                    Text("Tap to load prices")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            },
            alignment: .bottomTrailing
        )
        .onTapGesture {
            Task { await access.refreshProducts() }
        }
    }

    private func planCard(title: String,
                          price: String,
                          blurb: String,
                          selected: Bool,
                          onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if selected {
                            Text("SELECTED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.white.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(blurb)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text(price)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                (selected
                 ? AnyShapeStyle(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.55), Color.blue.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                 )
                 : AnyShapeStyle(Color.white.opacity(0.06))),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(selected ? 0.28 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
    private func goProTapped() async {
        // If products aren’t loaded yet, try to load them now
        if selectedProduct == nil {
            await access.refreshProducts()
        }
        guard let product = selectedProduct else {
            await MainActor.run {
                alertMessage =
                """
                We couldn’t load products yet.
                • Check your product IDs (\(ProIDs.monthly) / \(ProIDs.yearly))
                • Make sure you’re signed in as a Sandbox tester on device
                • Confirm In-App Purchase capability and network
                Try again in a moment.
                """
            }
            return
        }
        purchasing = true
        defer { purchasing = false }
        let ok = await access.purchase(product: product)
        if ok { await MainActor.run { dismiss() } }
    }
}
