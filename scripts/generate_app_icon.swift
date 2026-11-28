import Cocoa
import CoreGraphics

func loadSourceBrandIcon(from sourceURL: URL) -> NSImage? {
    guard let image = NSImage(contentsOf: sourceURL) else {
        return nil
    }
    return image
}

func createMacOSIconBitmap(size: Int, sourceImage: NSImage) -> NSBitmapImageRep? {
    let pixelSize = CGFloat(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    // Pin 1 point = 1 pixel so Retina displays do not double output dimensions.
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer {
        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
    }

    let ctx = graphicsContext.cgContext
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Clear transparent canvas
    ctx.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

    // Standard macOS Dock / App Icon proportions (844x844 inside 1024x1024)
    let s = pixelSize / 1024.0
    let inset: CGFloat = 90.0 * s
    let iconRect = CGRect(
        x: inset,
        y: inset,
        width: pixelSize - 2.0 * inset,
        height: pixelSize - 2.0 * inset
    )

    // Soft macOS icon drop shadow cast from the transparent-corner squircle alpha
    ctx.saveGState()
    let shadowBlur = max(0.5, 22.0 * s)
    let shadowOffsetY = min(-0.5, -10.0 * s)
    ctx.setShadow(
        offset: CGSize(width: 0, height: shadowOffsetY),
        blur: shadowBlur,
        color: NSColor.black.withAlphaComponent(0.32).cgColor
    )
    sourceImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.restoreGState()

    return rep
}

func savePNG(rep: NSBitmapImageRep, to url: URL) -> Bool {
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(url.lastPathComponent)")
        return false
    }
    do {
        try pngData.write(to: url)
        print("  Generated: \(url.lastPathComponent) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
        return true
    } catch {
        print("Failed to save \(url.path): \(error)")
        return false
    }
}

let iconSizes: [(name: String, size: Int)] = [
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
let scriptProjectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let projectRoot = fileManager.fileExists(atPath: currentDir.appendingPathComponent("Package.swift").path)
    ? currentDir
    : scriptProjectRoot

let resourcesDir = projectRoot.appendingPathComponent("TidyMac/Resources")
let sourceBrandURL = resourcesDir.appendingPathComponent("BrandIcon.png")
let iconsetDir = projectRoot.appendingPathComponent("AppIcon.iconset")
let outputIcnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")
let assetIconsetDir = resourcesDir.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")

guard let sourceBrandImage = loadSourceBrandIcon(from: sourceBrandURL) else {
    print("❌ Error: Missing or unreadable master icon at \(sourceBrandURL.path)")
    exit(1)
}

try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
defer {
    try? fileManager.removeItem(at: iconsetDir)
}

print("\n🎨 Generating TidyMac AppIcon Set from BrandIcon.png...")

for item in iconSizes {
    guard let rep = createMacOSIconBitmap(size: item.size, sourceImage: sourceBrandImage) else {
        print("Failed to render bitmap for \(item.name)")
        exit(1)
    }
    let dest = iconsetDir.appendingPathComponent(item.name)
    guard savePNG(rep: rep, to: dest) else {
        exit(1)
    }
    if fileManager.fileExists(atPath: assetIconsetDir.path) {
        let assetDest = assetIconsetDir.appendingPathComponent(item.name)
        guard savePNG(rep: rep, to: assetDest) else {
            exit(1)
        }
    }
}

print("Running iconutil to generate \(outputIcnsURL.path)...")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", outputIcnsURL.path]
do {
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus == 0 {
        print("✅ \(outputIcnsURL.path) successfully created!")
    } else {
        print("❌ iconutil failed with code \(proc.terminationStatus)")
        exit(proc.terminationStatus)
    }
} catch {
    print("Error executing iconutil: \(error)")
    exit(1)
}
