import Foundation
import SwiftUI

// MARK: - Nonisolated Fast Sizing & File Inspection Engine
public enum JunkScanEngine {
    
    public static func friendlyAppName(from bundleIdOrFolder: String) -> String {
        var clean = bundleIdOrFolder
        if clean.hasPrefix("com.") {
            let parts = clean.split(separator: ".")
            if parts.count >= 2 {
                clean = String(parts.dropFirst().joined(separator: " "))
            }
        }
        
        let lower = clean.lowercased()
        if lower.contains("spotify") { return "Spotify Cache" }
        if lower.contains("slack") { return "Slack Cache" }
        if lower.contains("google") || lower.contains("chrome") { return "Google Chrome Cache" }
        if lower.contains("vscode") || lower.contains("code") { return "VS Code Cache" }
        if lower.contains("telegram") { return "Telegram Cache" }
        if lower.contains("whatsapp") { return "WhatsApp Cache" }
        if lower.contains("discord") { return "Discord Cache" }
        if lower.contains("notion") { return "Notion Cache" }
        if lower.contains("brave") { return "Brave Cache" }
        if lower.contains("safari") { return "Safari Cache" }
        if lower.contains("quicklook") { return "QuickLook Thumbnails" }
        if lower.contains("cloudkit") { return "CloudKit Cache" }
        if lower.contains("xcode") { return "Xcode Cache" }
        
        return clean.capitalized
    }
    
    public static func calculateSizeFast(of url: URL, fm: FileManager = .default) -> (bytes: Int64, filesCount: Int) {
        let res = SizeCalculator.calculateSize(of: url, fm: fm)
        return (res.bytes, res.filesCount)
    }
    
    /// Folder names under ~/Library/Caches owned by browser or Xcode scanners to prevent double-counting.
    public static let excludedUserCacheDirectories: Set<String> = [
        "com.apple.Safari",
        "Google",
        "Firefox",
        "Mozilla",
        "Microsoft Edge",
        "BraveSoftware",
        "company.thebrowser.Browser",
        "com.apple.dt.Xcode"
    ]
    
    private static let excludedUserCacheDirectoriesLowercased: Set<String> = Set(
        excludedUserCacheDirectories.map { $0.lowercased() }
    )
    
    // MARK: 1. User Caches
    public static func scanUserAppCaches(home: URL, fm: FileManager) async -> [JunkItem] {
        let cachesURL = home.appendingPathComponent("Library/Caches")
        guard fm.fileExists(atPath: cachesURL.path) else { return [] }
        
        guard let subdirs = try? fm.contentsOfDirectory(
            at: cachesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for subURL in subdirs {
                if excludedUserCacheDirectoriesLowercased.contains(subURL.lastPathComponent.lowercased()) {
                    continue
                }
                group.addTask {
                    let (size, count) = calculateSizeFast(of: subURL, fm: fm)
                    guard size > 100 * 1024 else { return nil } // Filter out negligible items (< 100KB)
                    
                    let name = friendlyAppName(from: subURL.lastPathComponent)
                    return JunkItem(
                        category: .userCaches,
                        name: name,
                        path: subURL,
                        size: size,
                        fileCount: count,
                        isSelected: true,
                        details: subURL.path.replacingOccurrences(of: home.path, with: "~"),
                        icon: "folder.badge.gearshape"
                    )
                }
            }
            
            var items: [JunkItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: 2. Logs
    public static func scanLogs(
        home: URL,
        fm: FileManager,
        systemLogsURL: URL = URL(fileURLWithPath: "/Library/Logs")
    ) async -> [JunkItem] {
        let logRoots: [(url: URL, isSystem: Bool, icon: String)] = [
            (home.appendingPathComponent("Library/Logs"), false, "doc.text.magnifyingglass"),
            (systemLogsURL, true, "gearshape.2.fill")
        ]
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for root in logRoots {
                guard fm.fileExists(atPath: root.url.path) else { continue }
                guard let entries = try? fm.contentsOfDirectory(
                    at: root.url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }
                
                for entryURL in entries {
                    group.addTask {
                        let (size, count) = calculateSizeFast(of: entryURL, fm: fm)
                        guard size > 0 else { return nil }
                        
                        let displayPath = root.isSystem
                            ? entryURL.path
                            : entryURL.path.replacingOccurrences(of: home.path, with: "~")
                        
                        return JunkItem(
                            category: .systemLogs,
                            name: entryURL.lastPathComponent,
                            path: entryURL,
                            size: size,
                            fileCount: count,
                            isSelected: true,
                            details: displayPath,
                            icon: root.icon
                        )
                    }
                }
            }
            
            var items: [JunkItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: 3. Xcode & Developer
    public static func scanXcodeAndDeveloper(home: URL, fm: FileManager) async -> [JunkItem] {
        let targets: [(name: String, path: URL, desc: String, icon: String)] = [
            ("Xcode DerivedData", home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), "Intermediate build products, module caches, and project indexes", "hammer.fill"),
            ("iOS DeviceSupport", home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), "Symbol files for connected physical iOS devices", "ipad.and.iphone"),
            ("CoreSimulator Caches", home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"), "Simulator temporary asset caches and runtime data", "macwindow"),
            ("Xcode App Cache", home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"), "Xcode compilation and asset caches", "hammer"),
            ("Xcode Archives", home.appendingPathComponent("Library/Developer/Xcode/Archives"), "Local app archives and build bundles", "archivebox.fill"),
            ("Xcode Documentation Cache", home.appendingPathComponent("Library/Developer/Xcode/DocumentationCache"), "Downloaded documentation index cache", "book.closed")
        ]
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for target in targets {
                group.addTask {
                    guard fm.fileExists(atPath: target.path.path) else { return nil }
                    let (size, count) = calculateSizeFast(of: target.path, fm: fm)
                    guard size > 0 else { return nil }
                    
                    return JunkItem(
                        category: .xcodeDeveloper,
                        name: target.name,
                        path: target.path,
                        size: size,
                        fileCount: count,
                        isSelected: true,
                        details: target.desc,
                        icon: target.icon
                    )
                }
            }
            
            var items: [JunkItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: 4. Browser Caches
    public static func scanBrowserCaches(home: URL, fm: FileManager) async -> [JunkItem] {
        let browserTargets: [(name: String, path: URL, icon: String)] = [
            ("Safari Container Cache", home.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Caches"), "safari.fill"),
            ("Safari Cache", home.appendingPathComponent("Library/Caches/com.apple.Safari"), "safari.fill"),
            ("Google Chrome Cache", home.appendingPathComponent("Library/Caches/Google/Chrome"), "globe"),
            ("Google Chrome Profile Cache", home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"), "globe"),
            ("Google Chrome Code Cache", home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Code Cache"), "globe"),
            ("Mozilla Firefox Cache", home.appendingPathComponent("Library/Caches/Firefox"), "flame.fill"),
            ("Mozilla Firefox Legacy Cache", home.appendingPathComponent("Library/Caches/Mozilla/Firefox"), "flame.fill"),
            ("Microsoft Edge Cache", home.appendingPathComponent("Library/Caches/Microsoft Edge"), "globe.europe.africa.fill"),
            ("Microsoft Edge Profile Cache", home.appendingPathComponent("Library/Application Support/Microsoft Edge/Default/Cache"), "globe.europe.africa.fill"),
            ("Brave Browser Cache", home.appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser"), "shield.fill"),
            ("Brave Browser Profile Cache", home.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache"), "shield.fill"),
            ("Arc Browser Cache", home.appendingPathComponent("Library/Caches/company.thebrowser.Browser"), "circle.grid.2x2.fill")
        ]
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for target in browserTargets {
                group.addTask {
                    guard fm.fileExists(atPath: target.path.path) else { return nil }
                    let (size, count) = calculateSizeFast(of: target.path, fm: fm)
                    guard size > 10 * 1024 else { return nil }
                    
                    return JunkItem(
                        category: .browserCaches,
                        name: target.name,
                        path: target.path,
                        size: size,
                        fileCount: count,
                        isSelected: true,
                        details: target.path.path.replacingOccurrences(of: home.path, with: "~"),
                        icon: target.icon
                    )
                }
            }
            
            var items: [JunkItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: 5. Mail Attachments
    public static func scanMailAttachments(home: URL, fm: FileManager) async -> [JunkItem] {
        let mailPaths: [(name: String, path: URL, desc: String)] = [
            (
                "Mail Downloads Cache",
                home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                "Downloaded email attachments opened in Apple Mail"
            ),
            (
                "Legacy Mail Downloads",
                home.appendingPathComponent("Library/Mail Downloads"),
                "Opened email attachments from previous macOS versions"
            ),
            (
                "Mail Application Cache",
                home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Caches"),
                "Temporary message previews, avatars, and metadata cache"
            )
        ]
        
        var items: [JunkItem] = []
        for target in mailPaths {
            if fm.fileExists(atPath: target.path.path) {
                let (size, count) = calculateSizeFast(of: target.path, fm: fm)
                if size > 0 {
                    items.append(JunkItem(
                        category: .mailAttachments,
                        name: target.name,
                        path: target.path,
                        size: size,
                        fileCount: count,
                        isSelected: false, // Default false for safety
                        details: target.desc,
                        icon: "envelope.fill"
                    ))
                }
            }
        }
        return items
    }
    
    // MARK: 6. Trash
    public static func scanTrash(home: URL, fm: FileManager) async -> [JunkItem] {
        let trashURL = home.appendingPathComponent(".Trash")
        guard fm.fileExists(atPath: trashURL.path) else { return [] }
        
        guard let trashContents = try? fm.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return [] }
        
        guard !trashContents.isEmpty else { return [] }
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for itemURL in trashContents {
                group.addTask {
                    let (size, count) = calculateSizeFast(of: itemURL, fm: fm)
                    return JunkItem(
                        category: .trash,
                        name: itemURL.lastPathComponent,
                        path: itemURL,
                        size: size,
                        fileCount: count,
                        isSelected: true,
                        details: "In macOS Trash: \(itemURL.lastPathComponent)",
                        icon: "trash"
                    )
                }
            }
            
            var items: [JunkItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            return items.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: 7. iOS Backups
    public static func scanIOSBackups(home: URL, fm: FileManager) async -> [JunkItem] {
        let backupURL = home.appendingPathComponent("Library/Application Support/MobileSync/Backup")
        guard fm.fileExists(atPath: backupURL.path) else { return [] }
        
        guard let backups = try? fm.contentsOfDirectory(
            at: backupURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var items: [JunkItem] = []
        for backup in backups {
            let (size, count) = calculateSizeFast(of: backup, fm: fm)
            if size > 0 {
                items.append(JunkItem(
                    category: .iosBackups,
                    name: "iOS Backup (\(backup.lastPathComponent.prefix(8))...)",
                    path: backup,
                    size: size,
                    fileCount: count,
                    isSelected: false, // Default false for safety
                    details: backup.path.replacingOccurrences(of: home.path, with: "~"),
                    icon: "iphone"
                ))
            }
        }
        return items
    }
    
}

// MARK: - Main Actor System Junk Scanner Model
@MainActor
public class SystemJunkScanner: ObservableObject {
    public static let shared = SystemJunkScanner()
    
    @Published public var categories: [JunkCategory] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var currentScanningStep: String = ""
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var showReclaimedAnimation: Bool = false
    @Published public var scanError: String? = nil
    
    // Overall Stats
    public var totalFoundSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
    }
    
    public var totalSelectedSize: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }
    
    public var totalFoundFilesCount: Int {
        categories.reduce(0) { $0 + $1.totalFileCount }
    }
    
    public var totalSelectedFilesCount: Int {
        categories.reduce(0) { $0 + $1.selectedFileCount }
    }
    
    public var formattedTotalFoundSize: String {
        ByteCountFormatter.string(fromByteCount: totalFoundSize, countStyle: .file)
    }
    
    public var formattedTotalSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    public var allSelected: Bool {
        guard !categories.isEmpty else { return false }
        return categories.allSatisfy { $0.isSelected }
    }
    
    private let deletionLogManager: DeletionLogManager
    
    public init(deletionLogManager: DeletionLogManager = .shared) {
        self.deletionLogManager = deletionLogManager
        resetCategories()
    }
    
    public func resetCategories() {
        self.categories = JunkCategoryType.allCases.map {
            JunkCategory(id: $0, items: [], isExpanded: false, isScanning: false)
        }
    }
    
    public func toggleSelectAll(_ select: Bool) {
        for catIdx in categories.indices {
            for itemIdx in categories[catIdx].items.indices {
                categories[catIdx].items[itemIdx].isSelected = select
            }
        }
    }
    
    // MARK: - Fast Concurrent Scan
    
    public func startScan() async {
        guard !isScanning && !isCleaning else { return }
        isScanning = true
        scanProgress = 0.0
        currentScanningStep = "Preparing System Junk scan..."
        scanError = nil
        lastCleanResult = nil
        showReclaimedAnimation = false
        
        let startTime = Date()
        resetCategories()
        
        let targetCategories = JunkCategoryType.allCases
        let totalSteps = Double(targetCategories.count)
        var completedSteps: Double = 0.0
        
        var scannedCategories: [JunkCategory] = []
        
        for categoryType in targetCategories {
            currentScanningStep = "Scanning \(categoryType.rawValue)..."
            
            let items = await scanCategory(type: categoryType)
            
            var category = JunkCategory(
                id: categoryType,
                items: items,
                isExpanded: false,
                isScanning: false
            )
            
            // Set default selection based on category rules
            for idx in category.items.indices {
                category.items[idx].isSelected = categoryType.defaultSelected
            }
            
            scannedCategories.append(category)
            completedSteps += 1.0
            scanProgress = completedSteps / totalSteps
        }
        
        self.categories = scannedCategories
        self.isScanning = false
        self.currentScanningStep = "Scan complete! Found \(formattedTotalFoundSize) across \(totalFoundFilesCount) items."
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("System Junk scan finished in \(String(format: "%.2f", elapsed))s. Total size: \(formattedTotalFoundSize)")
    }
    
    private func scanCategory(type: JunkCategoryType) async -> [JunkItem] {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            
            switch type {
            case .userCaches:
                return await JunkScanEngine.scanUserAppCaches(home: home, fm: fm)
            case .systemLogs:
                return await JunkScanEngine.scanLogs(home: home, fm: fm)
            case .xcodeDeveloper:
                return await JunkScanEngine.scanXcodeAndDeveloper(home: home, fm: fm)
            case .browserCaches:
                return await JunkScanEngine.scanBrowserCaches(home: home, fm: fm)
            case .mailAttachments:
                return await JunkScanEngine.scanMailAttachments(home: home, fm: fm)
            case .trash:
                return await JunkScanEngine.scanTrash(home: home, fm: fm)
            case .iosBackups:
                return await JunkScanEngine.scanIOSBackups(home: home, fm: fm)
            }
        }.value
    }
    
    // MARK: - Clean Action (Send to Trash)
    
    public func performClean() async {
        await performClean(trashHandler: nil)
    }
    
    public func performClean(trashHandler: (@Sendable (URL) throws -> Void)?) async {
        guard !isCleaning && !isScanning else { return }
        isCleaning = true
        let isDryRun = DryRunManager.shared.isEnabled
        currentScanningStep = isDryRun ? "Simulating junk cleanup (Dry-Run mode)..." : "Moving selected junk to macOS Trash..."
        
        let startTime = Date()
        let categoriesSnapshot = self.categories
        let logManager = self.deletionLogManager
        
        let outcome = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let homeTrashURL = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
            let rawTrashPath = homeTrashURL.standardizedFileURL.path
            let standardizedHomeTrashPath = PathProtection.standardizedPath(of: homeTrashURL)
            
            var reclaimedBytes: Int64 = 0
            var reclaimedFiles: Int = 0
            var errorsCount: Int = 0
            var categoryReclaimed: [JunkCategoryType: Int64] = [:]
            var updatedCategories: [JunkCategory] = []
            var dryRunTargets: [String] = []
            
            for var category in categoriesSnapshot {
                let categoryType = category.id
                var catReclaimedForType: Int64 = 0
                var remainingItems: [JunkItem] = []
                
                for item in category.items {
                    guard item.isSelected else {
                        remainingItems.append(item)
                        continue
                    }
                    
                    let rawItemPath = item.path.standardizedFileURL.path
                    let standardizedItemPath = PathProtection.standardizedPath(of: item.path)
                    let isInTrash = item.category == .trash
                        || rawItemPath.hasPrefix(rawTrashPath + "/")
                        || standardizedItemPath.hasPrefix(standardizedHomeTrashPath + "/")
                    let intendedDestination: DeletionDestination = isInTrash ? .permanent : .trash
                    
                    // Safety check against critical system paths
                    if let protErr = PathProtection.evaluatePath(url: item.path) {
                        AppLogger.security.warning("Skipping protected path: \(item.path.path) - \(protErr.localizedDescription)")
                        logManager.log(
                            sourceModule: "System Junk",
                            path: item.path.path,
                            sizeBytes: item.size,
                            destination: intendedDestination,
                            isSuccess: false,
                            errorMessage: protErr.localizedDescription
                        )
                        errorsCount += 1
                        remainingItems.append(item)
                        continue
                    }
                    
                    if isDryRun {
                        dryRunTargets.append(item.path.path)
                        logManager.log(
                            sourceModule: "System Junk",
                            path: item.path.path,
                            sizeBytes: item.size,
                            destination: .simulated,
                            isSuccess: true
                        )
                        reclaimedBytes += item.size
                        reclaimedFiles += max(1, item.fileCount)
                        catReclaimedForType += item.size
                    } else {
                        do {
                            if isInTrash {
                                guard rawItemPath != rawTrashPath && standardizedItemPath != standardizedHomeTrashPath else {
                                    throw PathProtectionError.essentialUserDirectory(item.path.path)
                                }
                                // Already in trash -> remove to empty trash item
                                try fm.removeItem(at: item.path)
                            } else if let trashHandler = trashHandler {
                                try trashHandler(item.path)
                            } else {
                                // Move to macOS Trash safely!
                                try fm.trashItem(at: item.path, resultingItemURL: nil)
                            }
                            
                            logManager.log(
                                sourceModule: "System Junk",
                                path: item.path.path,
                                sizeBytes: item.size,
                                destination: intendedDestination,
                                isSuccess: true
                            )
                            
                            reclaimedBytes += item.size
                            reclaimedFiles += max(1, item.fileCount)
                            catReclaimedForType += item.size
                        } catch {
                            AppLogger.cleanup.error("Error cleaning \(item.path.path): \(error.localizedDescription)")
                            logManager.log(
                                sourceModule: "System Junk",
                                path: item.path.path,
                                sizeBytes: item.size,
                                destination: intendedDestination,
                                isSuccess: false,
                                errorMessage: error.localizedDescription
                            )
                            errorsCount += 1
                            remainingItems.append(item)
                        }
                    }
                }
                
                category.items = remainingItems
                updatedCategories.append(category)
                if catReclaimedForType > 0 {
                    categoryReclaimed[categoryType] = catReclaimedForType
                }
            }
            
            return (
                updatedCategories: updatedCategories,
                reclaimedBytes: reclaimedBytes,
                reclaimedFiles: reclaimedFiles,
                errorsCount: errorsCount,
                categoryReclaimed: categoryReclaimed,
                dryRunTargets: dryRunTargets
            )
        }.value
        
        for target in outcome.dryRunTargets {
            DryRunManager.shared.logSimulation(action: "Trash Junk Item", target: target)
        }
        
        self.categories = outcome.updatedCategories
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: outcome.reclaimedBytes,
            reclaimedFilesCount: outcome.reclaimedFiles,
            errorsCount: outcome.errorsCount,
            duration: elapsed,
            cleanedCategorySizes: outcome.categoryReclaimed,
            isDryRun: isDryRun
        )
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showReclaimedAnimation = true
        self.currentScanningStep = isDryRun ?
            "Dry-Run complete: Simulated \(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)) across \(outcome.reclaimedFiles) items." :
            "Clean completed: Safely moved \(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)) to Trash."
        
        // Refresh system storage model as well
        StorageModel.shared.refresh()
    }
}
