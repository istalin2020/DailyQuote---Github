import SwiftUI
import UIKit

struct ShareCardBuilder {
    
    static func image(
        forText text: String,
        themeNames: [String],
        selectedThemeIndex: Int,
        author: String? = nil,
        book: String? = nil,
        headingOverride: String? = nil
    ) -> UIImage {
        
        let canvas = CGSize(width: 800, height: 800)
        
        // Background from current home theme
        let bg: UIImage = ThemeState.shared.currentUIImageOrFallback(size: canvas)
        
        // Adaptive colors
        let sampleRect = CGRect(x: bg.size.width * 0.08,
                                y: bg.size.height * 0.25,
                                width: bg.size.width * 0.84,
                                height: bg.size.height * 0.50)
        
        let uiPrimary: UIColor   = bg.adaptiveTextColor(sampleRect: sampleRect, threshold: 0.50)
        let uiSecondary: UIColor = uiPrimary.withAlphaComponent(0.82)
        
        let primaryText   = Color(uiColor: uiPrimary)
        let secondaryText = Color(uiColor: uiSecondary)
        let softShadow    = Color.black.opacity(uiPrimary == .white ? 0.35 : 0.22)
        
        // Overlay
        let overlay = LinearGradient(
            colors: [Color.black.opacity(0.35), Color.black.opacity(0.15), Color.black.opacity(0.45)],
            startPoint: .top, endPoint: .bottom
        )
        
        // Heading + app mark data
        let heading = headingOverride ?? "Quote from a Book"
        let appIcon  = UIImage(named: "AppIcon_DailyQuoteReminder")
        let sideInset: CGFloat   = canvas.width  * 0.08
        let bottomInset: CGFloat = canvas.height * 0.08
        let iconSize: CGFloat    = 60
        
        // Compose
        let controller = UIHostingController(
            rootView:
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: canvas.width, height: canvas.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    overlay.ignoresSafeArea()
                    
                    VStack(spacing: 44) {
                        Text(heading)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(primaryText)
                            .shadow(color: softShadow, radius: 6, x: 0, y: 2)
                        
                        Text("\"\(text)\"")
                            .font(.system(size: 42, weight: .regular, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(primaryText)
                            .shadow(color: softShadow, radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 44)
                            .frame(maxWidth: 700)
                        
                        if (author?.isEmpty == false) || (book?.isEmpty == false) {
                            VStack(spacing: 6) {
                                if let a = author, !a.isEmpty {
                                    Text("- \(a)")
                                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                                        .foregroundStyle(secondaryText)
                                        .shadow(color: softShadow, radius: 4, x: 0, y: 1)
                                }
                                if let b = book, !b.isEmpty {
                                    Text("📖 \(b)")
                                        .font(.system(size: 24, weight: .regular, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(secondaryText)
                                        .shadow(color: softShadow, radius: 4, x: 0, y: 1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                    // ⬇️ Bottom-left app icon + name (same as generateShareImage)
                    if let icon = appIcon {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(uiImage: icon)
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
                .frame(width: canvas.width, height: canvas.height)
        )
        
        // Keep your original simple render path
        let view = controller.view!
        view.bounds = CGRect(origin: .zero, size: canvas)
        view.backgroundColor = .black
        
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
