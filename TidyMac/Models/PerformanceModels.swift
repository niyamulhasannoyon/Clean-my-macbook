import Foundation
import SwiftUI
import AppKit

// MARK: - Memory Metrics
public struct MemoryMetrics {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    
    public var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }
    
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
    }
    
    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .memory)
    }
    
    public var formattedActive: String {
        ByteCountFormatter.string(fromByteCount: Int64(activeBytes), countStyle: .memory)
    }
    
    public var formattedWired: String {
        ByteCountFormatter.string(fromByteCount: Int64(wiredBytes), countStyle: .memory)
    }
    
    public var formattedCompressed: String {
        ByteCountFormatter.string(fromByteCount: Int64(compressedBytes), countStyle: .memory)
    }
}

// MARK: - CPU Metrics
public struct CPUMetrics {
    public var usageRatio: Double = 0.0
    public var coreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    public var userPercent: Double = 0.0
    public var systemPercent: Double = 0.0
    public var idlePercent: Double = 100.0
    
    public var formattedPercent: String {
        String(format: "%.1f%%", usageRatio * 100)
    }
    
    public var modelDescription: String {
        "Apple Silicon • \(coreCount) Cores"
    }
}

// MARK: - Disk Metrics
public struct DiskMetrics {
    public var totalBytes: Int64 = 0
    public var freeBytes: Int64 = 0
    public var usedBytes: Int64 = 0
    
    public var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
}

// MARK: - Running App Item
public struct ProcessItem: Identifiable, Hashable {
    public var id: pid_t { pid }
    public let pid: pid_t
    public let name: String
    public let bundleIdentifier: String
    public var memoryBytes: UInt64
    public var icon: NSImage
    public var isTerminating: Bool = false
    
    public var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
    
    public static func == (lhs: ProcessItem, rhs: ProcessItem) -> Bool {
        lhs.pid == rhs.pid
    }
}

// MARK: - Launch Agent / Startup Item
public enum LaunchItemLocation: String, CaseIterable, Identifiable {
    case all = "All Items"
    case userAgent = "User Launch Agents"
    case systemAgent = "System Launch Agents"
    case systemDaemon = "System Daemons"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .userAgent: return "person.crop.circle"
        case .systemAgent: return "gearshape.2.fill"
        case .systemDaemon: return "lock.shield.fill"
        }
    }
    
    public var requiresAdmin: Bool {
        switch self {
        case .all, .userAgent: return false
        case .systemAgent, .systemDaemon: return true
        }
    }
}

public struct LaunchItem: Identifiable {
    public let id: String
    public let label: String
    public let displayName: String
    public var path: String
    public let location: LaunchItemLocation
    public let program: String
    public var isEnabled: Bool
    public var isToggling: Bool = false
    
    public init(
        id: String,
        label: String,
        displayName: String,
        path: String,
        location: LaunchItemLocation,
        program: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.label = label
        self.displayName = displayName
        self.path = path
        self.location = location
        self.program = program
        self.isEnabled = isEnabled
    }
}
