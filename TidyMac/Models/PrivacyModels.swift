import Foundation
import SwiftUI
import AppKit

// MARK: - Browser Type
public enum BrowserType: String, CaseIterable, Identifiable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case firefox = "Mozilla Firefox"
    case recentItems = "macOS Recent Items"
    
    public var id: String { rawValue }
    
    public var bundleIdentifier: String? {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .firefox: return "org.mozilla.firefox"
        case .recentItems: return nil
        }
    }
    
    public var icon: String {
        switch self {
        case .safari: return "safari.fill"
        case .chrome: return "globe"
        case .firefox: return "flame.fill"
        case .recentItems: return "clock.arrow.circlepath"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .safari: return .blue
        case .chrome: return .purple
        case .firefox: return .orange
        case .recentItems: return .teal
        }
    }
    
    public var processName: String {
        switch self {
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox"
        case .recentItems: return "Finder"
        }
    }
}

// MARK: - Privacy Category
public enum PrivacyCategory: String, CaseIterable, Identifiable {
    case history = "Browsing History"
    case cookies = "Cookies & Local Storage"
    case downloads = "Download History"
    case recentCache = "Caches & Web Data"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .cookies: return "shield.lefthalf.filled"
        case .downloads: return "arrow.down.circle.fill"
        case .recentCache: return "cylinder.split.1x2.fill"
        }
    }
}

// MARK: - Privacy Item
public struct PrivacyItem: Identifiable {
    public let id: String
    public let browser: BrowserType
    public let category: PrivacyCategory
    public let title: String
    public let description: String
    public let relativePaths: [String]
    public var isEnabled: Bool
    public var fileCount: Int
    public var sizeBytes: Int64
    public var isAvailable: Bool
    
    public var formattedSize: String {
        if sizeBytes == 0 {
            return "\(fileCount) items"
        }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public init(
        id: String,
        browser: BrowserType,
        category: PrivacyCategory,
        title: String,
        description: String,
        relativePaths: [String],
        isEnabled: Bool = true,
        fileCount: Int = 0,
        sizeBytes: Int64 = 0,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.browser = browser
        self.category = category
        self.title = title
        self.description = description
        self.relativePaths = relativePaths
        self.isEnabled = isEnabled
        self.fileCount = fileCount
        self.sizeBytes = sizeBytes
        self.isAvailable = isAvailable
    }
}
