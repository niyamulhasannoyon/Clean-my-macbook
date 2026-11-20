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
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, 0)
        }
        
        if !isDir.boolValue {
            if let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) {
                let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                return (sz, 1)
            }
            return (0, 1)
        }
        
        var totalBytes: Int64 = 0
        var totalFiles: Int = 0
        
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return (0, 0)
        }
        
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: resourceKeys) {
                if vals.isRegularFile == true {
                    totalFiles += 1
                    let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                    totalBytes += sz
                }
            }
        }
        
        return (totalBytes, totalFiles)
    }
    
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
    public static func scanLogs(home: URL, fm: FileManager) async -> [JunkItem] {
        var items: [JunkItem] = []
        
        // User Logs
        let userLogsURL = home.appendingPathComponent("Library/Logs")
        if fm.fileExists(atPath: userLogsURL.path) {
            let (size, count) = calculateSizeFast(of: userLogsURL, fm: fm)
            if size > 0 {
                items.append(JunkItem(
                    category: .systemLogs,
                    name: "User Diagnostic Logs",
                    path: userLogsURL,
                    size: size,
                    fileCount: count,
                    isSelected: true,
                    details: "~/Library/Logs",
                    icon: "doc.text.magnifyingglass"
                ))
            }
        }
        
        // System Logs
        let systemLogsURL = URL(fileURLWithPath: "/Library/Logs")
        if fm.fileExists(atPath: systemLogsURL.path) {
            let (size, count) = calculateSizeFast(of: systemLogsURL, fm: fm)
            if size > 0 {
                items.append(JunkItem(
                    category: .systemLogs,
                    name: "System Daemon & Diagnostic Logs",
                    path: systemLogsURL,
                    size: size,
                    fileCount: count,
                    isSelected: true,
                    details: "/Library/Logs",
                    icon: "gearshape.2.fill"
                ))
            }
        }
        
        return items
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
        let browserConfigs: [(name: String, paths: [URL], icon: String)] = [
            (
                "Safari Cache",
                [
                    home.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Caches"),
                    home.appendingPathComponent("Library/Caches/com.apple.Safari")
                ],
                "safari.fill"
            ),
            (
                "Google Chrome Cache",
                [
                    home.appendingPathComponent("Library/Caches/Google/Chrome"),
                    home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
                    home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Code Cache")
                ],
                "globe"
            ),
            (
                "Mozilla Firefox Cache",
                [
                    home.appendingPathComponent("Library/Caches/Firefox"),
                    home.appendingPathComponent("Library/Caches/Mozilla/Firefox")
                ],
                "flame.fill"
            ),
            (
                "Microsoft Edge Cache",
                [
                    home.appendingPathComponent("Library/Caches/Microsoft Edge"),
                    home.appendingPathComponent("Library/Application Support/Microsoft Edge/Default/Cache")
                ],
                "globe.europe.africa.fill"
            ),
            (
                "Brave Browser Cache",
                [
                    home.appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser"),
                    home.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache")
                ],
                "shield.fill"
            ),
            (
                "Arc Browser Cache",
                [
                    home.appendingPathComponent("Library/Caches/company.thebrowser.Browser")
                ],
                "circle.grid.2x2.fill"
            )
        ]
        
        return await withTaskGroup(of: JunkItem?.self) { group in
            for browser in browserConfigs {
                group.addTask {
                    var totalSize: Int64 = 0
                    var totalCount: Int = 0
                    var validPath: URL? = nil
                    
                    for path in browser.paths {
                        if fm.fileExists(atPath: path.path) {
                            validPath = validPath ?? path
                            let (size, count) = calculateSizeFast(of: path, fm: fm)
                            totalSize += size
                            totalCount += count
                        }
                    }
                    
                    guard let primaryPath = validPath, totalSize > 10 * 1024 else { return nil }
                    
                    return JunkItem(
                        category: .browserCaches,
                        name: browser.name,
                        path: primaryPath,
                        size: totalSize,
                        fileCount: totalCount,
                        isSelected: true,
                        details: "Web cache, offline scripts, stylesheets, and temporary assets",
                        icon: browser.icon
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
    
    // MARK: 8. Unused Languages (.lproj) - Optional
    public static func scanUnusedLanguages(fm: FileManager) async -> [JunkItem] {
        let preferred = Set(Locale.preferredLanguages.map { String($0.prefix(2)).lowercased() } + ["en", "base"])
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        var foundItems: [JunkItem] = []
        
        for dir in appDirs {
            guard let apps = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for app in apps where app.pathExtension == "app" {
                let resURL = app.appendingPathComponent("Contents/Resources")
                guard let resources = try? fm.contentsOfDirectory(at: resURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                    continue
                }
                
                var appUnusedSize: Int64 = 0
                var appUnusedCount: Int = 0
                
                for item in resources where item.pathExtension == "lproj" {
                    let langName = item.deletingPathExtension().lastPathComponent.lowercased()
                    let langCode = String(langName.prefix(2))
                    if !preferred.contains(langCode) && !preferred.contains(langName) {
                        let (size, count) = calculateSizeFast(of: item, fm: fm)
                        appUnusedSize += size
                        appUnusedCount += count
                    }
                }
                
                if appUnusedSize > 500 * 1024 { // Only report apps with > 500KB language junk
                    foundItems.append(JunkItem(
                        category: .unusedLanguages,
                        name: "\(app.deletingPathExtension().lastPathComponent) Language Bundles",
                        path: resURL,
                        size: appUnusedSize,
                        fileCount: appUnusedCount,
                        isSelected: false, // Optional safety default
                        details: "\(appUnusedCount) unused localization files (.lproj)",
                        icon: "character.book.closed"
                    ))
                }
            }
        }
        
        return foundItems.sorted { $0.size > $1.size }
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
    @Published public var includeUnusedLanguages: Bool = false
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
    
    public init() {
        resetCategories()
    }
    
    public func resetCategories() {
        self.categories = JunkCategoryType.allCases.compactMap { type in
            if type == .unusedLanguages && !includeUnusedLanguages {
                return nil
            }
            return JunkCategory(id: type, items: [], isExpanded: false, isScanning: false)
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
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        currentScanningStep = "Preparing System Junk scan..."
        scanError = nil
        lastCleanResult = nil
        showReclaimedAnimation = false
        
        let startTime = Date()
        resetCategories()
        
        var targetCategories = JunkCategoryType.allCases
        if !includeUnusedLanguages {
            targetCategories.removeAll(where: { $0 == .unusedLanguages })
        }
        
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
            case .unusedLanguages:
                return await JunkScanEngine.scanUnusedLanguages(fm: fm)
            }
        }.value
    }
    
    // MARK: - Clean Action (Send to Trash)
    
    public func performClean() async {
        guard !isCleaning else { return }
        isCleaning = true
        currentScanningStep = "Moving selected junk to macOS Trash..."
        
        let startTime = Date()
        var reclaimedBytes: Int64 = 0
        var reclaimedFiles: Int = 0
        var errorsCount: Int = 0
        var categoryReclaimed: [JunkCategoryType: Int64] = [:]
        
        let fm = FileManager.default
        let homeTrashPath = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        
        for catIdx in categories.indices {
            let categoryType = categories[catIdx].id
            var catReclaimedForType: Int64 = 0
            
            var remainingItems: [JunkItem] = []
            
            for item in categories[catIdx].items {
                if item.isSelected {
                    do {
                        if item.path.path.hasPrefix(homeTrashPath) {
                            // Already in trash -> remove to empty trash item
                            try fm.removeItem(at: item.path)
                        } else {
                            // Move to macOS Trash safely!
                            try fm.trashItem(at: item.path, resultingItemURL: nil)
                        }
                        
                        reclaimedBytes += item.size
                        reclaimedFiles += max(1, item.fileCount)
                        catReclaimedForType += item.size
                    } catch {
                        print("Error trashing \(item.path.path): \(error.localizedDescription)")
                        errorsCount += 1
                        remainingItems.append(item)
                    }
                } else {
                    remainingItems.append(item)
                }
            }
            
            categories[catIdx].items = remainingItems
            if catReclaimedForType > 0 {
                categoryReclaimed[categoryType] = catReclaimedForType
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: reclaimedBytes,
            reclaimedFilesCount: reclaimedFiles,
            errorsCount: errorsCount,
            duration: elapsed,
            cleanedCategorySizes: categoryReclaimed
        )
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showReclaimedAnimation = true
        self.currentScanningStep = "Clean completed: Safely moved \(ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)) to Trash."
        
        // Refresh system storage model as well
        StorageModel.shared.refresh()
    }
}
