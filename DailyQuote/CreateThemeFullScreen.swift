import SwiftUI

struct CreateThemeFullScreen: View {
    @Environment(\.dismiss) private var dismiss

    /// Parent gets called after a successful save.
    var onCreated: (_ image: UIImage, _ name: String) -> Void

    // UI state
    @State private var prompt: String = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var preview: UIImage?
    @FocusState private var focus: Bool

    // PRO / Free-tries
    @StateObject private var access = ProAccess.shared
    @State private var showProPaywall = false

    private var canGenerateNow: Bool { access.isPro || access.remainingCreateTheme > 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top
                let bottomInset = proxy.safeAreaInsets.bottom
                let previewHeight = min(380, proxy.size.height * 0.38)

                ScrollView {
                    VStack(spacing: 18) {

                        // Header
                        HStack(alignment: .firstTextBaseline) {
                            Text("Create Theme")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            // Badge: "PRO Active" OR "Free tries left: N"
                            entitlementBadge

                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.headline.weight(.semibold))
                                    .padding(8)
                            }
                            .tint(.white)
                            .accessibilityLabel("Close")
                        }
                        .padding(.top, 8)

                        // Prompt
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $prompt)
                                .focused($focus)
                                .font(.body)
                                .frame(height: 110)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(.black.opacity(0.15))
                                .foregroundColor(.white)

                            if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Describe a beautiful wallpaper you want (e.g. “golden sunrise over mountains”).")
                                    .font(.callout)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 16).padding(.leading, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: prompt) { _ in errorText = nil }
                        
                        let canGenerateNow = access.isPro || access.remainingCreateTheme > 0

                        // Generate / Go PRO button
                        Button {
                            if access.isPro || access.remainingCreateTheme > 0 {
                                    Task { await generate() }
                                } else {
                                showProPaywall = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isLoading ? "hourglass" : (canGenerateNow ? "wand.and.stars" : "crown"))
                                Text(isLoading
                                     ? "Generating…"
                                     : (canGenerateNow ? "Generate Image" : "Go PRO to Continue"))
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.blue, .cyan],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(isLoading)    // only disable while loading
                        .opacity(isLoading ? 0.6 : 1)

                        // Error
                        if let err = errorText {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Result preview
                        Group {
                            if let img = preview {
                                Image(uiImage: img)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: previewHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
                            } else {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.black.opacity(0.15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: previewHeight)
                                    .overlay(Text("Your image will appear here").foregroundStyle(.white.opacity(0.55)))
                            }
                        }

                        // Done = save + remember + apply + callback
                        Button {
                            Task { await saveAndApply() }
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundColor(.white)
                        }
                        .disabled(preview == nil || isLoading)
                        .opacity((preview == nil || isLoading) ? 0.6 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14 + topInset)
                    .padding(.bottom, 16 + bottomInset)
                }
            }
        }
        .interactiveDismissDisabled(true)
        .task {
            focus = true
            ProAccess.shared.seedIfNeeded()                 // ← ensure first-run value is 10
            await access.updateEntitlementFromTransactions()
        }
        .fullScreenCover(isPresented: $showProPaywall) {
            PaywallView()
        }
    }

    // MARK: - Badge view
    @ViewBuilder
    private var entitlementBadge: some View {
        if access.isPro {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill").font(.caption.bold())
                Text("PRO Active").font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.green.opacity(0.20)))
            .overlay(Capsule().stroke(Color.green.opacity(0.55), lineWidth: 1))
            .foregroundColor(.green)
            .accessibilityLabel("PRO Active")
        } else {
            Text("Free tries left: \(access.remainingCreateTheme)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Actions

    /// Calls your generator and shows a preview.
    @MainActor
    private func generate() async {
        errorText = nil
        preview = nil
        focus = false

        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard p.count >= 8 else {
            errorText = "Please describe at least 8 characters."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Use the API's best portrait size (1024x1792); the save step will
            // scale it to device-resolution without blurring since the source is
            // already high-res portrait.
            let img = try await AIImageService.shared.generateImage(prompt: p, size: "1024x1792")
            preview = img

            // Burn one Create credit on success for non-PRO
            ProAccess.shared.consumeCreateCreditIfNeeded()
        } catch {
            if let le = error as? LocalizedError, let msg = le.errorDescription, !msg.isEmpty {
                errorText = msg
            } else {
                errorText = error.localizedDescription
            }
        }
    }

    /// Persists the preview image, registers it, applies it, then informs the parent.
    @MainActor
    private func saveAndApply() async {
        guard let img = preview else { return }

        let short = ThemeCatalog.shortName(from: prompt)

        guard let path = ThemeCatalog.savePNG(image: img, filename: short) else {
            errorText = "Couldn’t save image to Documents."
            return
        }

        ThemeCatalog.appendCustomPath(path)

        let item = ThemeCatalog.Item(
            displayName: short,
            category: .beautiful,
            source: .file(path)
        )
        ThemeState.shared.apply(item)

        onCreated(img, short)
        dismiss()
    }
}

// MARK: - Small helper (file-scope)
private extension String {
    var trimmedCount: Int {
        trimmingCharacters(in: .whitespacesAndNewlines).count
    }
}

extension UIImage {
    /// Force a portrait 9:16 image and resize to a target size.
    /// Crops the long edge (center-crop) to preserve composition.
    func enforcingPortrait(target: CGSize = CGSize(width: 1242, height: 2688)) -> UIImage {
        let targetRatio = target.width / target.height  // ≈ 0.4625 (9:16)

        // 1) If already portrait and close to 9:16, just resize.
        let isPortrait = size.height >= size.width
        let ratio = size.width / size.height
        let closeEnough = abs(ratio - targetRatio) < 0.02

        var cropRect = CGRect(origin: .zero, size: size)

        if isPortrait && closeEnough {
            // no crop, only scale
        } else {
            // 2) Center-crop to 9:16 in *source* pixels
            if ratio > targetRatio {
                // too wide → trim width
                let newWidth = size.height * targetRatio
                cropRect.origin.x = (size.width - newWidth) / 2.0
                cropRect.size.width = newWidth
            } else {
                // too tall or landscape → trim height
                let newHeight = size.width / targetRatio
                cropRect.origin.y = (size.height - newHeight) / 2.0
                cropRect.size.height = newHeight
            }
        }

        guard let cg = self.cgImage?.cropping(to: cropRect.integral) else {
            return self // fallback if cropping fails
        }

        let cropped = UIImage(cgImage: cg, scale: self.scale, orientation: self.imageOrientation)

        // 3) Scale to the exact target pixels
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
