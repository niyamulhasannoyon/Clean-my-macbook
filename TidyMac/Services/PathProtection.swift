import Foundation

/// Defines reasons why a path is protected from modification or deletion.
public enum PathProtectionError: LocalizedError, Equatable {
    case rootDirectory(String)
    case criticalSystemDirectory(String)
    case userHomeDirectory(String)
    case essentialUserDirectory(String)
    case securityOrCredentialData(String)
    case systemApplication(String)
    case invalidPath(String)
    
    public var errorDescription: String? {
        switch self {
        case .rootDirectory(let path):
            return "Path is the system root volume and cannot be modified: \(path)"
        case .criticalSystemDirectory(let path):
            return "Path is a critical macOS system directory protected by System Integrity Protection (SIP): \(path)"
        case .userHomeDirectory(let path):
            return "Cannot delete the user home directory itself: \(path)"
        case .essentialUserDirectory(let path):
            return "Essential user root folder is protected from deletion: \(path)"
        case .securityOrCredentialData(let path):
            return "Security credentials, SSH keys, or keychains cannot be deleted: \(path)"
        case .systemApplication(let path):
            return "Default Apple system application is protected: \(path)"
        case .invalidPath(let path):
            return "Path is empty or invalid: \(path)"
        }
    }
}

/// Centralized security validation engine preventing accidental deletion of essential macOS files and directories.
public enum PathProtection {
    
    /// Exact critical root system paths that must never be deleted.
    public static let criticalSystemPaths: Set<String> = [
        "/",
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/usr/bin",
        "/usr/sbin",
        "/usr/lib",
        "/etc",
        "/private",
        "/private/etc",
        "/private/var",
        "/dev",
        "/Volumes",
        "/Library",
        "/Applications"
    ]
    
    /// Essential system path prefixes that are protected from deletion.
    public static let criticalSystemPrefixes: [String] = [
        "/System/",
        "/bin/",
        "/sbin/",
        "/usr/bin/",
        "/usr/sbin/",
        "/usr/lib/",
        "/private/etc/",
        "/private/var/db/",
        "/private/var/root/",
        "/dev/"
    ]
    
    /// Subpaths under /Applications that are core macOS system apps.
    public static let protectedSystemAppNames: Set<String> = [
        "Safari.app",
        "Finder.app",
        "System Settings.app",
        "System Preferences.app",
        "App Store.app",
        "Utilities",
        "Terminal.app",
        "Activity Monitor.app",
        "Console.app",
        "Disk Utility.app"
    ]
    
    /// Standard essential subdirectories in a user's home directory that should not have their root deleted.
    public static let essentialUserDirNames: Set<String> = [
        "Desktop",
        "Documents",
        "Downloads",
        "Library",
        "Pictures",
        "Movies",
        "Music",
        "Public",
        "Applications"
    ]
    
    /// Sensitive user credential and identity files/directories.
    public static let sensitiveUserPaths: Set<String> = [
        ".ssh",
        ".gnupg",
        ".aws",
        ".bash_profile",
        ".zshrc",
        ".bashrc",
        ".profile",
        ".zprofile",
        "Library/Keychains"
    ]
    
    /// Normalizes and standardizes a URL path, resolving any symlinks and relative path components.
    public static func standardizedPath(of url: URL) -> String {
        let standardURL = url.standardizedFileURL.resolvingSymlinksInPath()
        return standardURL.path
    }
    
    /// Validates whether a file/directory at the given URL is safe to clean or trash.
    /// Returns `nil` if safe, or a `PathProtectionError` describing why the path is protected.
    public static func evaluatePath(url: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> PathProtectionError? {
        let path = standardizedPath(of: url)
        
        // 1. Empty or Root
        if path.isEmpty {
            return .invalidPath(path)
        }
        if path == "/" {
            return .rootDirectory(path)
        }
        
        // 2. Critical System Paths (Exact match)
        if criticalSystemPaths.contains(path) {
            return .criticalSystemDirectory(path)
        }
        
        // 3. Critical System Prefixes
        for prefix in criticalSystemPrefixes {
            if path.hasPrefix(prefix) {
                return .criticalSystemDirectory(path)
            }
        }
        
        // 4. Apple System Applications
        if path.hasPrefix("/System/Applications") {
            return .systemApplication(path)
        }
        for appName in protectedSystemAppNames {
            if path == "/Applications/\(appName)" || path.hasPrefix("/Applications/\(appName)/") {
                return .systemApplication(path)
            }
        }
        
        // 5. User Home Directory checks
        let homePath = standardizedPath(of: homeDirectory)
        if path == homePath {
            return .userHomeDirectory(path)
        }
        
        // 6. Essential User Directories (the top-level folder itself, e.g. ~/Desktop)
        for dirName in essentialUserDirNames {
            let essentialDir = (homePath as NSString).appendingPathComponent(dirName)
            if path == essentialDir {
                return .essentialUserDirectory(path)
            }
        }
        
        // 7. Sensitive Credential & Config Paths
        for sensitive in sensitiveUserPaths {
            let fullSensitive = (homePath as NSString).appendingPathComponent(sensitive)
            if path == fullSensitive || path.hasPrefix(fullSensitive + "/") {
                return .securityOrCredentialData(path)
            }
        }
        
        // 8. Keychains anywhere in Library
        if path.contains("/Library/Keychains") || path.hasSuffix(".keychain") || path.hasSuffix(".keychain-db") {
            return .securityOrCredentialData(path)
        }
        
        // Passed all protection rules
        return nil
    }
    
    /// Returns true if the path is protected and must NOT be deleted.
    public static func isProtected(url: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        return evaluatePath(url: url, homeDirectory: homeDirectory) != nil
    }
    
    /// Throws a `PathProtectionError` if the path is protected.
    public static func assertSafeToDelete(url: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        if let error = evaluatePath(url: url, homeDirectory: homeDirectory) {
            throw error
        }
    }
    
    /// Filters a batch of URLs, returning safe URLs and a list of blocked URLs with reasons.
    public static func partitionSafeAndBlocked(
        urls: [URL],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> (safe: [URL], blocked: [(url: URL, reason: String)]) {
        var safe: [URL] = []
        var blocked: [(url: URL, reason: String)] = []
        
        for url in urls {
            if let error = evaluatePath(url: url, homeDirectory: homeDirectory) {
                blocked.append((url, error.localizedDescription))
            } else {
                safe.append(url)
            }
        }
        
        return (safe, blocked)
    }
}
