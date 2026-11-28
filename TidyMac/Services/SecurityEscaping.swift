import Foundation

/// Security and sanitization utilities for safe shell argument escaping,
/// path validation for privileged operations, and executable lookup without subshells.
public enum SecurityEscaping {
    
    /// Validates whether a file path is a permitted macOS launch item location.
    /// Strictly restricts paths to /Library/LaunchDaemons, /Library/LaunchAgents, or ~/Library/LaunchAgents.
    public static func isValidLaunchItemPath(_ path: String, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        // Reject empty, relative, dot-dot traversal components, or control-character inputs before URL resolution
        guard !path.isEmpty,
              path.hasPrefix("/"),
              !path.contains("\0"),
              !path.contains("\n"),
              !path.contains("\r"),
              !path.split(separator: "/").contains("..") else {
            return false
        }
        
        let cleanPath = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
            .lowercased()
        
        let userAgentsPath = homeDirectory
            .appendingPathComponent("Library/LaunchAgents")
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let userAgentsPrefix = userAgentsPath.hasSuffix("/") ? userAgentsPath : userAgentsPath + "/"
        
        let allowedPrefixes = [
            "/Library/LaunchDaemons/",
            "/Library/LaunchAgents/",
            userAgentsPrefix
        ].map { $0.lowercased() }
        
        guard allowedPrefixes.contains(where: { cleanPath.hasPrefix($0) }) else {
            return false
        }
        
        guard cleanPath.hasSuffix(".plist") || cleanPath.hasSuffix(".plist.disabled") else {
            return false
        }
        
        // Block path traversal and control characters
        guard !cleanPath.contains("/../") && !cleanPath.contains("\0") && !cleanPath.contains("\n") && !cleanPath.contains("\r") else {
            return false
        }
        
        return true
    }
    
    /// Quotes an arbitrary string safely for POSIX shell execution using single quotes.
    /// In POSIX shells, enclosing in '...' suppresses all variable expansion, backticks,
    /// subshells, and escapes. Internal single quotes are escaped as '\''.
    public static func posixShellQuote(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    /// Escapes double quotes and backslashes for AppleScript string literals:
    /// 'do shell script "..." with administrator privileges'
    public static func appleScriptStringEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    /// Safely resolves an executable on disk by searching known directories and PATH without spawning a subshell.
    public static func findExecutable(
        named name: String,
        fileManager: FileManager = .default,
        environmentPath: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> String? {
        // Prevent directory traversal or paths containing slashes/null bytes
        guard !name.contains("/") && !name.contains("\0") && !name.isEmpty else {
            return nil
        }
        
        let standardPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/homebrew/sbin/\(name)",
            "/usr/local/sbin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
            "/usr/sbin/\(name)",
            "/sbin/\(name)"
        ]
        
        for path in standardPaths {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        if let pathEnv = environmentPath {
            let dirs = pathEnv.components(separatedBy: ":")
            for dir in dirs where !dir.isEmpty {
                let candidate = (dir as NSString).appendingPathComponent(name)
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        
        return nil
    }
}
