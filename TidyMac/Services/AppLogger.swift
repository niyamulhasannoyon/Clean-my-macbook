import Foundation
import os

/// Unified structured logging for TidyMac using Apple's `os.Logger`.
public enum AppLogger {
    private static let subsystem = "com.tidymac.app"
    
    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let security = Logger(subsystem: subsystem, category: "security")
    public static let scanner = Logger(subsystem: subsystem, category: "scanner")
    public static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
    public static let performance = Logger(subsystem: subsystem, category: "performance")
    public static let maintenance = Logger(subsystem: subsystem, category: "maintenance")
    public static let malware = Logger(subsystem: subsystem, category: "malware")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
