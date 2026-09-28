// Daily Quote Development - Final Code Submitted to Apple
// Includes full working SwiftUI app with:
// - JSON-loaded quote engine
// - Daily notification at user-set time
// - Quote sharing with styled image and author photo blending
// - Quote history view
// - Time picker with persistent selection and haptic feedback
// - Mood-based background and author photo in share image

import SwiftUI
import UserNotifications
import BackgroundTasks
import UIKit
import UserNotifications

// Used for .sheet(item:) to avoid the "Any has no member sheet" error
struct SharePayload: Identifiable { let id = UUID(); let image: UIImage }


struct DailyQuoteView: View {
    // MARK: - State
    @State private var quote: BookQuote = BookQuote(text: "", author: "")
    @State private var allQuotes: [BookQuote] = []

    @State private var selectedHour: Int = (UserDefaults.standard.object(forKey: "selectedHour") as? Int) ?? 7
    @State private var selectedMinute: Int = (UserDefaults.standard.object(forKey: "selectedMinute") as? Int) ?? 0

    @State private var showHistory = false
    @State private var showTimePicker = false
    @State private var showThemePickerSheet = false

    @State private var shareItem: SharePayload?
    @State private var selectionHaptic = UISelectionFeedbackGenerator()

    @State private var showComposeSheet = false
    @State private var customQuoteText = ""
    @State private var customAuthor = ""
    @State private var customBook = ""
    @State private var composeText   = ""
    @State private var composeAuthor = ""
    @State private var composeBook   = ""
    // Ask AI
    @State private var showAskAISheet = false
    @State private var aiPrompt: String = ""
    @State private var aiQuote: String = ""
    @State private var aiLoading = false
    @State private var aiError: String?

    // === NEW: direct Pro sheet + entitlement state
    @State private var showPaywall = false
    @State private var showProPaywall = false
    @StateObject private var pro = ProAccess.shared
    @StateObject private var access = ProAccess.shared
    @StateObject private var theme = ThemeState.shared
    //@ObservedObject private var access = ProAccess.shared
    //@ObservedObject private var theme = ThemeState.shared

    private var currentThemeName: String { ThemeCatalog.name(for: theme.currentIndex) }
    private var themeNames: [String]    { ThemeCatalog.names }
    
    // MARK: - Adaptive colors from background
    // REPLACE your adaptiveTextColor with this version (no ThemeCatalog.uiImage(for: theme.current)):
    private var adaptiveTextColor: Color {
        // Guaranteed image (uses Home theme or a safe gradient)
        let img = theme.currentUIImageOrFallback(size: CGSize(width: 800, height: 800))
        let L = img.averageLuminance ?? 0.5
        return L < 0.55 ? Color.white.opacity(0.95) : Color.black.opacity(0.90)
    }

    private var readabilityOverlay: LinearGradient {
        LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.45)],
                       startPoint: .top, endPoint: .bottom)
    }
    
    // MARK: - Persistence keys
    private enum PersistKey {
        static let appVersion       = "app.version"                  // stores last app version that ran migrations
        static let shownQuotes      = "shownQuotes"                  // [String] of quote.text that were shown
        static let selectedHour     = "selectedHour"
        static let selectedMinute   = "selectedMinute"

        // Legacy (2.0) examples – only used if they existed; safe to leave if you never had them.
        static let legacyShownV2    = "history_shown"                // [String] (example)
        static let legacyHour       = "notifyHour"                   // Int (example)
        static let legacyMinute     = "notifyMinute"                 // Int (example)
    }

    // Parse "1.2.3" into comparable tuple
    private func versionTuple(_ s: String) -> (Int,Int,Int) {
        let parts = s.split(separator: ".").map { Int($0) ?? 0 }
        let a = parts.count > 0 ? parts[0] : 0
        let b = parts.count > 1 ? parts[1] : 0
        let c = parts.count > 2 ? parts[2] : 0
        return (a,b,c)
    }
    
    /// Run once when moving from 2.x → 3.x. Preserves history and notification time.
    private func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "3.0"
        let already = defaults.string(forKey: PersistKey.appVersion)

        // If we've already migrated for this or a newer version, do nothing.
        if let v = already, versionTuple(v) >= versionTuple(current) { return }

        // ---- Merge any legacy history arrays into the current one (if they existed) ----
        let existingShown = Set(defaults.stringArray(forKey: PersistKey.shownQuotes) ?? [])
        let legacyShown   = Set(defaults.stringArray(forKey: PersistKey.legacyShownV2) ?? [])
        let mergedShown   = Array(existingShown.union(legacyShown))
        if !mergedShown.isEmpty {
            defaults.set(mergedShown, forKey: PersistKey.shownQuotes)
        }

        // ---- Preserve notification time if legacy keys were used in 2.0 ----
        if defaults.object(forKey: PersistKey.selectedHour) == nil,
           let h = defaults.object(forKey: PersistKey.legacyHour) as? Int {
            defaults.set(h, forKey: PersistKey.selectedHour)
        }
        if defaults.object(forKey: PersistKey.selectedMinute) == nil,
           let m = defaults.object(forKey: PersistKey.legacyMinute) as? Int {
            defaults.set(m, forKey: PersistKey.selectedMinute)
        }

        // Mark migration complete for this version
        defaults.set(current, forKey: PersistKey.appVersion)
    }

    // --- Button styles (re-add) ---
    struct LinkChipStyleCompact: ButtonStyle {
        var fg: Color
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.clear, in: Capsule())
                .overlay(Capsule().stroke(fg.opacity(0.30), lineWidth: 1))
                .foregroundStyle(fg)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
        }
    }
    struct AccentPillStyleCompact: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [.blue, .cyan],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.30), lineWidth: 0.5))
                .foregroundStyle(.white)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
        }
    }
    struct IconCircleStyleCompact: ButtonStyle {
        var fg: Color
        var outlined: Bool = false
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Color.clear, in: Circle())
                .overlay(Circle().stroke(fg.opacity(outlined ? 0.35 : 0.28), lineWidth: 1))
                .foregroundStyle(fg)
                .scaleEffect(configuration.isPressed ? 0.93 : 1)
        }
    }
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Top bar (transparent, compact, sits over wallpaper)
    @ViewBuilder
    private var topBar: some View {
        GeometryReader { geo in
            let isTight = geo.size.width < 380
            let fg = adaptiveTextColor

            HStack(spacing: isTight ? 10 : 14) {

                // LEFT cluster: History • Theme • Ask AI (+ PRO badge)
                HStack(spacing: isTight ? 10 : 14) {
                    Button("History") { showHistory = true }
                        .buttonStyle(LinkChipStyleCompact(fg: fg))
                        .lineLimit(1)

                    // Theme with PRO badge (only when access.isPro)
                    ZStack(alignment: .topTrailing) {
                        Button("Theme") { showThemePickerSheet = true }
                            .buttonStyle(LinkChipStyleCompact(fg: fg))
                            .lineLimit(1)

                        if access.isPro {
                            Text("PRO")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                                .offset(x: 6, y: -6)   // tiny hang-off, same feel as Ask AI tag
                                .allowsHitTesting(false)
                        }
                    }

                    Button { showAskAISheet = true } label: {
                        HStack(spacing: 6) {
                            Text("Ask AI")
                                .font(.system(size: isTight ? 14 : 15, weight: .semibold))
                        }
                    }
                    .buttonStyle(AccentPillStyleCompact())
                    .fixedSize()
                    .overlay(alignment: .topTrailing) {
                        // Tiny PRO tag that hangs off the top-right
                        if access.isPro {
                            Text("Pro")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                                .offset(x: 6, y: -6)
                        }
                    }
                }

                Spacer(minLength: isTight ? 2 : 3)

                // RIGHT cluster: Crown • Alarm • Compose
                HStack(spacing: isTight ? 10 : 14) {
                    // Crown opens PaywallView directly
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.15)) { showProPaywall = true }
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 1, y: 1)
                    }
                    .buttonStyle(IconCircleStyleCompact(fg: fg, outlined: true))

                    Button { showTimePicker = true } label: {
                        Image(systemName: "alarm")
                            .font(.system(size: isTight ? 16 : 17, weight: .semibold))
                    }
                    .buttonStyle(IconCircleStyleCompact(fg: fg))

                    Button {
                        customQuoteText = ""; customAuthor = ""; customBook = ""
                        showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: isTight ? 16 : 17, weight: .semibold))
                    }
                    .buttonStyle(IconCircleStyleCompact(fg: fg, outlined: true))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isTight ? 8 : 12)
            .padding(.vertical, isTight ? 6 : 8)
            .background(Color.clear)
        }
        .frame(height: 44) // ensures stable layout
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // NEW — fills the screen but doesn't "push" UI out of view
                GeometryReader { proxy in
                    let size = proxy.size
                    Image(uiImage: theme.currentUIImageOrFallback(size: size))
                        .resizable()
                        .interpolation(.high)     // keep it sharp
                        .antialiased(true)
                        .aspectRatio(contentMode: .fill)  // use .fit if you want zero crop
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .position(x: size.width/2, y: size.height/2)

                    // put the overlay in the same geometry, not ignoring safe areas
                    readabilityOverlay
                        .frame(width: size.width, height: size.height)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()    // keep this on the container only

                VStack {
                    Spacer()

                    // Main content
                    VStack(spacing: 40) {
                        Text("📚 Quote of the Day")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(adaptiveTextColor)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        Text(quote.text)
                            .font(.title3).italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 60)  // ⬅️ a tad more room on customs
                            .frame(maxWidth: 700)
                            .foregroundStyle(adaptiveTextColor)


                        VStack(spacing: 20) {
                            Text("- \(quote.author)")
                                .font(.headline)
                                .foregroundStyle(adaptiveTextColor.opacity(0.85))

                            if let book = quote.book {
                                Text("📖 \(book)")
                                    .font(.subheadline)
                                    .foregroundStyle(adaptiveTextColor.opacity(0.75))
                            }
                        }
                        .padding(.top, 10)

                        Button {
                            shareItem = SharePayload(image: generateShareImage())
                        } label: {
                            Text("Share Quote")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }

                    Spacer()

                    Text("Current Notification Time: \(formattedTime(hour: selectedHour, minute: selectedMinute))")
                        .font(.subheadline)
                        .foregroundStyle(adaptiveTextColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, theme.isUsingCustomImage ? 28 : 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Time picker overlay
                if showTimePicker {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showTimePicker = false }

                    VStack {
                        DatePicker("", selection: bindingForTime(), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .background(.thinMaterial)
                            .cornerRadius(12)
                            .padding()
                            .colorScheme(.dark)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    topBar
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                }
            }

            // Sheets
            .sheet(isPresented: $showHistory) { QuoteHistoryView() }
            .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
                ActivityView(activityItems: [item.image])
            }
            .sheet(isPresented: $showThemePickerSheet) {
                ThemePickerView(selectedIndex: $theme.currentIndex)
            }
            .onDisappear {
                // keep index in bounds if the list size changed
                theme.currentIndex = ThemeCatalog.clampedIndex(from: theme.currentIndex)
                UserDefaults.standard.set(theme.currentIndex, forKey: "selectedThemeIndex")
            }
            
            .fullScreenCover(isPresented: $showAskAISheet) {
                AskAIQuoteSheet(
                    themeName: currentThemeName,
                    adaptiveTextColor: adaptiveTextColor,
                    prompt: $aiPrompt,
                    quote: $aiQuote,
                    isLoading: $aiLoading,
                    error: $aiError
                ) { text, author, book in
                    let img = ShareCardBuilder.image(
                        forText: text,
                        themeNames: themeNames,
                        selectedThemeIndex: theme.currentIndex,   // Int, not Item
                        author: author,
                        book: book,
                        headingOverride: "Quote of the Day"
                    )
                    shareItem = SharePayload(image: img)
                }
                .interactiveDismissDisabled(true)
            }
            
            .fullScreenCover(isPresented: $showComposeSheet) {
                ComposeQuoteOverlay(
                    adaptiveTextColor: adaptiveTextColor,   // 👈 NEW
                    themeName: currentThemeName,
                    onShare: { text, author, book in
                        let img = ShareCardBuilder.image(
                            forText: text,
                            themeNames: themeNames,
                            selectedThemeIndex: theme.currentIndex,   // Int, not Item
                            author: author,
                            book: book,
                            headingOverride: "Quote of the Day"
                        )
                        shareItem = SharePayload(image: img)
                        showComposeSheet = false
                    },
                    text: $composeText,
                    author: $composeAuthor,
                    book: $composeBook
                )
            }
            .fullScreenCover(isPresented: $showProPaywall) {
                PaywallView()
            }
            
            .onAppear {
                // Make sure migrations run before we load/select anything
                migrateIfNeeded()

                requestNotificationPermission()
                loadQuotes()

                scheduleRollingDailyQuotes(hour: selectedHour, minute: selectedMinute)
                scheduleAppRefresh()

                theme.currentIndex = ThemeCatalog.clampedIndex(from: theme.currentIndex)
                UserDefaults.standard.set(theme.currentIndex, forKey: "selectedThemeIndex")
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    // Returning from background on a new day must show the new quote
                    selectTodayQuote()
                    scheduleRollingDailyQuotes(hour: selectedHour, minute: selectedMinute)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                // Midnight passed while the app was open
                selectTodayQuote()
            }
            .onChange(of: showTimePicker) { isShowing in
                if isShowing {
                    selectionHaptic.prepare()
                } else {
                    scheduleRollingDailyQuotes(hour: selectedHour, minute: selectedMinute)
                    scheduleAppRefresh()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .onChange(of: theme.currentIndex) { newIndex in
                let clamped = ThemeCatalog.clampedIndex(from: newIndex)
                if clamped != theme.currentIndex {                    // keep it in range
                    theme.currentIndex = clamped
                }
                UserDefaults.standard.set(clamped, forKey: "selectedThemeIndex")
            }
        }
    }


    /// A UITextView-backed editor with a fully transparent background.
    struct ClearTextEditor: UIViewRepresentable {
        @Binding var text: String
        var font: UIFont = UIFont.preferredFont(forTextStyle: .title3)
        var textColor: UIColor = .label

        func makeUIView(context: Context) -> UITextView {
            let tv = UITextView()
            tv.backgroundColor = .clear
            tv.isScrollEnabled = true
            tv.font = font
            tv.textColor = textColor
            tv.delegate = context.coordinator
            tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return tv
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            if uiView.text != text { uiView.text = text }
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }
        final class Coordinator: NSObject, UITextViewDelegate {
            var parent: ClearTextEditor
            init(_ parent: ClearTextEditor) { self.parent = parent }
            func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        }
    }

    // Ask for notification permission then ensure our rolling window + BG refresh are set.
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        scheduleRollingDailyQuotes(hour: selectedHour, minute: selectedMinute)
                        scheduleAppRefresh()
                    } else { print("🔕 Notifications denied by user.") }
                }
            case .authorized, .provisional, .ephemeral:
                scheduleRollingDailyQuotes(hour: selectedHour, minute: selectedMinute)
                scheduleAppRefresh()
            case .denied:
                print("🔕 Notifications are denied in Settings.")
            @unknown default:
                break
            }
        }
    }

    // MARK: - Share image (uses current theme)
    func generateShareImage(
        for custom: BookQuote? = nil,
        heading: String? = nil,
        showAttributionIfAvailable: Bool = true
    ) -> UIImage {

        // 1080x1080 logical × 3x scale = 3240×3240 actual pixels
        let canvas = CGSize(width: 1080, height: 1080)

        let bgUIImage = theme.currentUIImageOrFallback(size: canvas)
        let q = custom ?? quote
        let titleText = heading ?? "📚 Quote from a Book"

        // App icon (skip safely if the asset is missing)
        let appIcon = UIImage(named: "AppIcon_DailyQuoteReminder")

        // ---- Adaptive colors (same idea as before)
        let sampleRect = CGRect(x: bgUIImage.size.width * 0.08,
                                y: bgUIImage.size.height * 0.25,
                                width: bgUIImage.size.width * 0.84,
                                height: bgUIImage.size.height * 0.50)
        let uiPrimary   = bgUIImage.adaptiveTextColor(sampleRect: sampleRect, threshold: 0.50)
        let uiSecondary = uiPrimary.withAlphaComponent(0.82)
        let primaryText   = Color(uiColor: uiPrimary)
        let secondaryText = Color(uiColor: uiSecondary)
        let softShadow    = Color.black.opacity(uiPrimary == .white ? 0.35 : 0.22)

        let overlay = LinearGradient(
            colors: [Color.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.45)],
            startPoint: .top, endPoint: .bottom
        )

        // Bottom-left mark metrics
        let sideInset: CGFloat   = canvas.width  * 0.08
        let bottomInset: CGFloat = canvas.height * 0.08
        let iconSize: CGFloat = 60

        let host = UIHostingController(
            rootView:
                ZStack {
                    // Solid base to guarantee opacity
                    Color.black

                    // Background
                    Image(uiImage: bgUIImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: canvas.width, height: canvas.height)
                        .clipped()

                    overlay

                    // Quote text
                    VStack(spacing: 80) {
                        Text(titleText)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(primaryText)
                            .shadow(color: softShadow, radius: 6, x: 0, y: 2)

                        Text("\"\(q.text)\"")
                            .font(.system(size: 44, weight: .regular, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(primaryText)
                            .shadow(color: softShadow, radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 44)
                            .frame(maxWidth: 700)

                        let authorIsEmpty = q.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let showAuthor = showAttributionIfAvailable && !authorIsEmpty
                        let showBook   = showAttributionIfAvailable && (q.book?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

                        if showAuthor || showBook {
                            VStack(spacing: 6) {
                                if showAuthor {
                                    Text("- \(q.author)")
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                        .foregroundStyle(secondaryText)
                                        .shadow(color: softShadow, radius: 4, x: 0, y: 1)
                                }
                                if showBook, let book = q.book {
                                    Text("📖 \(book)")
                                        .font(.system(size: 26, weight: .regular, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(secondaryText)
                                        .shadow(color: softShadow, radius: 4, x: 0, y: 1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: canvas.width, height: canvas.height)
                // ✅ Bottom-left app mark (icon with app name BELOW it)
                .overlay(alignment: .bottomLeading) {
                    if let appIcon {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(uiImage: appIcon)
                                .resizable()
                                .frame(width: iconSize, height: iconSize)
                                .cornerRadius(12)
                                .shadow(radius: 4)

                            Text("DailyQuoteReminder")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                                .shadow(color: softShadow, radius: 3, x: 0, y: 1)
                        }
                        .padding(.leading, sideInset)
                        .padding(.bottom, bottomInset)
                    }
                }
        )

        // === Render at 3x for crisp share output ===
        let view = host.view!
        view.frame = CGRect(origin: .zero, size: canvas)
        view.backgroundColor = .black

        // Mount briefly so layout resolves fully
        let win = UIWindow(frame: view.frame)
        win.backgroundColor = .black
        win.rootViewController = host
        win.isHidden = false
        win.layoutIfNeeded()

        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = true
        fmt.scale  = 3  // 1080 x 3 = 3240 actual pixels per side

        let finalImage = UIGraphicsImageRenderer(size: canvas, format: fmt).image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: canvas))
            view.layer.render(in: ctx.cgContext)
        }

        // Clean up
        win.isHidden = true
        return finalImage
    }

    // MARK: - Time picker binding
    func bindingForTime() -> Binding<Date> {
        Binding<Date>(
            get: {
                var comps = DateComponents()
                comps.hour = selectedHour
                comps.minute = selectedMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let newHour = comps.hour ?? 7
                let newMinute = comps.minute ?? 0
                if newHour != selectedHour || newMinute != selectedMinute {
                    selectionHaptic.selectionChanged()
                    selectionHaptic.prepare()
                }
                selectedHour = newHour
                selectedMinute = newMinute
                UserDefaults.standard.set(selectedHour, forKey: "selectedHour")
                UserDefaults.standard.set(selectedMinute, forKey: "selectedMinute")
            }
        )
    }

    // MARK: - Quote data (unchanged selection logic)
    func formattedTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let df = DateFormatter(); df.dateFormat = "h:mm a"
        return df.string(from: date)
    }

    func loadQuotes() {
        if let url = Bundle.main.url(forResource: "quotes", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                allQuotes = try decoder.decode([BookQuote].self, from: data)
                selectTodayQuote()
            } catch {
                print("❌ Failed to decode quotes.json: \(error)")
            }
        } else {
            print("❌ quotes.json not found in bundle.")
        }
    }

    // MARK: - Deterministic quote selection (see QuoteSchedule)

    /// Picks today's quote from quotes.json. History is derived from
    /// QuoteSchedule, so nothing needs to be recorded here.
    func selectTodayQuote() {
        guard !allQuotes.isEmpty else { return }
        quote = QuoteSchedule.quote(for: Date(), in: allQuotes)
    }
}

import SwiftUI
import StoreKit

struct AskAIQuoteSheet: View {
    // Theme + bindings
    let themeName: String
    let adaptiveTextColor: Color
    @Binding var prompt: String          // user input
    @Binding var quote: String           // AI result (quote-only)
    @Binding var isLoading: Bool
    @Binding var error: String?
    var onShare: (String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusPrompt: Bool
    @ObservedObject private var keyboard = KeyboardResponder()

    // Pro access / paywall
    @StateObject private var access = ProAccess.shared
    @State private var showProPaywall = false
    @State private var showPaywall = false
    private let gate = AskAIGate()

    // Optional meta from AI
    @State private var lastAuthor: String?
    @State private var lastBook: String?

    // Theme state
    @ObservedObject private var theme = ThemeState.shared

    // MARK: - Backdrop (preserves full custom images)
    private var backdrop: some View {
        ZStack {
            Group {
                if theme.isUsingCustomImage {
                    Image(uiImage: theme.currentUIImageOrFallback(size: UIScreen.main.bounds.size))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea()
                } else {
                    Image(uiImage: theme.currentUIImageOrFallback(size: UIScreen.main.bounds.size))
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
            }

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.45)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Color.black.opacity(0.12).ignoresSafeArea()
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerRow() -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Ask AI")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if access.isPro {
                Text("PRO Active")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("Free tries left: \(access.remainingAskAI)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white.opacity(0.9))
            }

            Button("Done") {
                resetFields()
                dismiss()
            }
            .font(.system(size: 17, weight: .semibold))
        }
        .padding(.bottom, 2)
    }

    // MARK: - Prompt editor
    @ViewBuilder
    private func promptEditor(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What kind of quote do you want?")
                .font(.subheadline)
                .foregroundColor(adaptiveTextColor)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .focused($focusPrompt)
                    .font(.body)
                    .foregroundColor(adaptiveTextColor)   // 👈 text colour
                    .tint(adaptiveTextColor)              // 👈 caret /selection
                    .frame(height: height)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(adaptiveTextColor.opacity(0.18), lineWidth: 1)
                    )

                if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("e.g. A quote about Happiness / A quote from the Book The Secret")
                        .font(.caption)
                        .foregroundColor(adaptiveTextColor.opacity(0.65))
                        .padding(.top, 16)
                        .padding(.leading, 18)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Generate button (gated)
    @ViewBuilder
    private func generateButton() -> some View {
        let isPromptEmpty = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let blocked = !access.canUseAskAI() // not PRO && Ask-AI credits == 0

        Button {
            hideKeyboard()
                let blocked = !ProAccess.shared.canUseAskAI()   // not PRO && no Ask-AI credits left
                if blocked {
                    showPaywall = true                          // present PaywallView
            } else {
                Task { await generate() }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isLoading ? "hourglass" : (blocked ? "crown.fill" : "sparkles"))
                    .imageScale(.medium)
                Text(isLoading ? "Generating…" : (blocked ? "Go PRO to Continue" : "Generate Quote"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [Color.blue, Color.cyan],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundColor(.white)
            .opacity((isLoading || isPromptEmpty) ? 0.6 : 1)
        }
        .disabled(isLoading || isPromptEmpty)
    }

    // MARK: - Helpers
    private func attributionLine(author: String?, book: String?) -> String? {
        let a = author?.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = book?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (a?.isEmpty == false, b?.isEmpty == false) {
        case (true, true):   return "— \(a!), \(b!)"
        case (true, false):  return "— \(a!)"
        case (false, true):  return "— \(b!)"
        default:             return nil
        }
    }

    @ViewBuilder
    private func errorLabel(_ err: String?) -> some View {
        if let err {
            Text(err)
                .foregroundColor(.red)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func resultCard(minH: CGFloat, maxH: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Response")
                .font(.subheadline)
                .foregroundColor(adaptiveTextColor)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(quote)
                            .font(.title3.italic())
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let line = attributionLine(author: lastAuthor, book: lastBook) {
                        Text(line)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.top, 2)
                    }
                }
                .frame(minHeight: minH, maxHeight: maxH, alignment: .topLeading)
                .padding(12)

                if quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                    Text("AI generated Quote will appear here..")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func shareButton() -> some View {
        Button {
            let text = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            onShare(text, lastAuthor, lastBook)
            resetFields()
            dismiss()
        } label: {
            Text("Share Quote")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(.white)
        }
        .disabled(quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop

                // Tap outside to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }

                let cardW = geo.size.width  * 0.80
                let cardH = geo.size.height * 0.80

                VStack(alignment: .leading, spacing: 16) {
                    headerRow()

                    if !access.isPro {
                        Text("You start with \(ProAccess.initialFreeTriesAskAI) free tries.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            promptEditor(height: cardH * 0.11)
                            generateButton()
                            errorLabel(error)
                            resultCard(minH: cardH * 0.28, maxH: cardH * 0.34)
                            shareButton()
                        }
                        .padding(.bottom, max(16, keyboard.currentHeight + 12))
                    }
                }
                .padding(20)
                .frame(width: cardW, height: cardH, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2.2)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .ignoresSafeArea(.keyboard)
        .task {
            focusPrompt = true
            // Make sure entitlement + counters are fresh when the sheet opens
            await access.updateEntitlementFromTransactions()
            ProAccess.shared.seedIfNeeded()
        }
        .onDisappear { resetFields() }
    }

    // MARK: - Generate (gated, consumes free tries)
    @MainActor
    private func generate() async {
        error = nil
        quote = ""

        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let recent = AskAIRecentStore.shared.recent
        let maxAttempts = 3
        var attempt = 0
        var picked: QuoteResult?

        while attempt < maxAttempts {
            attempt += 1
            do {
                let r = try await AIQuoteService.shared.generateQuote(prompt: p, recent: recent)
                let text = r.quote.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && !AskAIRecentStore.shared.contains(text) {
                    picked = r
                    break
                }
            } catch {
                self.error = "Couldn't get a quote. Please try again."
                return
            }
        }

        if let r = picked {
            // ✅ Update UI with the successful quote
            quote = r.quote
            lastAuthor = r.author
            lastBook = r.book

            // Save to recent store so we don't repeat it
            AskAIRecentStore.shared.add(r.quote)

            // Burn one Ask AI credit on success for non-PRO
            ProAccess.shared.consumeOneFreeUseAskAIIfNeeded()
            // If you kept the old single-pool API, use:
            // ProAccess.shared.consumeOneFreeUseIfNeeded()

        } else {
            self.error = "We couldn't find a new quote. Please try again."
        }
    }

    // MARK: - Local helpers
    private func resetFields() {
        prompt = ""
        quote  = ""
        error  = nil
        isLoading = false
        hideKeyboard()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// =================== Compose Overlay, Scheduling, History & App scaffolding ===================
// (Unchanged from your version, except history & share calls now pass ThemeCatalog.names)

struct ComposeQuoteOverlay: View {
    let adaptiveTextColor: Color
    @State private var aiPrompt: String = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var isLoading = false
    @State private var aiError: String?
    
    let themeName: String
    let onShare: (_ text: String, _ author: String?, _ book: String?) -> Void

    @Binding var text: String
    @Binding var author: String
    @Binding var book: String
    @ObservedObject private var theme = ThemeState.shared

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @ObservedObject private var keyboard = KeyboardResponder()
    
    var body: some View {
                GeometryReader { geo in
                    ZStack {
                        // Background
                        Image(uiImage: theme.currentUIImageOrFallback(size: UIScreen.main.bounds.size))
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                        
                        LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.45)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                        Color.black.opacity(0.12).ignoresSafeArea()

                        // Tap outside to dismiss keyboard
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { hideKeyboard() }

                        // Card size
                        let cardW = geo.size.width  * 0.80
                        let cardH = geo.size.height * 0.75

                        // Card
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack {
                                Text("Compose Quote")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.85)
                                Spacer()
                                Button("Done") { dismiss() }
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .padding(.bottom, 4)

                            // Editor
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $text)
                                    .focused($focused)
                                    .font(.title3)
                                    .foregroundColor(adaptiveTextColor)
                                    .frame(height: cardH * 0.30)
                                    .padding(10)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Write or Paste the Quote here to share…")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.65))
                                        .padding(.top, 16).padding(.leading, 18)
                                        .allowsHitTesting(false)
                                }
                            }

                            // Attribution
                            Text("ATTRIBUTION (OPTIONAL)")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(adaptiveTextColor)

                            VStack(spacing: 10) {
                                // Author
                                TextField(
                                    "",                                   // empty label
                                    text: $author,
                                    prompt: Text("Author")
                                        .foregroundColor(adaptiveTextColor.opacity(0.65))
                                )
                                .textContentType(.name)
                                .submitLabel(.done)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .foregroundColor(adaptiveTextColor)       // typed text color
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(adaptiveTextColor.opacity(0.18), lineWidth: 1)
                                )

                                // Book / Source
                                TextField(
                                    "",
                                    text: $book,
                                    prompt: Text("Book / Source")
                                        .foregroundColor(adaptiveTextColor.opacity(0.65))
                                )
                                .submitLabel(.done)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .foregroundColor(adaptiveTextColor)       // typed text color
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(adaptiveTextColor.opacity(0.18), lineWidth: 1)
                                )
                            }

                            // Share
                            HStack {
                                Spacer()
                                Button {
                                    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !t.isEmpty else { return }

                                    let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let b = book.trimmingCharacters(in: .whitespacesAndNewlines)

                                    onShare(t, a.isEmpty ? nil : a, b.isEmpty ? nil : b)

                                    // Reset for next time
                                    text = ""; author = ""; book = ""
                                    hideKeyboard()
                                } label: {
                                    Text("Share Quote")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            Color.blue,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                        .foregroundColor(.white)
                                }
                                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(20)
                        .frame(width: cardW, height: cardH, alignment: .top)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1))
                        )
                        // Keep the card horizontally centered and nudge up with keyboard
                        .position(x: geo.size.width/2, y: geo.size.height/2.5)
                        .padding(.bottom, keyboard.currentHeight) // ← moves up with keyboard
                        .animation(.easeOut(duration: 0.25), value: keyboard.currentHeight)
                        .animation(nil, value: focused)
                    }
                }
                .ignoresSafeArea(.keyboard)
            }

            // MARK: - Helpers
            private func hideKeyboard() {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            }
        }

// MARK: - NEW: Rolling daily notifications (64-day window)
// (unchanged from your version)
/// Put your sound file in the app bundle (Build Phases → Copy Bundle Resources).
/// Supported: .caf / .aif(f) / .wav, under ~30 seconds.
private let kCustomSoundFile = "quoteTone.caf"

private func ymdString(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

private func dayAt(hour: Int, minute: Int, from base: Date) -> Date {
    var c = Calendar.current.dateComponents([.year,.month,.day], from: base)
    c.hour = hour; c.minute = minute; c.second = 0
    return Calendar.current.date(from: c) ?? base
}

private func nextFireBaseDate(hour: Int, minute: Int, now: Date = Date()) -> Date {
    let today = dayAt(hour: hour, minute: minute, from: now)
    return today > now ? today : Calendar.current.date(byAdding: .day, value: 1, to: today)!
}

// MARK: - Permission (same behavior, just tidy logging)
func requestNotificationAuth() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error { print("🔔 Notification auth error:", error) }
        print("🔔 Notifications granted:", granted)
    }
}

// MARK: - Deterministic quote schedule (single source of truth)
//
// Every date maps to exactly one quote:
//   index = daysSince(anchorDate) % totalQuotes
//
// The anchor date is set once (first launch, or by QuotesResetManager).
// The home screen, the notification scheduler and the History screen all
// use this, so they always agree — and History can be rebuilt for any past
// day, even days the app was never opened (notification only).
enum QuoteSchedule {
    static let anchorDateKey = "quotes.anchorDate"

    // Same format/locale as QuotesResetManager so stored anchors parse identically.
    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Loads the stored anchor date, or creates one (today) if none exists.
    static func anchorDate() -> Date {
        let cal = Calendar.current
        if let stored = UserDefaults.standard.string(forKey: anchorDateKey),
           let d = ymd.date(from: stored) {
            return cal.startOfDay(for: d)
        }
        let today = cal.startOfDay(for: Date())
        UserDefaults.standard.set(ymd.string(from: today), forKey: anchorDateKey)
        return today
    }

    /// Whole days from the anchor to `date` (never negative).
    static func dayNumber(for date: Date) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: anchorDate(),
                                      to: cal.startOfDay(for: date)).day ?? 0
        return max(0, days)
    }

    static func index(for date: Date, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return dayNumber(for: date) % total
    }

    static func quote(for date: Date, in quotes: [BookQuote]) -> BookQuote {
        guard !quotes.isEmpty else { return BookQuote(text: "", author: "") }
        return quotes[index(for: date, total: quotes.count)]
    }

    /// Every quote delivered from the anchor date up to and including `date`,
    /// newest first. Capped at one full cycle so the list never repeats.
    static func history(through date: Date = Date(), in quotes: [BookQuote]) -> [(date: Date, quote: BookQuote)] {
        guard !quotes.isEmpty else { return [] }
        let cal = Calendar.current
        let anchor = anchorDate()
        let last = dayNumber(for: date)
        let first = max(0, last - quotes.count + 1)
        return (first...last).reversed().compactMap { day in
            guard let d = cal.date(byAdding: .day, value: day, to: anchor) else { return nil }
            return (date: d, quote: quotes[day % quotes.count])
        }
    }
}

/// Return the quote for a specific date using the deterministic anchor-based index.
private func quoteForDate(_ date: Date, allQuotes: [BookQuote]) -> BookQuote {
    QuoteSchedule.quote(for: date, in: allQuotes)
}

// MARK: - Sound helper
/// Returns a UNNotificationSound using the bundled custom file if present; falls back to .default.
private func quoteNotificationSound() -> UNNotificationSound {
    if let _ = Bundle.main.url(forResource: (kCustomSoundFile as NSString).deletingPathExtension,
                               withExtension: (kCustomSoundFile as NSString).pathExtension) {
        return UNNotificationSound(named: UNNotificationSoundName(kCustomSoundFile))
    } else {
        // File missing or not in Copy Bundle Resources → use default sound
        print("⚠️ Custom sound '\(kCustomSoundFile)' not found in bundle. Using .default.")
        return .default
    }
}

func scheduleNextDailyQuote(hour: Int, minute: Int) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["nextDailyQuote"])

    var comps = DateComponents()
    comps.hour = hour
    comps.minute = minute

    let now = Date()
    let cal = Calendar.current
    var fire = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now.addingTimeInterval(60)

    // If the computed time is in the past for today, push to tomorrow
    if fire <= now { fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire.addingTimeInterval(24*3600) }

    let content = UNMutableNotificationContent()
    content.title = "Daily Quote"
    content.body  = "Tap to see today's inspiration."
    content.sound = .default

    let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year,.month,.day,.hour,.minute], from: fire), repeats: false)
    let req = UNNotificationRequest(identifier: "nextDailyQuote", content: content, trigger: trigger)
    center.add(req)
}

// MARK: - Scheduler (sequential, uses custom tone)
func scheduleRollingDailyQuotes(hour: Int, minute: Int, days: Int = 64) {
    let center = UNUserNotificationCenter.current()

    center.getPendingNotificationRequests { reqs in
        // Clear previous dailyQuote_* to avoid duplicates
        let ids = reqs.map(\.identifier).filter { $0.hasPrefix("dailyQuote_") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        // Load quotes.json
        var allQuotes: [BookQuote] = []
        if let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([BookQuote].self, from: data) {
            allQuotes = decoded
        }

        let start = nextFireBaseDate(hour: hour, minute: minute)
        let sound = quoteNotificationSound()

        for offset in 0..<min(days, 64) {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: offset, to: start) else { continue }
            // Deterministic: same date always maps to same quote
            let q = quoteForDate(fireDate, allQuotes: allQuotes)

            let content = UNMutableNotificationContent()
            content.title = "Quote of the Day"
            content.body  = q.text.isEmpty ? "Your daily inspiration ✨" : "\"\(q.text)\" — \(q.author)"
            content.sound = sound

            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let id = "dailyQuote_\(ymdString(fireDate))"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req)
        }
    }
}

// MARK: - Background refresh

private let bgRefreshID = "com.istalin.DailyQuote.refresh"

func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: bgRefreshID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24*60*60)
    try? BGTaskScheduler.shared.submit(request)
}

func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: bgRefreshID, using: nil) { task in
        guard let refresh = task as? BGAppRefreshTask else { return }
        scheduleAppRefresh()

        let hour = (UserDefaults.standard.object(forKey: "selectedHour") as? Int) ?? 7
        let minute = (UserDefaults.standard.object(forKey: "selectedMinute") as? Int) ?? 0

        let op = BlockOperation { scheduleRollingDailyQuotes(hour: hour, minute: minute) }
        let q = OperationQueue()
        refresh.expirationHandler = { q.cancelAllOperations() }
        op.completionBlock = { refresh.setTaskCompleted(success: !op.isCancelled) }
        q.addOperation(op)
    }
}



struct QuoteHistoryView: View {
    private var selectedThemeIndex: Int {
        UserDefaults.standard.integer(forKey: "selectedThemeIndex")
    }

    private struct Row: Identifiable {
        let id: Date          // one row per day — stable identity for List
        let text: String
        let author: String?
        let book: String?
    }

    /// Every day's quote from the anchor date through today, newest first.
    /// Derived from QuoteSchedule (the same formula the notifications use),
    /// so days when only the notification was seen are included too.
    private static func buildRows() -> [Row] {
        QuoteSchedule.history(in: Bundle.main.loadQuotesSafely()).map { entry in
            Row(id: entry.date, text: entry.quote.text,
                author: entry.quote.author, book: entry.quote.book)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    @State private var rows: [Row] = []

    private struct ShareImagePayload: Identifiable { let id = UUID(); let image: UIImage }
    @State private var shareItem: ShareImagePayload?

    var body: some View {
        NavigationView {
            List {
                ForEach(rows) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Self.dayFormatter.string(from: item.id))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(item.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline) {
                            Text(item.author.map { "- \($0)" } ?? "")
                                .font(.subheadline).foregroundColor(.secondary).lineLimit(1)

                            Spacer(minLength: 12)

                            Text(item.book.map { "📖 \($0)" } ?? "")
                                .font(.subheadline).foregroundColor(.secondary)
                                .lineLimit(1).multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Spacer()
                            Button {
                                let img = ShareCardBuilder.image(
                                    forText: item.text,
                                    themeNames: ThemeCatalog.names,     // single source
                                    selectedThemeIndex: selectedThemeIndex,
                                    author: item.author,
                                    book: item.book,
                                    headingOverride: "📚 Quote from a Book"
                                )
                                shareItem = ShareImagePayload(image: img)
                            } label: {
                                Image(systemName: "square.and.arrow.up").imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Quote History")
        }
        .onAppear { rows = Self.buildRows() }
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { payload in
            ActivityView(activityItems: [payload.image])
        }
    }
}

// MARK: - Helpers you already use

private extension Bundle {
    func loadQuotesSafely() -> [BookQuote] {
        guard let url = url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([BookQuote].self, from: data) else {
            return []
        }
        return decoded
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@main
struct DailyQuoteApp: App {
    init() {
        registerBackgroundTasks()
        ThemeState.shared.seedDefaultThemeIfNeeded()
        QuotesResetManager.resetIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            DailyQuoteView()
                .onAppear { scheduleAppRefresh() }
        }
    }
}



