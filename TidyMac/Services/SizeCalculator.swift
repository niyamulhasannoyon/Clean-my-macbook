import Foundation

/// Fast and accurate size calculation result model.
public struct SizeResult: Equatable {
    public let bytes: Int64
    public let filesCount: Int
    
    public var formatted: String {
        SizeCalculator.formatBytes(bytes)
    }
    
    public init(bytes: Int64 = 0, filesCount: Int = 0) {
        self.bytes = bytes
        self.filesCount = filesCount
    }
}

/// Robust engine for measuring file and directory sizes on macOS APFS / HFS+.
public enum SizeCalculator {
    
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useAll]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
    
    /// Formats raw byte count into human-readable string (e.g. "14.2 MB", "1.2 GB").
    public static func formatBytes(_ bytes: Int64) -> String {
        return byteFormatter.string(fromByteCount: bytes)
    }
    
    /// Computes accurate disk usage for a single file or directory.
    ///
    /// - Parameters:
    ///   - url: URL to inspect.
    ///   - fm: FileManager instance to use.
    ///   - followSymlinks: If false, symlinks are measured by their link metadata rather than traversed, preventing loops.
    /// - Returns: `SizeResult` with total bytes and file count.
    public static func calculateSize(
        of url: URL,
        fm: FileManager = .default,
        followSymlinks: Bool = false
    ) -> SizeResult {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return SizeResult(bytes: 0, filesCount: 0)
        }
        
        let resourceKeys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]
        
        // Handle single non-directory file
        if !isDir.boolValue {
            if let vals = try? url.resourceValues(forKeys: resourceKeys) {
                let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                return SizeResult(bytes: max(0, sz), filesCount: 1)
            }
            return SizeResult(bytes: 0, filesCount: 1)
        }
        
        // Handle directory traversal
        var totalBytes: Int64 = 0
        var totalFiles: Int = 0
        
        // Do not skip package descendants so .app, .framework, .bundle, and .xcarchive contents are measured accurately;
        // FileManager.enumerator already avoids traversing directory symlinks by default.
        let options: FileManager.DirectoryEnumerationOptions = []
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options,
            errorHandler: { _, _ in true }
        ) else {
            return SizeResult(bytes: 0, filesCount: 0)
        }
        
        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }
            
            // Skip traversing symlinks if not following
            if !followSymlinks && (vals.isSymbolicLink == true) {
                totalFiles += 1
                let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                totalBytes += max(0, sz)
                continue
            }
            
            if vals.isRegularFile == true {
                totalFiles += 1
                let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                totalBytes += max(0, sz)
            }
        }
        
        return SizeResult(bytes: totalBytes, filesCount: totalFiles)
    }
}
