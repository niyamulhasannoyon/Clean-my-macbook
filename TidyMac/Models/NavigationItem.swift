import SwiftUI

public enum NavigationCategory: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cleaning = "Cleanup"
    case applications = "Applications"
    case security = "Security & Privacy"
    case system = "Optimization"
    
    public var id: String { rawValue }
    
    public var items: [NavigationItem] {
        switch self {
        case .overview:
            return [.smartScan]
        case .cleaning:
            return [.systemJunk, .largeOldFiles, .duplicates]
        case .applications:
            return [.appUninstaller]
        case .security:
            return [.privacy, .malwareScan]
        case .system:
            return [.maintenance, .performance, .diskSpace]
        }
    }
}

public enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
    case smartScan = "Smart Scan"
    case systemJunk = "System Junk"
    case largeOldFiles = "Large & Old Files"
    case duplicates = "Duplicates"
    case appUninstaller = "App Uninstaller"
    case privacy = "Privacy"
    case malwareScan = "Malware Scan"
    case maintenance = "Maintenance"
    case performance = "Performance"
    case diskSpace = "Disk Space"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .smartScan: return "sparkles"
        case .systemJunk: return "trash.fill"
        case .largeOldFiles: return "folder.badge.clock"
        case .duplicates: return "square.on.square"
        case .appUninstaller: return "app.badge.xmark"
        case .privacy: return "hand.raised.fill"
        case .malwareScan: return "shield.checkered"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .performance: return "speedometer"
        case .diskSpace: return "chart.pie.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .smartScan: return .cyan
        case .systemJunk: return .blue
        case .largeOldFiles: return .teal
        case .duplicates: return .indigo
        case .appUninstaller: return .orange
        case .privacy: return .purple
        case .malwareScan: return .green
        case .maintenance: return .pink
        case .performance: return .mint
        case .diskSpace: return .yellow
        }
    }
    
    public var subtitle: String {
        switch self {
        case .smartScan: return "All-in-one smart system analysis and cleanup"
        case .systemJunk: return "Clean caches, system logs, and temporary files"
        case .largeOldFiles: return "Locate massive files you haven't opened in months"
        case .duplicates: return "Find and remove identical files wasting space"
        case .appUninstaller: return "Completely uninstall apps and leftover service files"
        case .privacy: return "Erase browsing history and manage application permissions"
        case .malwareScan: return "Scan for viruses, adware, and vulnerabilities"
        case .maintenance: return "Run repair scripts, flush DNS cache, and free RAM"
        case .performance: return "Monitor real-time CPU, RAM, and hardware health"
        case .diskSpace: return "Explore interactive storage maps and directory sizes"
        }
    }
}
