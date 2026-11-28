import Foundation
import SwiftUI
import AppKit

@MainActor
public class LargeOldFilesScanner: ObservableObject {
    public static let shared = LargeOldFilesScanner()
    
    @Published public var files: [LargeOldFileItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready to scan Home directory"
    @Published public var scannedCount: Int = 0
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var showCelebration: Bool = false
    @Published public var scanError: String? = nil
    
    // Filters and Sorting
    @Published public var selectedCategory: String = "All"
    @Published public var criteriaFilter: LargeOldCriteriaFilter = .all
    @Published public var sortOption: LargeOldSortOption = .sizeDescending
    @Published public var searchKeyword: String = ""
    
    private let deletionLogManager: DeletionLogManager
    
    public init(deletionLogManager: DeletionLogManager = .shared) {
        self.deletionLogManager = deletionLogManager
    }
    
    // Computed statistics
    public var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    public var selectedFiles: [LargeOldFileItem] {
        filteredFiles.filter { $0.isSelected }
    }
    
    public var selectedSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
    
    public var largeFilesCount: Int {
        files.filter { $0.isLarge }.count
    }
    
    public var oldFilesCount: Int {
        files.filter { $0.isOld }.count
    }
    
    // Filtered and sorted files
    public var filteredFiles: [LargeOldFileItem] {
        var result = files
        
        // 1. Criteria Filter
        switch criteriaFilter {
        case .all:
            break
        case .largeOnly:
            result = result.filter { $0.isLarge }
        case .oldOnly:
            result = result.filter { $0.isOld }
        }
        
        // 2. Category / File Type Filter
        if selectedCategory != "All" {
            result = result.filter { $0.fileType.rawValue == selectedCategory }
        }
        
        // 3. Search Keyword
        let query = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query) }
        }
        
        // 4. Sorting
        switch sortOption {
        case .sizeDescending:
            result.sort { $0.size > $1.size }
        case .sizeAscending:
            result.sort { $0.size < $1.size }
        case .dateOldest:
            result.sort { $0.modificationDate < $1.modificationDate }
        case .dateNewest:
            result.sort { $0.modificationDate > $1.modificationDate }
        case .nameAZ:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameZA:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        }
        
        return result
    }
    
    // Toggle Select All
    public func toggleSelectAll(_ select: Bool) {
        let matchingIDs = Set(filteredFiles.map { $0.id })
        for idx in files.indices {
            if matchingIDs.contains(files[idx].id) {
                files[idx].isSelected = select
            }
        }
    }
    
    // MARK: - Scan Home Folder
    public func startScan(customURL: URL? = nil) async {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Starting Large & Old Files scan..."
        scanProgress = 0.0
        scannedCount = 0
        lastCleanResult = nil
        showCelebration = false
        files = []
        
        let rootURL = customURL ?? FileManager.default.homeDirectoryForCurrentUser
        let startTime = Date()
        
        let discoveredItems = await Task.detached(priority: .userInitiated) { () -> [LargeOldFileItem] in
            let fm = FileManager.default
            let homePath = fm.homeDirectoryForCurrentUser.path
            
            let resourceKeys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .contentModificationDateKey,
                .isSymbolicLinkKey,
                .isPackageKey
            ]
            
            // Paths to skip for safety and efficiency
            let skipPrefixes: [String] = [
                rootURL.appendingPathComponent("Library").path,
                rootURL.appendingPathComponent(".Trash").path
            ]
            
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                return []
            }
            
            var matched: [LargeOldFileItem] = []
            let calendar = Calendar.current
            let now = Date()
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                let filePath = fileURL.path
                
                // Skip system Library and Trash
                var shouldSkip = false
                for prefix in skipPrefixes {
                    if filePath.hasPrefix(prefix) {
                        enumerator.skipDescendants()
                        shouldSkip = true
                        break
                    }
                }
                if shouldSkip { continue }
                
                // Skip hidden folders and files (starting with dot)
                let lastComponent = fileURL.lastPathComponent
                if lastComponent.hasPrefix(".") {
                    enumerator.skipDescendants()
                    continue
                }
                
                // Do not enter Photos library packages
                if filePath.contains(".photoslibrary") || filePath.contains(".photolibrary") {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
                
                // Skip symlinks and packages
                if values.isSymbolicLink == true || values.isPackage == true {
                    continue
                }
                
                guard values.isRegularFile == true else { continue }
                
                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                let modDate = values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
                let ageInDays = calendar.dateComponents([.day], from: modDate, to: now).day ?? 0
                
                let is100MBPlus = size >= (100 * 1024 * 1024)
                let is1YearOld = ageInDays >= 365 && size >= (100 * 1024) // At least 100KB to avoid zero/tiny cache files
                
                if is100MBPlus || is1YearOld {
                    let displayPath = filePath.replacingOccurrences(of: homePath, with: "~")
                    let fileType = LargeOldFileType.detect(from: fileURL)
                    
                    let item = LargeOldFileItem(
                        url: fileURL,
                        name: lastComponent,
                        path: displayPath,
                        size: size,
                        modificationDate: modDate,
                        fileType: fileType,
                        isSelected: false
                    )
                    matched.append(item)
                }
            }
            
            return matched
        }.value
        
        self.files = discoveredItems
        self.isScanning = false
        self.scanProgress = 1.0
        
        let elapsed = Date().timeIntervalSince(startTime)
        self.statusMessage = "Found \(files.count) files (\(formattedTotalSize)) in \(String(format: "%.1f", elapsed))s"
    }
    
    // MARK: - Actions: Reveal in Finder
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - Actions: Quick Look / Open
    public func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Actions: Move to Trash (Single)
    public func moveToTrash(item: LargeOldFileItem) {
        moveToTrash(item: item, trashHandler: nil)
    }
    
    public func moveToTrash(item: LargeOldFileItem, trashHandler: ((URL) throws -> Void)?) {
        if let protErr = PathProtection.evaluatePath(url: item.url) {
            deletionLogManager.log(
                sourceModule: "Large & Old Files",
                path: item.url.path,
                sizeBytes: item.size,
                destination: .trash,
                isSuccess: false,
                errorMessage: protErr.localizedDescription
            )
            statusMessage = "Cannot delete protected file: \(protErr.localizedDescription)"
            scanError = protErr.localizedDescription
            return
        }
        
        if DryRunManager.shared.isEnabled {
            DryRunManager.shared.logSimulation(action: "Move to Trash", target: item.path)
            deletionLogManager.log(
                sourceModule: "Large & Old Files",
                path: item.url.path,
                sizeBytes: item.size,
                destination: .simulated,
                isSuccess: true
            )
            files.removeAll { $0.id == item.id }
            statusMessage = "[Dry-Run] Simulated moving '\(item.name)' to Trash."
            return
        }
        
        let fm = FileManager.default
        do {
            if let trashHandler = trashHandler {
                try trashHandler(item.url)
            } else {
                try fm.trashItem(at: item.url, resultingItemURL: nil)
            }
            deletionLogManager.log(
                sourceModule: "Large & Old Files",
                path: item.url.path,
                sizeBytes: item.size,
                destination: .trash,
                isSuccess: true
            )
            files.removeAll { $0.id == item.id }
            statusMessage = "Moved '\(item.name)' to Trash."
            StorageModel.shared.refresh()
        } catch {
            deletionLogManager.log(
                sourceModule: "Large & Old Files",
                path: item.url.path,
                sizeBytes: item.size,
                destination: .trash,
                isSuccess: false,
                errorMessage: error.localizedDescription
            )
            statusMessage = "Failed to move '\(item.name)' to Trash: \(error.localizedDescription)"
            scanError = error.localizedDescription
        }
    }
    
    // MARK: - Actions: Move Selected to Trash
    public func moveSelectedToTrash() async {
        await moveSelectedToTrash(trashHandler: nil)
    }
    
    public func moveSelectedToTrash(trashHandler: (@Sendable (URL) throws -> Void)?) async {
        guard !isCleaning && !isScanning else { return }
        isCleaning = true
        let isDryRun = DryRunManager.shared.isEnabled
        statusMessage = isDryRun ? "Simulating file cleanup (Dry-Run mode)..." : "Moving selected files to macOS Trash..."
        
        let startTime = Date()
        let itemsToTrash = selectedFiles
        let logManager = self.deletionLogManager
        
        let outcome = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var reclaimedBytes: Int64 = 0
            var reclaimedCount: Int = 0
            var errorsCount: Int = 0
            var removedIDs = Set<UUID>()
            var dryRunTargets: [String] = []
            
            for item in itemsToTrash {
                if let protErr = PathProtection.evaluatePath(url: item.url) {
                    AppLogger.security.warning("Skipping protected file: \(item.path) - \(protErr.localizedDescription)")
                    logManager.log(
                        sourceModule: "Large & Old Files",
                        path: item.url.path,
                        sizeBytes: item.size,
                        destination: .trash,
                        isSuccess: false,
                        errorMessage: protErr.localizedDescription
                    )
                    errorsCount += 1
                    continue
                }
                
                if isDryRun {
                    dryRunTargets.append(item.path)
                    logManager.log(
                        sourceModule: "Large & Old Files",
                        path: item.url.path,
                        sizeBytes: item.size,
                        destination: .simulated,
                        isSuccess: true
                    )
                    reclaimedBytes += item.size
                    reclaimedCount += 1
                    removedIDs.insert(item.id)
                } else {
                    do {
                        if let trashHandler = trashHandler {
                            try trashHandler(item.url)
                        } else {
                            try fm.trashItem(at: item.url, resultingItemURL: nil)
                        }
                        logManager.log(
                            sourceModule: "Large & Old Files",
                            path: item.url.path,
                            sizeBytes: item.size,
                            destination: .trash,
                            isSuccess: true
                        )
                        reclaimedBytes += item.size
                        reclaimedCount += 1
                        removedIDs.insert(item.id)
                    } catch {
                        errorsCount += 1
                        AppLogger.cleanup.error("Error trashing \(item.path): \(error.localizedDescription)")
                        logManager.log(
                            sourceModule: "Large & Old Files",
                            path: item.url.path,
                            sizeBytes: item.size,
                            destination: .trash,
                            isSuccess: false,
                            errorMessage: error.localizedDescription
                        )
                    }
                }
            }
            
            return (
                reclaimedBytes: reclaimedBytes,
                reclaimedCount: reclaimedCount,
                errorsCount: errorsCount,
                removedIDs: removedIDs,
                dryRunTargets: dryRunTargets
            )
        }.value
        
        for target in outcome.dryRunTargets {
            DryRunManager.shared.logSimulation(action: "Move to Trash", target: target)
        }
        
        files.removeAll { outcome.removedIDs.contains($0.id) }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: outcome.reclaimedBytes,
            reclaimedFilesCount: outcome.reclaimedCount,
            errorsCount: outcome.errorsCount,
            duration: elapsed,
            cleanedCategorySizes: [:],
            isDryRun: isDryRun
        )
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showCelebration = true
        self.statusMessage = isDryRun ?
            "Dry-Run: Simulated \(outcome.reclaimedCount) files (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)))." :
            "Successfully moved \(outcome.reclaimedCount) files (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file))) to Trash."
        
        StorageModel.shared.refresh()
    }
}
