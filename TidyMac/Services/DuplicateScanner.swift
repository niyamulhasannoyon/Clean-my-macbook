import Foundation
import SwiftUI
import AppKit
import CryptoKit

// MARK: - Scan Stage Enum
public enum DuplicateScanStage: String {
    case idle = "Ready to scan for duplicates"
    case groupingBySize = "Stage 1/3: Grouping files by exact byte size..."
    case partialHashing = "Stage 2/3: Computing fast partial hashes..."
    case fullHashing = "Stage 3/3: Verifying full SHA-256 checksums..."
    case completed = "Scan complete!"
}

@MainActor
public class DuplicateScanner: ObservableObject {
    public static let shared = DuplicateScanner()
    
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var currentStage: DuplicateScanStage = .idle
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = "Click Scan to find identical files"
    @Published public var selectedKeepStrategy: DuplicateKeepStrategy = .keepOldest
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var showCelebration: Bool = false
    @Published public var searchKeyword: String = ""
    @Published public var filterCategory: String = "All"
    
    // Safety verification flag: deletion can ONLY occur if confirmed
    @Published public var isDeleteConfirmedByUser: Bool = false
    
    public init() {}
    
    // MARK: - Computed Properties
    public var totalDuplicateFilesCount: Int {
        duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }
    
    public var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }
    
    public var formattedTotalWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: totalWastedSpace, countStyle: .file)
    }
    
    public var selectedFilesForRemoval: [DuplicateFileItem] {
        duplicateGroups.flatMap { $0.files.filter { $0.isSelectedForRemoval } }
    }
    
    public var totalSelectedRemovalCount: Int {
        selectedFilesForRemoval.count
    }
    
    public var totalSelectedRemovalSize: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.selectedWastedSpace }
    }
    
    public var formattedSelectedRemovalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedRemovalSize, countStyle: .file)
    }
    
    public var filteredGroups: [DuplicateGroup] {
        var groups = duplicateGroups
        
        if filterCategory != "All" {
            groups = groups.filter { $0.category == filterCategory }
        }
        
        let query = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            groups = groups.filter { group in
                group.fileName.lowercased().contains(query) ||
                group.files.contains { $0.path.lowercased().contains(query) }
            }
        }
        
        return groups
    }
    
    // MARK: - Auto-Select "Keep One"
    public func applyKeepOneAutoSelect(strategy: DuplicateKeepStrategy? = nil) {
        let strat = strategy ?? selectedKeepStrategy
        selectedKeepStrategy = strat
        
        for gIdx in duplicateGroups.indices {
            applyKeepOneToGroup(at: gIdx, strategy: strat)
        }
    }
    
    public func applyKeepOneToGroup(at index: Int, strategy: DuplicateKeepStrategy) {
        guard index < duplicateGroups.count else { return }
        var groupFiles = duplicateGroups[index].files
        guard !groupFiles.isEmpty else { return }
        
        // Sort according to keep strategy to determine which file to KEEP
        switch strategy {
        case .keepOldest:
            groupFiles.sort { $0.modificationDate < $1.modificationDate }
        case .keepNewest:
            groupFiles.sort { $0.modificationDate > $1.modificationDate }
        case .keepShortestPath:
            groupFiles.sort { $0.path.count < $1.path.count }
        }
        
        // First file is the original to KEEP; all subsequent files are selected for removal
        for idx in groupFiles.indices {
            if idx == 0 {
                groupFiles[idx].isSelectedForRemoval = false
                groupFiles[idx].isKeptOriginal = true
            } else {
                groupFiles[idx].isSelectedForRemoval = true
                groupFiles[idx].isKeptOriginal = false
            }
        }
        
        duplicateGroups[index].files = groupFiles
    }
    
    public func toggleFileSelection(groupId: UUID, fileId: UUID) {
        guard let gIdx = duplicateGroups.firstIndex(where: { $0.id == groupId }) else { return }
        guard let fIdx = duplicateGroups[gIdx].files.firstIndex(where: { $0.id == fileId }) else { return }
        
        duplicateGroups[gIdx].files[fIdx].isSelectedForRemoval.toggle()
        
        // Update kept original indicator
        let retained = duplicateGroups[gIdx].files.filter { !$0.isSelectedForRemoval }
        if retained.count == 1, let keptId = retained.first?.id {
            for i in duplicateGroups[gIdx].files.indices {
                duplicateGroups[gIdx].files[i].isKeptOriginal = (duplicateGroups[gIdx].files[i].id == keptId)
            }
        } else {
            for i in duplicateGroups[gIdx].files.indices {
                duplicateGroups[gIdx].files[i].isKeptOriginal = false
            }
        }
    }
    
    // MARK: - Reveal in Finder
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - 3-Stage Duplicate Finding Pipeline
    public func startScan(rootURL: URL? = nil) async {
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        duplicateGroups = []
        lastCleanResult = nil
        showCelebration = false
        
        let targetURL = rootURL ?? FileManager.default.homeDirectoryForCurrentUser
        let startTime = Date()
        
        // STAGE 1: Fast Size Grouping
        currentStage = .groupingBySize
        statusMessage = "Stage 1/3: Scanning files & grouping by exact byte size..."
        
        let sizeGroups = await Task.detached(priority: .userInitiated) { () -> [Int64: [URL]] in
            let fm = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .isSymbolicLinkKey,
                .isPackageKey
            ]
            
            let skipPaths: [String] = [
                targetURL.appendingPathComponent("Library").path,
                targetURL.appendingPathComponent(".Trash").path
            ]
            
            guard let enumerator = fm.enumerator(
                at: targetURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                return [:]
            }
            
            var map: [Int64: [URL]] = [:]
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                let path = fileURL.path
                
                // CRITICAL SAFETY CHECK: NEVER enter Photos library packages
                if path.contains(".photoslibrary") || path.contains(".photolibrary") {
                    enumerator.skipDescendants()
                    continue
                }
                
                // Skip system Library, Trash, and hidden files/folders
                var skip = false
                for p in skipPaths {
                    if path.hasPrefix(p) {
                        enumerator.skipDescendants()
                        skip = true
                        break
                    }
                }
                if skip { continue }
                
                if fileURL.lastPathComponent.hasPrefix(".") {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true || values.isPackage == true { continue }
                guard values.isRegularFile == true else { continue }
                
                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                guard size > 100 else { continue } // Skip 0-byte and trivial files
                
                map[size, default: []].append(fileURL)
            }
            
            // Filter: Only keep sizes with at least 2 files
            return map.filter { $0.value.count >= 2 }
        }.value
        
        guard !sizeGroups.isEmpty else {
            finishScanEmpty(startTime: startTime)
            return
        }
        
        progress = 0.33
        
        // STAGE 2: Fast Partial Hash (First 8KB Chunk)
        currentStage = .partialHashing
        statusMessage = "Stage 2/3: Filtering candidates with fast 8KB partial hashes..."
        
        struct PartialKey: Hashable {
            let size: Int64
            let hash: String
        }
        
        let partialGroups = await Task.detached(priority: .userInitiated) { () -> [PartialKey: [URL]] in
            var map: [PartialKey: [URL]] = [:]
            
            for (size, urls) in sizeGroups {
                if Task.isCancelled { break }
                for url in urls {
                    if let handle = try? FileHandle(forReadingFrom: url) {
                        let chunk = (try? handle.read(upToCount: 8192)) ?? nil
                        try? handle.close()
                        
                        if let data = chunk {
                            let digest = SHA256.hash(data: data)
                            let hex = digest.map { String(format: "%02x", $0) }.joined()
                            let key = PartialKey(size: size, hash: hex)
                            map[key, default: []].append(url)
                        }
                    }
                }
            }
            
            // Filter: Only keep groups with at least 2 files
            return map.filter { $0.value.count >= 2 }
        }.value
        
        guard !partialGroups.isEmpty else {
            finishScanEmpty(startTime: startTime)
            return
        }
        
        progress = 0.66
        
        // STAGE 3: Full SHA-256 Checksum Verification
        currentStage = .fullHashing
        statusMessage = "Stage 3/3: Verifying full SHA-256 cryptographic hashes..."
        
        struct FullKey: Hashable {
            let size: Int64
            let sha256: String
        }
        
        let fullGroups = await Task.detached(priority: .userInitiated) { () -> [FullKey: [URL]] in
            var map: [FullKey: [URL]] = [:]
            
            for (partialKey, urls) in partialGroups {
                if Task.isCancelled { break }
                for url in urls {
                    guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
                    var hasher = SHA256()
                    var readFailed = false
                    
                    while true {
                        do {
                            guard let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty else {
                                break
                            }
                            hasher.update(data: chunk)
                        } catch {
                            readFailed = true
                            break
                        }
                    }
                    try? handle.close()
                    
                    if !readFailed {
                        let digest = hasher.finalize()
                        let fullHex = digest.map { String(format: "%02x", $0) }.joined()
                        let key = FullKey(size: partialKey.size, sha256: fullHex)
                        map[key, default: []].append(url)
                    }
                }
            }
            
            // Filter: Only keep confirmed duplicates (count >= 2)
            return map.filter { $0.value.count >= 2 }
        }.value
        
        // BUILD DUPLICATE GROUPS
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var parsedGroups: [DuplicateGroup] = []
        
        for (key, urls) in fullGroups {
            var fileItems: [DuplicateFileItem] = []
            
            for url in urls {
                let path = url.path
                let displayPath = path.replacingOccurrences(of: homePath, with: "~")
                let dirPath = url.deletingLastPathComponent().path.replacingOccurrences(of: homePath, with: "~")
                let name = url.lastPathComponent
                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                
                let item = DuplicateFileItem(
                    url: url,
                    path: displayPath,
                    directoryPath: dirPath,
                    name: name,
                    size: key.size,
                    modificationDate: modDate,
                    isSelectedForRemoval: false,
                    isKeptOriginal: false
                )
                fileItems.append(item)
            }
            
            let (category, icon, color) = detectCategory(for: urls.first?.pathExtension.lowercased() ?? "")
            let groupName = urls.first?.lastPathComponent ?? "Duplicate Files"
            
            let group = DuplicateGroup(
                fullHash: key.sha256,
                fileSize: key.size,
                fileName: groupName,
                category: category,
                icon: icon,
                color: color,
                files: fileItems,
                isExpanded: true
            )
            parsedGroups.append(group)
        }
        
        // Sort groups by wasted space descending
        parsedGroups.sort { $0.wastedSpace > $1.wastedSpace }
        
        self.duplicateGroups = parsedGroups
        
        // Auto-select "Keep One" by default
        applyKeepOneAutoSelect()
        
        self.isScanning = false
        self.currentStage = .completed
        self.progress = 1.0
        
        let elapsed = Date().timeIntervalSince(startTime)
        self.statusMessage = "Found \(duplicateGroups.count) duplicate groups (\(formattedTotalWastedSpace) wasted) in \(String(format: "%.1f", elapsed))s"
    }
    
    private func finishScanEmpty(startTime: Date) {
        self.duplicateGroups = []
        self.isScanning = false
        self.currentStage = .completed
        self.progress = 1.0
        let elapsed = Date().timeIntervalSince(startTime)
        self.statusMessage = "No duplicate files found (\(String(format: "%.1f", elapsed))s)."
    }
    
    // MARK: - Category Detection Helper
    private func detectCategory(for ext: String) -> (String, String, Color) {
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "raw", "psd", "svg", "webp":
            return ("Photos", "photo.fill", .green)
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "txt", "rtf", "csv":
            return ("Documents", "doc.text.fill", .blue)
        case "mp4", "mov", "mkv", "avi", "wmv", "m4v", "flv":
            return ("Videos", "film", .purple)
        case "mp3", "wav", "flac", "aac", "m4a", "ogg":
            return ("Audio", "waveform", .pink)
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "dmg", "iso":
            return ("Archives", "doc.zipper", .orange)
        default:
            return ("Other", "doc.on.doc.fill", .indigo)
        }
    }
    
    // MARK: - Safe Delete Action (Move to macOS Trash)
    // CRITICAL: MUST NEVER delete anything without user confirmation!
    public func moveSelectedDuplicatesToTrash(userConfirmed: Bool) async {
        guard userConfirmed else {
            print("Action blocked: Deletion not confirmed by user.")
            return
        }
        guard !isCleaning else { return }
        isCleaning = true
        statusMessage = "Moving confirmed duplicates to macOS Trash..."
        
        let startTime = Date()
        var reclaimedBytes: Int64 = 0
        var reclaimedCount: Int = 0
        var errorsCount: Int = 0
        
        let fm = FileManager.default
        var updatedGroups: [DuplicateGroup] = []
        
        for var group in duplicateGroups {
            var remainingFiles: [DuplicateFileItem] = []
            
            for file in group.files {
                if file.isSelectedForRemoval {
                    do {
                        // Safely move to macOS Trash
                        try fm.trashItem(at: file.url, resultingItemURL: nil)
                        reclaimedBytes += file.size
                        reclaimedCount += 1
                    } catch {
                        errorsCount += 1
                        print("Error moving duplicate to Trash: \(file.path), error: \(error.localizedDescription)")
                        remainingFiles.append(file)
                    }
                } else {
                    remainingFiles.append(file)
                }
            }
            
            // Only keep group if 2 or more files remain
            if remainingFiles.count >= 2 {
                group.files = remainingFiles
                updatedGroups.append(group)
            }
        }
        
        self.duplicateGroups = updatedGroups
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: reclaimedBytes,
            reclaimedFilesCount: reclaimedCount,
            errorsCount: errorsCount,
            duration: elapsed,
            cleanedCategorySizes: [:]
        )
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showCelebration = true
        self.statusMessage = "Successfully moved \(reclaimedCount) duplicates (\(ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file))) to Trash."
        
        StorageModel.shared.refresh()
    }
}
