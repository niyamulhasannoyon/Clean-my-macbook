import SwiftUI
import AppKit

/// Loads and caches TidyMac's bundled app icon (`AppIcon.icns` / `BrandIcon.png`)
/// safely across `.app` bundles, Xcode builds, and SwiftPM (`swift run`) binaries.
@MainActor
public enum TidyMacIconProvider {
    private static func swiftPMResourceBundle() -> Bundle? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("TidyMac_TidyMac.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("TidyMac_TidyMac.bundle")
        ]
        for candidate in candidates {
            if let url = candidate, let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }

    public static let sharedAppIcon: NSImage = {
        if let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: icnsURL) {
            return image
        }
        if let named = NSImage(named: NSImage.Name("AppIcon")) {
            return named
        }
        if let spmBundle = swiftPMResourceBundle(),
           let icnsURL = spmBundle.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: icnsURL) {
            return image
        }
        if let fallback = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TidyMac") {
            return fallback
        }
        return NSImage()
    }()

    public static let sharedBrandIcon: NSImage = {
        if let pngURL = Bundle.main.url(forResource: "BrandIcon", withExtension: "png"),
           let image = NSImage(contentsOf: pngURL) {
            return image
        }
        if let named = NSImage(named: NSImage.Name("BrandIcon")) {
            return named
        }
        if let spmBundle = swiftPMResourceBundle(),
           let pngURL = spmBundle.url(forResource: "BrandIcon", withExtension: "png"),
           let image = NSImage(contentsOf: pngURL) {
            return image
        }
        return sharedAppIcon
    }()

    public static func configureApplicationIcon() {
        NSApplication.shared.applicationIconImage = sharedAppIcon
    }

    /// Generates an 18x18 monochrome template glyph matching TidyMac's ring + star logo
    /// so macOS automatically adapts it for Light Mode and Dark Mode menu bars.
    public static func menuBarTemplateImage() -> NSImage {
        let ptSize: CGFloat = 18.0
        let image = NSImage(size: NSSize(width: ptSize, height: ptSize), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            let center = CGPoint(x: 8.7, y: 8.7)
            let outerR: CGFloat = 6.5
            let innerR: CGFloat = 4.2

            // Swept circular crescent open around upper-right for the 4-point star
            let startDeg: CGFloat = 72.0
            let endDeg: CGFloat = 374.0
            let ringPath = CGMutablePath()
            ringPath.addArc(
                center: center,
                radius: outerR,
                startAngle: startDeg * .pi / 180.0,
                endAngle: endDeg * .pi / 180.0,
                clockwise: false
            )
            ringPath.addArc(
                center: CGPoint(x: 8.95, y: 8.95),
                radius: innerR,
                startAngle: endDeg * .pi / 180.0,
                endAngle: startDeg * .pi / 180.0,
                clockwise: true
            )
            ringPath.closeSubpath()

            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(ringPath)
            ctx.fillPath()

            // Crisp 4-point star breaking the upper-right rim
            let starCenter = CGPoint(x: 13.0, y: 13.0)
            let starOuter: CGFloat = 3.6
            let starInner: CGFloat = 1.05
            let starPath = CGMutablePath()
            let points: [CGPoint] = [
                CGPoint(x: starCenter.x, y: starCenter.y + starOuter),
                CGPoint(x: starCenter.x + starInner, y: starCenter.y + starInner),
                CGPoint(x: starCenter.x + starOuter, y: starCenter.y),
                CGPoint(x: starCenter.x + starInner, y: starCenter.y - starInner),
                CGPoint(x: starCenter.x, y: starCenter.y - starOuter),
                CGPoint(x: starCenter.x - starInner, y: starCenter.y - starInner),
                CGPoint(x: starCenter.x - starOuter, y: starCenter.y),
                CGPoint(x: starCenter.x - starInner, y: starCenter.y + starInner)
            ]
            starPath.move(to: points[0])
            for point in points.dropFirst() {
                starPath.addLine(to: point)
            }
            starPath.closeSubpath()
            ctx.addPath(starPath)
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Reusable SwiftUI view displaying TidyMac's official rounded squircle app icon.
public struct TidyMacAppIconView: View {
    public let size: CGFloat
    public var shadowRadius: CGFloat

    public init(size: CGFloat, shadowRadius: CGFloat = 0) {
        self.size = size
        self.shadowRadius = shadowRadius
    }

    public var body: some View {
        Image(nsImage: TidyMacIconProvider.sharedBrandIcon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: shadowRadius > 0 ? Color.black.opacity(0.22) : .clear, radius: shadowRadius, x: 0, y: shadowRadius * 0.45)
    }
}
