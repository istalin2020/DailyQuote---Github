import UIKit
import CoreImage

extension UIImage {
    // MARK: - Whole-image luminance (kept for backward compatibility)
    /// Perceived average luminance in 0…1 over the entire image (nil if it can't compute)
    var averageLuminance: CGFloat? {
        return averageLuminance(in: CGRect(origin: .zero, size: size))
    }

    // MARK: - Region luminance
    /// Perceived average luminance (0…1) for a specific rect on the image.
    /// If rect is out of bounds it will be clamped to the image area.
    func averageLuminance(in rect: CGRect) -> CGFloat? {
        guard let cg = self.cgImage else { return nil }

        // Clamp to image bounds (points → pixels)
        let scale = self.scale
        let clamped = CGRect(
            x: max(0, rect.origin.x) * scale,
            y: max(0, rect.origin.y) * scale,
            width: min(rect.size.width, size.width - rect.origin.x) * scale,
            height: min(rect.size.height, size.height - rect.origin.y) * scale
        )
        guard clamped.width > 0, clamped.height > 0 else { return nil }

        guard let cropped = cg.cropping(to: clamped) else { return nil }
        let ci = CIImage(cgImage: cropped)
        let extent = ci.extent

        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }

        // Render 1×1 pixel in a linear-ish space to avoid gamma surprises
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var rgba = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &rgba,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        let r = CGFloat(rgba[0]) / 255.0
        let g = CGFloat(rgba[1]) / 255.0
        let b = CGFloat(rgba[2]) / 255.0

        // WCAG relative luminance (perceived brightness)
        func srgbToLin(_ c: CGFloat) -> CGFloat {
            return (c <= 0.03928) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        let L = 0.2126 * srgbToLin(r) + 0.7152 * srgbToLin(g) + 0.0722 * srgbToLin(b)
        return max(0, min(1, L))
    }

    // MARK: - Adaptive text color
    /// Chooses .white on dark backgrounds and .black on light backgrounds.
    /// - Parameters:
    ///   - sampleRect: Area where your text will be drawn. If nil, uses whole image.
    ///   - threshold: 0…1 split; lower values make white text more likely. 0.50 is a good default.
    func adaptiveTextColor(sampleRect: CGRect? = nil, threshold: CGFloat = 0.50) -> UIColor {
        let area = sampleRect ?? CGRect(origin: .zero, size: size)
        let L = averageLuminance(in: area) ?? 0.5
        return (L < threshold) ? .white : .black
    }

    // MARK: - (Optional) Contrast helper if you ever want to fine-tune
    /// Returns contrast ratio (1…21) between a text color and a sampled region.
    func contrastRatio(for textColor: UIColor, sampleRect: CGRect? = nil) -> CGFloat {
        let area = sampleRect ?? CGRect(origin: .zero, size: size)
        let Lbg = averageLuminance(in: area) ?? 0.5
        // Relative luminance for the text color
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        textColor.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

        func srgbToLin(_ c: CGFloat) -> CGFloat {
            return (c <= 0.03928) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        let Ltext = 0.2126 * srgbToLin(tr) + 0.7152 * srgbToLin(tg) + 0.0722 * srgbToLin(tb)

        let L1 = max(Lbg, Ltext)
        let L2 = min(Lbg, Ltext)
        return (L1 + 0.05) / (L2 + 0.05)
    }
}
