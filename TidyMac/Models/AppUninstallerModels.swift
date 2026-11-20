import SwiftUI
import Foundation
import AppKit

// MARK: - Leftover Category
public enum LeftoverCategory: String, CaseIterable, Identifiable, Hashable {
    case appBinary = "Application Bundle"
    case appSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case containers = "Containers & Sandboxes"
    case logs = "Logs & Diagnostics"
    case launchAgents = "Launch Agents"
    case savedState = "Saved Application State"
    case other = "Other Residuals"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .appBinary: return "app.fill"
        case .appSupport: return "folder.badge.gearshape"
        case .caches: return "bolt.horizontal.fill"
        case .preferences: return "slider.horizontal.3"
        case .containers: return "shippingbox.fill"
        case .logs: return "doc.text.magnifyingglass"
        case .launchAgents: return "gearshape.arrow.triangle.2.circlepath"
        case .savedState: return "clock.arrow.circlepath"
        case .other: return "archivebox.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .appBinary: return .blue
        case .appSupport: return .purple
        case .caches: return .orange
        case .preferences: return .pink
        case .containers: return .teal
        case .logs: return .indigo
        case .launchAgents: return .red
        case .savedState: return .cyan
        case .other: return .gray
        }
    }
    
    public var explanation: String {
        switch self {
        case .appBinary: return "The core application executable and resource bundle."
        case .appSupport: return "Persistent user databases, extensions, templates, and runtime state."
        case .caches: return "Temporary cached network data, rendered graphics, and intermediate files."
        case .preferences: return "User settings, license keys, and window configurations (.plist)."
        case .containers: return "App sandbox container filesystem and shared group storage."
        case .logs: return "Diagnostic logs, crash traces, and session telemetry."
        case .launchAgents: return "Background daemon plists scheduled to run at user login."
        case .savedState: return "Snapshots of open windows and document states between launches."
        case .other: return "Associated cookies, HTTP storages, or helper process leftovers."
        }
    }
}

// MARK: - App Leftover Item
public struct AppLeftoverItem: Identifiable, Hashable {
    public let id: UUID
    public let category: LeftoverCategory
    public let name: String
    public let displayPath: String
    public let url: URL
    public var size: Int64
    public var fileCount: Int
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        category: LeftoverCategory,
        name: String,
        displayPath: String,
        url: URL,
        size: Int64,
        fileCount: Int = 1,
        isSelected: Bool = true
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.displayPath = displayPath
        self.url = url
        self.size = size
        self.fileCount = fileCount
        self.isSelected = isSelected
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Installed App Model
public struct InstalledApp: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let bundleURL: URL
    public var appSize: Int64
    public var isSystemApp: Bool
    public var leftovers: [AppLeftoverItem]
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        version: String,
        bundleURL: URL,
        appSize: Int64,
        isSystemApp: Bool = false,
        leftovers: [AppLeftoverItem] = [],
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.bundleURL = bundleURL
        self.appSize = appSize
        self.isSystemApp = isSystemApp
        self.leftovers = leftovers
        self.isSelected = isSelected
    }
    
    public var leftoversSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }
    
    public var selectedLeftoversSize: Int64 {
        leftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    public var totalSize: Int64 {
        appSize + leftoversSize
    }
    
    public var totalSelectedSize: Int64 {
        appSize + selectedLeftoversSize
    }
    
    public var leftoversCount: Int {
        leftovers.count
    }
    
    public var formattedAppSize: String {
        ByteCountFormatter.string(fromByteCount: appSize, countStyle: .file)
    }
    
    public var formattedLeftoversSize: String {
        ByteCountFormatter.string(fromByteCount: leftoversSize, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    public var isUserApp: Bool {
        bundleURL.path.contains("/Users/")
    }
}

// MARK: - Orphaned App Group Model
public struct OrphanedAppGroup: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String?
    public var items: [AppLeftoverItem]
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        items: [AppLeftoverItem] = [],
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.items = items
        self.isSelected = isSelected
    }
    
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    public var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
    
    public var fileCount: Int {
        items.reduce(0) { $0 + max(1, $1.fileCount) }
    }
}

// MARK: - Navigation Tab and Sort Options
public enum AppUninstallerTab: String, CaseIterable, Identifiable {
    case installedApps = "Installed Applications"
    case orphanedLeftovers = "Orphaned Leftovers"
    
    public var id: String { rawValue }
}

public enum AppSortOption: String, CaseIterable, Identifiable {
    case sizeDescending = "Size (Largest First)"
    case sizeAscending = "Size (Smallest First)"
    case nameAscending = "Name (A-Z)"
    case leftoversDescending = "Leftovers (Most Space)"
    
    public var id: String { rawValue }
}
