import SwiftUI
import Foundation

public enum JunkCategoryType: String, CaseIterable, Identifiable, Hashable {
    case userCaches = "User App Caches"
    case systemLogs = "System & User Logs"
    case xcodeDeveloper = "Xcode & Developer Caches"
    case browserCaches = "Browser Caches"
    case mailAttachments = "Mail Attachments Cache"
    case trash = "Trash Bins"
    case iosBackups = "iOS Device Backups"
    case unusedLanguages = "Unused Language Files (.lproj)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .userCaches: return "folder.badge.gearshape"
        case .systemLogs: return "doc.text.magnifyingglass"
        case .xcodeDeveloper: return "hammer.fill"
        case .browserCaches: return "globe"
        case .mailAttachments: return "envelope.badge"
        case .trash: return "trash.fill"
        case .iosBackups: return "iphone.badge.play"
        case .unusedLanguages: return "character.book.closed.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .userCaches: return .blue
        case .systemLogs: return .indigo
        case .xcodeDeveloper: return .purple
        case .browserCaches: return .cyan
        case .mailAttachments: return .teal
        case .trash: return .orange
        case .iosBackups: return .mint
        case .unusedLanguages: return .pink
        }
    }
    
    public var subtitle: String {
        switch self {
        case .userCaches:
            return "Application cache files, cached media, and temporary session data."
        case .systemLogs:
            return "Diagnostic logs, error reports, and macOS daemon traces."
        case .xcodeDeveloper:
            return "Xcode DerivedData, build artifacts, simulator caches, and old iOS device support."
        case .browserCaches:
            return "Web cache, offline scripts, and media from Safari, Chrome, Firefox, Edge, Brave."
        case .mailAttachments:
            return "Locally cached copies of opened email attachments and mail cache."
        case .trash:
            return "Items in your macOS Trash bin ready for permanent removal."
        case .iosBackups:
            return "Legacy local backup archives of iPhone and iPad devices."
        case .unusedLanguages:
            return "Localization files (.lproj) in apps for languages you don't use."
        }
    }
    
    public var defaultSelected: Bool {
        switch self {
        case .userCaches, .systemLogs, .xcodeDeveloper, .browserCaches, .trash:
            return true
        case .mailAttachments, .iosBackups, .unusedLanguages:
            return false // Safe default for user-sensitive data
        }
    }
    
    public var isOptionalScan: Bool {
        return self == .unusedLanguages
    }
}

public struct JunkItem: Identifiable, Hashable {
    public let id: UUID
    public let category: JunkCategoryType
    public let name: String
    public let path: URL
    public var size: Int64
    public var fileCount: Int
    public var isSelected: Bool
    public let details: String
    public let icon: String
    
    public init(
        id: UUID = UUID(),
        category: JunkCategoryType,
        name: String,
        path: URL,
        size: Int64,
        fileCount: Int = 1,
        isSelected: Bool = true,
        details: String = "",
        icon: String = "doc.fill"
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.path = path
        self.size = size
        self.fileCount = fileCount
        self.isSelected = isSelected
        self.details = details
        self.icon = icon
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct JunkCategory: Identifiable {
    public let id: JunkCategoryType
    public var title: String { id.rawValue }
    public var description: String { id.subtitle }
    public var icon: String { id.icon }
    public var iconColor: Color { id.tintColor }
    public var items: [JunkItem]
    public var isExpanded: Bool
    public var isScanning: Bool
    
    public init(
        id: JunkCategoryType,
        items: [JunkItem] = [],
        isExpanded: Bool = false,
        isScanning: Bool = false
    ) {
        self.id = id
        self.items = items
        self.isExpanded = isExpanded
        self.isScanning = isScanning
    }
    
    public var isSelected: Bool {
        get {
            guard !items.isEmpty else { return false }
            return items.allSatisfy { $0.isSelected }
        }
        set {
            for idx in items.indices {
                items[idx].isSelected = newValue
            }
        }
    }
    
    public var isPartiallySelected: Bool {
        let selectedCount = items.filter { $0.isSelected }.count
        return selectedCount > 0 && selectedCount < items.count
    }
    
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    public var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    public var totalFileCount: Int {
        items.reduce(0) { $0 + $1.fileCount }
    }
    
    public var selectedFileCount: Int {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.fileCount }
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
}

public struct CleanResult: Equatable {
    public let reclaimedBytes: Int64
    public let reclaimedFilesCount: Int
    public let errorsCount: Int
    public let duration: TimeInterval
    public let cleanedCategorySizes: [JunkCategoryType: Int64]
    
    public init(
        reclaimedBytes: Int64,
        reclaimedFilesCount: Int,
        errorsCount: Int,
        duration: TimeInterval,
        cleanedCategorySizes: [JunkCategoryType: Int64] = [:]
    ) {
        self.reclaimedBytes = reclaimedBytes
        self.reclaimedFilesCount = reclaimedFilesCount
        self.errorsCount = errorsCount
        self.duration = duration
        self.cleanedCategorySizes = cleanedCategorySizes
    }
    
    public var formattedReclaimedSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
    }
}
