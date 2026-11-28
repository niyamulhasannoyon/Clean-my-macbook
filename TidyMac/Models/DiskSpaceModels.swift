import SwiftUI
import Foundation

// MARK: - Chart Style
public enum DiskChartStyle: String, CaseIterable, Identifiable {
    case treemap = "Treemap"
    case sunburst = "Sunburst"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .treemap: return "square.grid.2x2.fill"
        case .sunburst: return "circle.dashed.inset.filled"
        }
    }
}

// MARK: - Disk Node Model
public final class DiskNode: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var size: Int64
    public var fileCount: Int
    public var children: [DiskNode]
    public var color: Color
    public var level: Int
    public let isVirtual: Bool
    public var hasScannedChildren: Bool
    public weak var parent: DiskNode?
    
    public var canDrillDown: Bool {
        isDirectory && (!children.isEmpty || !hasScannedChildren)
    }
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64 = 0,
        fileCount: Int = 0,
        children: [DiskNode] = [],
        color: Color = .blue,
        level: Int = 0,
        isVirtual: Bool = false,
        hasScannedChildren: Bool = true,
        parent: DiskNode? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.fileCount = fileCount
        self.children = children
        self.color = color
        self.level = level
        self.isVirtual = isVirtual
        self.hasScannedChildren = hasScannedChildren
        self.parent = parent
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public var extensionName: String {
        url.pathExtension.lowercased()
    }
    
    public var iconName: String {
        if isDirectory {
            let lower = name.lowercased()
            if lower == "applications" { return "app.badge.fill" }
            if lower == "downloads" { return "arrow.down.circle.fill" }
            if lower == "documents" { return "doc.fill" }
            if lower == "desktop" { return "menubar.dock.rectangle" }
            if lower == "pictures" || lower == "photos" { return "photo.fill" }
            if lower == "music" { return "music.note" }
            if lower == "movies" || lower == "videos" { return "film.fill" }
            if lower == "library" { return "building.columns.fill" }
            if lower == "developer" || lower == "code" { return "hammer.fill" }
            return "folder.fill"
        }
        
        let ext = extensionName
        switch ext {
        case "dmg", "pkg", "iso": return "shippingbox.fill"
        case "zip", "tar", "gz", "rar", "7z": return "archivebox.fill"
        case "mp4", "mov", "mkv", "avi": return "play.rectangle.fill"
        case "mp3", "m4a", "wav", "flac": return "music.quarternote.3"
        case "png", "jpg", "jpeg", "webp", "gif", "heic": return "photo"
        case "pdf": return "doc.richtext.fill"
        case "app": return "app.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Treemap Calculated Item
public struct TreemapItem: Identifiable {
    public let id: UUID
    public let node: DiskNode
    public let rect: CGRect
    public let color: Color
    
    public init(id: UUID = UUID(), node: DiskNode, rect: CGRect, color: Color) {
        self.id = id
        self.node = node
        self.rect = rect
        self.color = color
    }
}

// MARK: - Sunburst Calculated Segment
public struct SunburstSegment: Identifiable {
    public let id: UUID
    public let node: DiskNode
    public let startAngle: Double // in radians
    public let endAngle: Double   // in radians
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let ringIndex: Int     // 0 = immediate children, 1 = grandchildren
    public let color: Color
    
    public init(
        id: UUID = UUID(),
        node: DiskNode,
        startAngle: Double,
        endAngle: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        ringIndex: Int,
        color: Color
    ) {
        self.id = id
        self.node = node
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.ringIndex = ringIndex
        self.color = color
    }
}

// MARK: - Palette Generator
public enum DiskColorPalette {
    public static let colors: [Color] = [
        Color(red: 0.22, green: 0.58, blue: 0.98), // Dodger Blue
        Color(red: 0.35, green: 0.78, blue: 0.45), // Emerald
        Color(red: 0.98, green: 0.65, blue: 0.18), // Amber Orange
        Color(red: 0.88, green: 0.34, blue: 0.38), // Coral Crimson
        Color(red: 0.68, green: 0.42, blue: 0.92), // Purple Violet
        Color(red: 0.16, green: 0.78, blue: 0.76), // Bright Teal
        Color(red: 0.95, green: 0.45, blue: 0.70), // Pink
        Color(red: 0.45, green: 0.62, blue: 0.85), // Slate Blue
        Color(red: 0.85, green: 0.75, blue: 0.20), // Gold
        Color(red: 0.30, green: 0.70, blue: 0.60), // Mint Green
        Color(red: 0.75, green: 0.50, blue: 0.35), // Ochre Bronze
        Color(red: 0.50, green: 0.55, blue: 0.90)  // Periwinkle
    ]
    
    public static func color(for index: Int) -> Color {
        colors[abs(index) % colors.count]
    }
}
