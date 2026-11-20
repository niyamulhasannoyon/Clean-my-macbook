import Cocoa
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    
    // Scale factor relative to 1024
    let s = size / 1024.0
    
    // Canvas: inset slightly for standard macOS app icon shadow
    let inset: CGFloat = 80.0 * s
    let squircleRect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let cornerRadius: CGFloat = squircleRect.width * 0.224
    
    // 1. Drop Shadow under the squircle
    ctx.saveGState()
    let shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
    ctx.setShadow(offset: CGSize(width: 0, height: -12.0 * s), blur: 24.0 * s, color: shadowColor)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor(red: 0.08, green: 0.12, blue: 0.24, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. Base Gradient Fill
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        NSColor(red: 0.06, green: 0.10, blue: 0.25, alpha: 1.0).cgColor, // Deep Midnight
        NSColor(red: 0.09, green: 0.22, blue: 0.48, alpha: 1.0).cgColor, // Royal Slate
        NSColor(red: 0.08, green: 0.42, blue: 0.74, alpha: 1.0).cgColor, // Ocean Blue
        NSColor(red: 0.05, green: 0.65, blue: 0.85, alpha: 1.0).cgColor  // Cyan
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 0.4, 0.75, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
            options: []
        )
    }
    
    // 3. Subtle Ambient Light Radial Flare at top left
    let flareColors = [
        NSColor.white.withAlphaComponent(0.25).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let flareGradient = CGGradient(colorsSpace: colorSpace, colors: flareColors, locations: [0.0, 1.0]) {
        let flareCenter = CGPoint(x: squircleRect.minX + squircleRect.width * 0.35, y: squircleRect.maxY - squircleRect.height * 0.25)
        ctx.drawRadialGradient(
            flareGradient,
            startCenter: flareCenter,
            startRadius: 0,
            endCenter: flareCenter,
            endRadius: squircleRect.width * 0.7,
            options: []
        )
    }
    
    // 4. Inner Border Highlight
    ctx.addPath(squirclePath)
    ctx.setLineWidth(3.0 * s)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.strokePath()
    
    ctx.restoreGState() // End squircle clipping
    
    // 5. Central Graphic: SF Symbol "sparkles" with subtle badge
    ctx.saveGState()
    
    // Circular frosted glow behind symbol
    let glowCenter = CGPoint(x: squircleRect.midX, y: squircleRect.midY)
    let glowRadius: CGFloat = 220.0 * s
    let glowColors = [
        NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.35).cgColor,
        NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: glowCenter,
            startRadius: 0,
            endCenter: glowCenter,
            endRadius: glowRadius,
            options: []
        )
    }
    
    // Draw SF Symbol: "sparkles"
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 420.0 * s, weight: .bold)
    if let symbolImage = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TidyMac")?.withSymbolConfiguration(symbolConfig) {
        
        // Shadow for the symbol
        ctx.setShadow(
            offset: CGSize(width: 0, height: -10.0 * s),
            blur: 18.0 * s,
            color: NSColor(red: 0.0, green: 0.1, blue: 0.3, alpha: 0.55).cgColor
        )
        
        let symWidth = symbolImage.size.width
        let symHeight = symbolImage.size.height
        let symX = squircleRect.midX - symWidth / 2.0
        let symY = squircleRect.midY - symHeight / 2.0 - (10.0 * s)
        let symRect = CGRect(x: symX, y: symY, width: symWidth, height: symHeight)
        
        // Render symbol tinted in crisp white with slight top-down luminescence
        symbolImage.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    // 6. Secondary accent SF Symbol badge: "internaldrive.fill" small icon at bottom right inside squircle
    let badgeConfig = NSImage.SymbolConfiguration(pointSize: 130.0 * s, weight: .semibold)
    if let badgeImage = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: "Storage")?.withSymbolConfiguration(badgeConfig) {
        let bW = badgeImage.size.width
        let bH = badgeImage.size.height
        let bX = squircleRect.maxX - bW - (45.0 * s)
        let bY = squircleRect.minY + (45.0 * s)
        let bRect = CGRect(x: bX, y: bY, width: bW, height: bH)
        
        // Small pill badge behind drive
        let pillRect = bRect.insetBy(dx: -14.0 * s, dy: -14.0 * s)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
        ctx.addPath(CGPath(roundedRect: pillRect, cornerWidth: pillRect.height / 2.0, cornerHeight: pillRect.height / 2.0, transform: nil))
        ctx.fillPath()
        
        badgeImage.draw(in: bRect, from: .zero, operation: .sourceOver, fraction: 0.85)
    }
    
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(url.lastPathComponent)")
        return
    }
    do {
        try pngData.write(to: url)
        print("  Generated: \(url.lastPathComponent) (\(Int(image.size.width))x\(Int(image.size.height)))")
    } catch {
        print("Failed to save \(url.path): \(error)")
    }
}

// Sizes needed for macOS .iconset
let iconSizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetDir = currentDir.appendingPathComponent("AppIcon.iconset")

try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

print("\n🎨 Generating TidyMac SF Symbols Original App Icon Set...")

for item in iconSizes {
    let img = createIcon(size: item.size)
    let dest = iconsetDir.appendingPathComponent(item.name)
    savePNG(image: img, to: dest)
}

print("Running iconutil to generate AppIcon.icns...")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", currentDir.appendingPathComponent("AppIcon.icns").path]
do {
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus == 0 {
        print("✅ AppIcon.icns successfully created!")
    } else {
        print("❌ iconutil failed with code \(proc.terminationStatus)")
    }
} catch {
    print("Error executing iconutil: \(error)")
}
