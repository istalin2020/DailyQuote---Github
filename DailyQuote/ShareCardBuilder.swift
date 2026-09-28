import SwiftUI
import UIKit

/// Renders the shareable quote card used everywhere (Home, History,
/// Ask AI, Compose) so every share looks the same.
struct ShareCardBuilder {

    /// 4:5 portrait — the size Instagram/WhatsApp/iMessage show largest in a
    /// feed, and it crops far less of the portrait wallpapers than a square.
    static let canvas = CGSize(width: 1080, height: 1350)
    /// 2x -> 2160x2700 px. The wallpapers are 1024x1536, so higher scales only
    /// make the file bigger without adding detail.
    static let renderScale: CGFloat = 2

    static func image(
        forText text: String,
        themeNames: [String] = [],
        selectedThemeIndex: Int = 0,
        author: String? = nil,
        book: String? = nil,
        headingOverride: String? = nil
    ) -> UIImage {
        let canvas = Self.canvas
        let bg = ThemeState.shared.currentUIImageOrFallback(size: canvas)

        // Brighter wallpapers get a stronger shade so white text always reads.
        let lum = bg.averageLuminance ?? 0.5
        let shade = min(0.30, max(0, (lum - 0.30) * 0.75))

        let card = ShareCardView(
            background: bg,
            heading: headingOverride ?? "📚 Quote from a Book",
            text: text,
            author: author?.trimmingCharacters(in: .whitespacesAndNewlines),
            book: book?.trimmingCharacters(in: .whitespacesAndNewlines),
            appIcon: UIImage(named: "AppIcon_DailyQuoteReminder"),
            extraShade: shade
        )
        .frame(width: canvas.width, height: canvas.height)
        .ignoresSafeArea()

        let host = UIHostingController(rootView: card)
        // Without this the offscreen window's status-bar inset pushed the
        // whole card down and left a black strip at the top.
        host.safeAreaRegions = []
        host.view.backgroundColor = .black
        host.view.frame = CGRect(origin: .zero, size: canvas)

        // Mount briefly so layout resolves fully
        let win = UIWindow(frame: host.view.frame)
        win.backgroundColor = .black
        win.rootViewController = host
        win.isHidden = false
        defer { win.isHidden = true }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = true
        fmt.scale = Self.renderScale
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: canvas))
            host.view.layer.render(in: ctx.cgContext)
        }
    }
}

// MARK: - Card layout

private struct ShareCardView: View {
    let background: UIImage
    let heading: String
    let text: String
    let author: String?
    let book: String?
    let appIcon: UIImage?
    let extraShade: CGFloat

    private var canvas: CGSize { ShareCardBuilder.canvas }

    /// The quote without any quote marks it already had (Compose / Ask AI),
    /// so they aren't doubled when the card adds its own.
    private var bareText: String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}").union(.whitespacesAndNewlines))
    }

    /// Larger type for short quotes, smaller for long ones.
    private var quoteSize: CGFloat {
        switch text.count {
        case ..<70:  return 60
        case ..<130: return 54
        case ..<210: return 48
        case ..<300: return 42
        default:     return 38
        }
    }

    var body: some View {
        ZStack {
            // Wallpaper, edge to edge
            Image(uiImage: background)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: canvas.width, height: canvas.height)
                .clipped()

            // Soft shade: darker top/bottom, lighter middle
            LinearGradient(
                colors: [.black.opacity(0.40 + extraShade),
                         .black.opacity(0.22 + extraShade),
                         .black.opacity(0.30 + extraShade),
                         .black.opacity(0.62 + extraShade)],
                startPoint: .top, endPoint: .bottom
            )

            // Vignette pulls the eye to the quote
            RadialGradient(
                colors: [.clear, .black.opacity(0.35)],
                center: .center,
                startRadius: canvas.width * 0.35,
                endRadius: canvas.height * 0.75
            )

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Heading, quote and attribution stay together, centred
                VStack(spacing: 0) {
                    Text(heading)
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .modifier(TextGlow())
                        .padding(.bottom, 56)

                    // Quote wrapped in opening and closing quote marks
                    Text("\u{201C}\(bareText)\u{201D}")
                        .font(.system(size: quoteSize, weight: .medium, design: .serif))
                        .lineSpacing(quoteSize * 0.22)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: canvas.width * 0.80)
                        .modifier(TextGlow())

                    if hasAttribution {
                        Capsule()
                            .fill(.white.opacity(0.75))
                            .frame(width: 120, height: 3)
                            .padding(.top, 44)
                            .padding(.bottom, 28)

                        VStack(spacing: 12) {
                            if let a = author, !a.isEmpty {
                                Text("\u{2014} \(a)")
                                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .modifier(TextGlow())
                            }
                            if let b = book, !b.isEmpty {
                                Text("📖 \(b)")
                                    .font(.system(size: 30, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: canvas.width * 0.8)
                                    .modifier(TextGlow())
                            }
                        }
                    }
                }

                Spacer(minLength: 40)

                // App branding
                HStack(spacing: 22) {
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous)
                                .stroke(.white.opacity(0.35), lineWidth: 2))
                            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DailyQuoteReminder")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("A new quote every day")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .modifier(TextGlow())
                    Spacer()
                }
                .padding(.horizontal, 70)
                .padding(.bottom, 70)
            }
            .frame(width: canvas.width, height: canvas.height)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }

    private var hasAttribution: Bool {
        (author?.isEmpty == false) || (book?.isEmpty == false)
    }
}

/// Two-layer shadow: a tight one for crisp edges and a wide soft one so text
/// stays readable on busy or bright parts of any wallpaper.
private struct TextGlow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 2)
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
    }
}
