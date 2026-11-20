import Foundation
import SwiftUI

// MARK: - Smart Scan Modules
public enum SmartScanModule: String, CaseIterable, Identifiable {
    case systemJunk = "System Junk"
    case largeFiles = "Large & Old Files"
    case privacy = "Privacy"
    case performance = "Performance"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .systemJunk: return "trash.fill"
        case .largeFiles: return "folder.badge.clock"
        case .privacy: return "hand.raised.fill"
        case .performance: return "bolt.circle.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .systemJunk: return .blue
        case .largeFiles: return .teal
        case .privacy: return .purple
        case .performance: return .cyan
        }
    }
}

// MARK: - Smart Scan State
public enum SmartScanState: Equatable {
    case idle
    case scanning(step: String, progress: Double, currentModule: SmartScanModule)
    case completed
    case cleaning(step: String, progress: Double)
    case celebration
}

// MARK: - Smart Scan Summary
public struct SmartScanSummary {
    public var junkBytes: Int64 = 0
    public var junkFilesCount: Int = 0
    public var isJunkSelected: Bool = true
    
    public var largeFilesBytes: Int64 = 0
    public var largeFilesCount: Int = 0
    public var isLargeFilesSelected: Bool = true
    
    public var privacyBytes: Int64 = 0
    public var privacyFilesCount: Int = 0
    public var isPrivacySelected: Bool = true
    
    public var purgeableRAMBytes: Int64 = 0
    public var performanceTasksCount: Int = 3
    public var isPerformanceSelected: Bool = true
    
    public init() {}
    
    // Total Cleanable Storage (Junk + Large Files + Privacy)
    public var totalCleanableBytes: Int64 {
        var total: Int64 = 0
        if isJunkSelected { total += junkBytes }
        if isLargeFilesSelected { total += largeFilesBytes }
        if isPrivacySelected { total += privacyBytes }
        return total
    }
    
    public var formattedTotalCleanable: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }
    
    public var formattedJunkSize: String {
        ByteCountFormatter.string(fromByteCount: junkBytes, countStyle: .file)
    }
    
    public var formattedLargeFilesSize: String {
        ByteCountFormatter.string(fromByteCount: largeFilesBytes, countStyle: .file)
    }
    
    public var formattedPrivacySize: String {
        ByteCountFormatter.string(fromByteCount: privacyBytes, countStyle: .file)
    }
    
    public var formattedPurgeableRAM: String {
        ByteCountFormatter.string(fromByteCount: purgeableRAMBytes, countStyle: .file)
    }
}
