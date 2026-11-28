import Foundation
import SwiftUI
import AppKit

@MainActor
public class AppUninstallerScanner: ObservableObject {
    public static let shared = AppUninstallerScanner()
    
    // Published State
    @Published public var installedApps: [InstalledApp] = []
    @Published public var selectedAppId: UUID? = nil
    @Published public var orphanedGroups: [OrphanedAppGroup] = []
    
    @Published public var isScanning: Bool = false
    @Published public var isScanningLeftovers: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var statusMessage: String = "Ready to scan installed apps"
    
    @Published public var selectedTab: AppUninstallerTab = .installedApps
    @Published public var searchText: String = ""
    @Published public var sortOption: AppSortOption = .sizeDescending
    @Published public var showSystemApps: Bool = false
    
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var showCelebration: Bool = false
    @Published public var scanError: String? = nil
    
    private let homeURL: URL
    private let appDirectories: [URL]
    private let systemAppDirectories: [URL]
    private let deletionLogManager: DeletionLogManager
    
    public convenience init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.init(
            homeURL: home,
            appDirectories: [
                URL(fileURLWithPath: "/Applications"),
                home.appendingPathComponent("Applications")
            ]
        )
    }
    
    public init(
        homeURL: URL,
        appDirectories: [URL],
        systemAppDirectories: [URL] = [
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications")
        ],
        deletionLogManager: DeletionLogManager = .shared
    ) {
        self.homeURL = homeURL
        self.appDirectories = appDirectories
        self.systemAppDirectories = systemAppDirectories
        self.deletionLogManager = deletionLogManager
    }
    
    // MARK: - Selected App Helper
    public var selectedApp: InstalledApp? {
        guard let selectedAppId = selectedAppId else {
            return filteredApps.first
        }
        return installedApps.first(where: { $0.id == selectedAppId })
    }
    
    // MARK: - Filtered & Sorted Apps
    public var filteredApps: [InstalledApp] {
        var result = installedApps
        
        if !showSystemApps {
            result = result.filter { !$0.isSystemApp }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query) ||
                $0.bundleURL.path.lowercased().contains(query)
            }
        }
        
        switch sortOption {
        case .sizeDescending:
            result.sort { $0.totalSize > $1.totalSize }
        case .sizeAscending:
            result.sort { $0.totalSize < $1.totalSize }
        case .nameAscending:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .leftoversDescending:
            result.sort { $0.leftoversSize > $1.leftoversSize }
        }
        
        return result
    }
    
    // MARK: - Orphaned Groups Filtered
    public var filteredOrphanedGroups: [OrphanedAppGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return orphanedGroups
        }
        return orphanedGroups.filter { group in
            group.name.lowercased().contains(query) ||
            (group.bundleIdentifier?.lowercased().contains(query) ?? false) ||
            group.items.contains(where: { $0.displayPath.lowercased().contains(query) })
        }
    }
    
    public var totalInstalledAppsCount: Int {
        installedApps.filter { !$0.isSystemApp }.count
    }
    
    public var totalReclaimableAppSpace: Int64 {
        installedApps.filter { !$0.isSystemApp }.reduce(0) { $0 + $1.totalSize }
    }
    
    public var formattedTotalReclaimableSpace: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableAppSpace, countStyle: .file)
    }
    
    public var totalOrphanedSize: Int64 {
        orphanedGroups.reduce(0) { $0 + $1.totalSize }
    }
    
    public var formattedTotalOrphanedSize: String {
        ByteCountFormatter.string(fromByteCount: totalOrphanedSize, countStyle: .file)
    }
    
    public var selectedOrphanedSize: Int64 {
        orphanedGroups.reduce(0) { $0 + $1.selectedSize }
    }
    
    public var formattedSelectedOrphanedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedOrphanedSize, countStyle: .file)
    }
    
    public var hasSelectedOrphans: Bool {
        orphanedGroups.contains { $0.items.contains { $0.isSelected } }
    }
    
    // MARK: - Full Scan Action
    public func scanAll() async {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        scanProgress = 0.0
        statusMessage = "Discovering installed applications in /Applications and ~/Applications..."
        
        let appDirs = self.appDirectories
        
        // 1. Gather all app bundle URLs off MainActor
        let foundAppURLs: [URL] = await Task.detached(priority: .userInitiated) {
            Self.discoverAppBundleURLs(in: appDirs)
        }.value
        
        let totalCount = max(1, foundAppURLs.count)
        statusMessage = "Analyzing \(foundAppURLs.count) applications and measuring bundle sizes..."
        
        // 2. Parse app metadata and sizes concurrently off MainActor
        let parsedApps: [InstalledApp] = await Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: InstalledApp?.self) { group in
                for appURL in foundAppURLs {
                    group.addTask {
                        let bundle = Bundle(url: appURL)
                        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                            ?? appURL.deletingPathExtension().lastPathComponent
                        let bundleId = bundle?.bundleIdentifier ?? ""
                        let version = (bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
                            ?? "1.0"
                        
                        let isSystem = appURL.path.hasPrefix("/System") ||
                            (bundleId.hasPrefix("com.apple.") && !appURL.path.contains("/Users/"))
                        
                        let (size, _) = JunkScanEngine.calculateSizeFast(of: appURL)
                        
                        return InstalledApp(
                            name: name,
                            bundleIdentifier: bundleId,
                            version: version,
                            bundleURL: appURL,
                            appSize: size,
                            isSystemApp: isSystem,
                            leftovers: []
                        )
                    }
                }
                
                var collected: [InstalledApp] = []
                for await item in group {
                    if let app = item {
                        collected.append(app)
                    }
                }
                return collected
            }
        }.value
        
        // Update preliminary app list
        let sortedPreliminary = parsedApps.sorted { $0.totalSize > $1.totalSize }
        let previousBundleURL = self.installedApps.first(where: { $0.id == self.selectedAppId })?.bundleURL
        self.installedApps = sortedPreliminary
        if let prevURL = previousBundleURL,
           let matched = sortedPreliminary.first(where: { $0.bundleURL == prevURL }) {
            self.selectedAppId = matched.id
        } else if self.selectedAppId == nil || !sortedPreliminary.contains(where: { $0.id == self.selectedAppId }) {
            self.selectedAppId = sortedPreliminary.first(where: { !$0.isSystemApp })?.id
        }
        
        // 3. Scan leftovers for all installed applications (off MainActor)
        statusMessage = "Deep scanning leftover files across ~/Library directories..."
        isScanningLeftovers = true
        
        var appsWithLeftovers: [InstalledApp] = []
        for (index, app) in sortedPreliminary.enumerated() {
            let progress = Double(index) / Double(totalCount)
            self.scanProgress = progress
            self.statusMessage = "Scanning leftovers for \(app.name)..."
            
            let leftovers = await self.findLeftovers(for: app)
            var updatedApp = app
            updatedApp.leftovers = leftovers
            appsWithLeftovers.append(updatedApp)
        }
        
        let sortedFinal = appsWithLeftovers.sorted { $0.totalSize > $1.totalSize }
        self.installedApps = sortedFinal
        self.isScanningLeftovers = false
        
        // 4. Scan for Orphaned Leftovers (off MainActor)
        self.statusMessage = "Scanning for orphaned leftovers from uninstalled apps..."
        let orphans = await self.scanOrphanedLeftovers(knownApps: sortedFinal)
        self.orphanedGroups = orphans.sorted { $0.totalSize > $1.totalSize }
        
        self.scanProgress = 1.0
        self.statusMessage = "Scan complete: Found \(installedApps.count) apps and \(orphanedGroups.count) orphaned residual groups."
        self.isScanning = false
    }
    
    // MARK: - Refresh Leftovers for Specific App
    public func refreshLeftovers(for app: InstalledApp) async {
        guard !isScanningLeftovers && !isScanning && !isCleaning else { return }
        isScanningLeftovers = true
        let leftovers = await findLeftovers(for: app)
        if let idx = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps[idx].leftovers = leftovers
        }
        isScanningLeftovers = false
    }
    
    // MARK: - App Bundle Discovery (Off MainActor)
    nonisolated private static func discoverAppBundleURLs(in appDirectories: [URL]) -> [URL] {
        let fm = FileManager.default
        var foundAppURLs: [URL] = []
        for dir in appDirectories {
            guard fm.fileExists(atPath: dir.path) else { continue }
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for url in contents {
                    if url.pathExtension.lowercased() == "app" {
                        foundAppURLs.append(url)
                    } else if url.hasDirectoryPath {
                        // Check subdirectories (e.g. /Applications/Utilities)
                        if let subContents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                            for subURL in subContents where subURL.pathExtension.lowercased() == "app" {
                                foundAppURLs.append(subURL)
                            }
                        }
                    }
                }
            }
        }
        return foundAppURLs
    }
    
    // MARK: - Leftover Finder Engine
    public func findLeftovers(for app: InstalledApp) async -> [AppLeftoverItem] {
        let home = self.homeURL
        return await Task.detached(priority: .userInitiated) {
            Self.findLeftoversSync(for: app, home: home)
        }.value
    }
    
    nonisolated private static func findLeftoversSync(for app: InstalledApp, home: URL) -> [AppLeftoverItem] {
        let appName = app.name
        let bundleId = app.bundleIdentifier
        let fm = FileManager.default
        
        var items: [AppLeftoverItem] = []
        
        // Define candidate directories to check
        let locations: [(category: LeftoverCategory, url: URL)] = [
            (.appSupport, home.appendingPathComponent("Library/Application Support")),
            (.caches, home.appendingPathComponent("Library/Caches")),
            (.preferences, home.appendingPathComponent("Library/Preferences")),
            (.containers, home.appendingPathComponent("Library/Containers")),
            (.logs, home.appendingPathComponent("Library/Logs")),
            (.launchAgents, home.appendingPathComponent("Library/LaunchAgents")),
            (.savedState, home.appendingPathComponent("Library/Saved Application State"))
        ]
        
        for loc in locations {
            guard fm.fileExists(atPath: loc.url.path) else { continue }
            guard let contents = try? fm.contentsOfDirectory(at: loc.url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for fileURL in contents {
                let filename = fileURL.lastPathComponent
                
                if matchesApp(filename: filename, fileURL: fileURL, appName: appName, bundleId: bundleId, category: loc.category) {
                    let (size, count) = JunkScanEngine.calculateSizeFast(of: fileURL, fm: fm)
                    guard size > 0 || loc.category == .preferences || loc.category == .launchAgents else { continue }
                    
                    let displayPath = fileURL.path.replacingOccurrences(of: home.path, with: "~")
                    let item = AppLeftoverItem(
                        category: loc.category,
                        name: filename,
                        displayPath: displayPath,
                        url: fileURL,
                        size: size,
                        fileCount: count,
                        isSelected: true
                    )
                    items.append(item)
                }
            }
        }
        
        // Also check ~/Library/Preferences/ByHost for bundleId
        let byHostURL = home.appendingPathComponent("Library/Preferences/ByHost")
        if fm.fileExists(atPath: byHostURL.path), !bundleId.isEmpty {
            if let hostFiles = try? fm.contentsOfDirectory(at: byHostURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for hFile in hostFiles {
                    if hFile.lastPathComponent.lowercased().hasPrefix(bundleId.lowercased()) {
                        let (size, count) = JunkScanEngine.calculateSizeFast(of: hFile, fm: fm)
                        let displayPath = hFile.path.replacingOccurrences(of: home.path, with: "~")
                        items.append(AppLeftoverItem(
                            category: .preferences,
                            name: hFile.lastPathComponent,
                            displayPath: displayPath,
                            url: hFile,
                            size: size,
                            fileCount: count,
                            isSelected: true
                        ))
                    }
                }
            }
        }
        
        // Also check ~/Library/Group Containers for matching bundle identifier
        let groupContainersURL = home.appendingPathComponent("Library/Group Containers")
        if fm.fileExists(atPath: groupContainersURL.path), !bundleId.isEmpty {
            if let groupDirs = try? fm.contentsOfDirectory(at: groupContainersURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for gDir in groupDirs {
                    let gName = gDir.lastPathComponent.lowercased()
                    if gName.contains(bundleId.lowercased()) {
                        let (size, count) = JunkScanEngine.calculateSizeFast(of: gDir, fm: fm)
                        if size > 0 {
                            let displayPath = gDir.path.replacingOccurrences(of: home.path, with: "~")
                            items.append(AppLeftoverItem(
                                category: .containers,
                                name: gDir.lastPathComponent,
                                displayPath: displayPath,
                                url: gDir,
                                size: size,
                                fileCount: count,
                                isSelected: true
                            ))
                        }
                    }
                }
            }
        }
        
        // Also check ~/Library/Application Support vendor subdirectories (e.g. Google/Chrome, BraveSoftware/Brave-Browser)
        let appSupportURL = home.appendingPathComponent("Library/Application Support")
        if let vendorDirs = try? fm.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for vDir in vendorDirs {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: vDir.path, isDirectory: &isDir), isDir.boolValue {
                    // Check subfolders inside this vendor directory
                    if let subDirs = try? fm.contentsOfDirectory(at: vDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                        for subDir in subDirs {
                            let subName = subDir.lastPathComponent
                            if matchesApp(filename: subName, fileURL: subDir, appName: appName, bundleId: bundleId, category: .appSupport) {
                                if !items.contains(where: { $0.url.path == subDir.path }) {
                                    let (size, count) = JunkScanEngine.calculateSizeFast(of: subDir, fm: fm)
                                    let displayPath = subDir.path.replacingOccurrences(of: home.path, with: "~")
                                    items.append(AppLeftoverItem(
                                        category: .appSupport,
                                        name: "\(vDir.lastPathComponent)/\(subName)",
                                        displayPath: displayPath,
                                        url: subDir,
                                        size: size,
                                        fileCount: count,
                                        isSelected: true
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - Matching Rules
    nonisolated public static func matchesApp(
        filename: String,
        fileURL: URL,
        appName: String,
        bundleId: String,
        category: LeftoverCategory
    ) -> Bool {
        let fLower = filename.lowercased()
        let bLower = bundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let nameClean = appName.replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nLower = nameClean.lowercased()
        
        // 1. Bundle ID Exact or Prefix/Extension Match
        if !bLower.isEmpty {
            if fLower == bLower { return true }
            if fLower.hasPrefix(bLower + ".") || fLower.hasPrefix(bLower + "-") || fLower.hasPrefix(bLower + "_") {
                return true
            }
            if category == .preferences && (fLower == "\(bLower).plist" || fLower.hasPrefix("\(bLower).")) {
                return true
            }
            if category == .savedState && fLower == "\(bLower).savedstate" {
                return true
            }
        }
        
        // 2. App Name Match
        // Guard against overly short or ambiguous strings
        if nLower.count >= 3 && !isGenericSystemWord(nLower) {
            if fLower == nLower { return true }
            if fLower.hasPrefix(nLower + ".") || fLower.hasPrefix(nLower + " ") || fLower.hasPrefix(nLower + "-") {
                return true
            }
            if category == .preferences && fLower == "\(nLower).plist" {
                return true
            }
            if category == .savedState && fLower == "\(nLower).savedstate" {
                return true
            }
            
            // Normalized alphanumeric check (e.g. "logioptionsplus" matches "Logi Options+", "claude3p" starts with "claude").
            // Never test nAlpha.hasPrefix(fAlpha), which lets short vendor names like "Google" or "Go" match "Google Chrome".
            let fAlpha = fLower.filter { $0.isLetter || $0.isNumber }
            if matchesNormalizedAlphanumeric(filenameAlpha: fAlpha, appNameLower: nLower) {
                return true
            }
        }
        
        // 3. LaunchAgents check
        if category == .launchAgents {
            if fLower.hasSuffix(".plist") {
                if !bLower.isEmpty && fLower.contains(bLower) { return true }
                if nLower.count >= 4 && fLower.contains(nLower) { return true }
                
                // Read plist content to check if it points to the app binary or bundle id
                if let data = try? Data(contentsOf: fileURL),
                   let content = String(data: data, encoding: .utf8) {
                    if !bLower.isEmpty && content.range(of: bLower, options: .caseInsensitive) != nil { return true }
                    if !appName.isEmpty && content.contains(appName) { return true }
                }
            }
        }
        
        return false
    }
    
    nonisolated private static func matchesNormalizedAlphanumeric(filenameAlpha fAlpha: String, appNameLower: String) -> Bool {
        let nAlpha = appNameLower.filter { $0.isLetter || $0.isNumber }
        return fAlpha.count >= 5 && nAlpha.count >= 5 && (fAlpha == nAlpha || fAlpha.hasPrefix(nAlpha))
    }
    
    nonisolated private static func isGenericSystemWord(_ word: String) -> Bool {
        let genericWords: Set<String> = [
            "apple", "system", "library", "mac", "macos", "data", "cache", "log", "logs",
            "file", "files", "support", "container", "containers", "state", "saved", "config"
        ]
        return genericWords.contains(word)
    }
    
    // MARK: - Orphaned Leftovers Scanner Engine
    public func scanOrphanedLeftovers(knownApps: [InstalledApp]) async -> [OrphanedAppGroup] {
        let home = self.homeURL
        let systemAppDirs = self.systemAppDirectories
        return await Task.detached(priority: .userInitiated) {
            Self.scanOrphanedLeftoversSync(knownApps: knownApps, home: home, systemAppDirectories: systemAppDirs)
        }.value
    }
    
    nonisolated private static func scanOrphanedLeftoversSync(
        knownApps: [InstalledApp],
        home: URL,
        systemAppDirectories: [URL]
    ) -> [OrphanedAppGroup] {
        let fm = FileManager.default
        
        // Build set of all installed bundle IDs and app names across all system locations
        var installedBids: Set<String> = []
        var installedNames: Set<String> = []
        
        for app in knownApps {
            if !app.bundleIdentifier.isEmpty {
                installedBids.insert(app.bundleIdentifier.lowercased())
            }
            let clean = app.name.replacingOccurrences(of: ".app", with: "").lowercased()
            if clean.count >= 3 {
                installedNames.insert(clean)
            }
        }
        
        // Also add macOS System Applications to prevent false positives
        for u in systemAppDirectories {
            if let files = try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for f in files where f.pathExtension.lowercased() == "app" {
                    let b = Bundle(url: f)
                    if let bid = b?.bundleIdentifier {
                        installedBids.insert(bid.lowercased())
                    }
                    installedNames.insert(f.deletingPathExtension().lastPathComponent.lowercased())
                }
            }
        }
        
        let candidateLocations: [(category: LeftoverCategory, url: URL)] = [
            (.appSupport, home.appendingPathComponent("Library/Application Support")),
            (.caches, home.appendingPathComponent("Library/Caches")),
            (.containers, home.appendingPathComponent("Library/Containers")),
            (.savedState, home.appendingPathComponent("Library/Saved Application State")),
            (.launchAgents, home.appendingPathComponent("Library/LaunchAgents")),
            (.preferences, home.appendingPathComponent("Library/Preferences")),
            (.logs, home.appendingPathComponent("Library/Logs"))
        ]
        
        var orphanCandidates: [(category: LeftoverCategory, name: String, url: URL, groupKey: String)] = []
        
        for loc in candidateLocations {
            guard fm.fileExists(atPath: loc.url.path) else { continue }
            guard let contents = try? fm.contentsOfDirectory(at: loc.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for fileURL in contents {
                let filename = fileURL.lastPathComponent
                if filename.hasPrefix(".") { continue }
                
                // Exclude system Apple files and services
                if isAppleSystemResidual(filename: filename) { continue }
                
                // Exclude if belongs to any installed app
                if belongsToInstalledApp(filename: filename, installedBids: installedBids, installedNames: installedNames) {
                    continue
                }
                
                // Infer a friendly group name
                let groupKey = inferAppGroupKey(from: filename)
                guard !groupKey.isEmpty, !isAppleSystemResidual(filename: groupKey) else { continue }
                
                orphanCandidates.append((category: loc.category, name: filename, url: fileURL, groupKey: groupKey))
            }
        }
        
        // Measure sizes and group by inferred app name (already off MainActor in Task.detached)
        var groupedItems: [String: [AppLeftoverItem]] = [:]
        
        for cand in orphanCandidates {
            let (size, count) = JunkScanEngine.calculateSizeFast(of: cand.url, fm: fm)
            guard size > 0 || cand.category == .preferences || cand.category == .launchAgents else { continue }
            
            let displayPath = cand.url.path.replacingOccurrences(of: home.path, with: "~")
            let item = AppLeftoverItem(
                category: cand.category,
                name: cand.name,
                displayPath: displayPath,
                url: cand.url,
                size: size,
                fileCount: count,
                isSelected: false
            )
            
            groupedItems[cand.groupKey, default: []].append(item)
        }
        
        var groups: [OrphanedAppGroup] = []
        for (groupName, items) in groupedItems {
            guard !items.isEmpty else { continue }
            let totalSz = items.reduce(0) { $0 + $1.size }
            // Filter out empty or negligible orphaned groups (< 10 KB unless it's LaunchAgent)
            guard totalSz > 10 * 1024 || items.contains(where: { $0.category == .launchAgents }) else { continue }
            
            let group = OrphanedAppGroup(
                name: groupName,
                bundleIdentifier: items.first(where: { $0.name.contains(".") })?.name,
                items: items.sorted { $0.size > $1.size },
                isSelected: false
            )
            groups.append(group)
        }
        
        return groups
    }
    
    nonisolated private static func isAppleSystemResidual(filename: String) -> Bool {
        let lower = filename.lowercased()
        if lower.hasPrefix("com.apple.") || lower.hasPrefix("apple") || lower.hasPrefix("byhost") {
            return true
        }
        
        let systemKeywords: Set<String> = [
            "icloud", "cloudkit", "quicklook", "coresimulator", "system", "preferences",
            "syncservices", "addressbook", "callhistorytransactions", "callhistorydb", "diskimages",
            "familykit", "homeenergyd", "locationaccessstored", "networkserviceproxy", "sesstorage",
            "music", "tv", "podcasts", "books", "photos", "shortcuts", "siri", "knowledge", "biome",
            "accounts", "passes", "messages", "facetime", "feedbackassistant", "weather", "stocks",
            "news", "home", "fontcollections", "automator", "colorsync", "voicememos", "reminders",
            "notes", "keychains", "identityservices", "security", "safari", "mail", "calendar",
            "finder", "preview", "textedit", "terminal", "console", "activity monitor", "disk utility",
            "keychain access", "system information", "voiceover", "chess", "stickies", "grapher",
            "digital color meter", "audio midi setup", "colorsync utility", "bluetooth file exchange",
            "migration assistant", "boot camp assistant", "screen sharing", "airport utility", "app store",
            "system settings", "system preferences", "dock", "software update", "controlcenter",
            "notificationcenter", "spotlight", "metadata", "installer", "crashreporter", "crashreports",
            "diagnosticreports", "diagnostics", "spindump", "containermanager", "default.store",
            "default.store-wal", "ilifemediabrowser", "quicktime", "spaces", "windowserver",
            "animoji", "appexit", "categories", "clouddocs", "differentialprivacy", "fileprovider",
            "intelligenceflow", "imagent", "passd", "translation", "videos", "tips", "gamecontroller",
            "screentime", "contacts", "calendars", "systemmigration", "com.apple"
        ]
        
        return systemKeywords.contains(lower)
    }
    
    nonisolated public static func belongsToInstalledApp(
        filename: String,
        installedBids: Set<String>,
        installedNames: Set<String>
    ) -> Bool {
        let lower = filename.lowercased()
        
        for bid in installedBids {
            if lower == bid || lower.hasPrefix(bid + ".") || lower.hasPrefix(bid + "-") || lower.contains(bid) {
                return true
            }
        }
        
        for name in installedNames {
            if lower == name || lower.hasPrefix(name + ".") || lower.hasPrefix(name + "-") || lower.hasPrefix(name + " ") {
                return true
            }
        }
        
        // Alphanumeric normalized check (e.g. logioptionsplus matches Logi Options+).
        // Never test nAlpha.hasPrefix(fAlpha), which lets short vendor names like "Google" or "Go" match "Google Chrome".
        let fAlpha = lower.filter { $0.isLetter || $0.isNumber }
        if fAlpha.count >= 5 && installedNames.contains(where: { matchesNormalizedAlphanumeric(filenameAlpha: fAlpha, appNameLower: $0) }) {
            return true
        }
        
        // Also check if it's a known vendor folder that has installed software
        if lower == "google" && (installedNames.contains("google chrome") || installedNames.contains("google drive") || installedNames.contains("chrome")) {
            return true
        }
        if lower == "microsoft" && (installedNames.contains("code") || installedNames.contains("visual studio code") || installedNames.contains("teams")) {
            return true
        }
        if lower == "bravesoftware" && (installedNames.contains("brave browser") || installedNames.contains("brave")) {
            return true
        }
        
        return false
    }
    
    nonisolated private static func inferAppGroupKey(from filename: String) -> String {
        var clean = filename
        if clean.hasSuffix(".savedState") {
            clean = clean.replacingOccurrences(of: ".savedState", with: "")
        }
        if clean.hasSuffix(".plist") {
            clean = clean.replacingOccurrences(of: ".plist", with: "")
        }
        
        if clean.contains(".") {
            let parts = clean.split(separator: ".")
            if parts.count >= 2 {
                let candidate = String(parts.last!)
                if candidate.count > 2 && !candidate.lowercased().contains("shipit") && !candidate.lowercased().contains("helper") {
                    return JunkScanEngine.friendlyAppName(from: candidate)
                }
            }
        }
        
        return JunkScanEngine.friendlyAppName(from: clean)
    }
    
    // MARK: - Trash Selected App & Leftovers (Safe Trashing)
    public func trashApp(app: InstalledApp, trashBundle: Bool = true) async -> Bool {
        await trashApp(app: app, trashBundle: trashBundle, trashHandler: nil)
    }
    
    public func trashApp(
        app: InstalledApp,
        trashBundle: Bool = true,
        trashHandler: (@Sendable (URL) throws -> Void)?
    ) async -> Bool {
        guard !isCleaning else { return false }
        isCleaning = true
        scanError = nil
        let isDryRun = DryRunManager.shared.isEnabled
        statusMessage = isDryRun ?
            "Simulating uninstallation of \(app.name)..." :
            "Safely moving \(app.name) and selected leftovers to macOS Trash..."
        
        let startTime = Date()
        let home = self.homeURL
        let logManager = self.deletionLogManager
        
        // 1. Terminate running instance if open (skip if dry run; AppKit must run on MainActor)
        if !isDryRun && !app.bundleIdentifier.isEmpty {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
            for rApp in runningApps {
                rApp.terminate()
            }
        }
        
        // 2 & 3. Trash leftovers and app bundle off MainActor
        let outcome = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let performTrash: @Sendable (URL) throws -> Void = trashHandler ?? { url in
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
            
            var reclaimedBytes: Int64 = 0
            var reclaimedFiles: Int = 0
            var errorsCount: Int = 0
            var remainingLeftovers: [AppLeftoverItem] = []
            var dryRunTargets: [(action: String, path: String)] = []
            var firstLeftoverError: String? = nil
            
            // Trash Selected Leftover Files
            for item in app.leftovers {
                guard item.isSelected else {
                    remainingLeftovers.append(item)
                    continue
                }
                
                if let protErr = PathProtection.evaluatePath(url: item.url, homeDirectory: home) {
                    AppLogger.security.warning("Skipping protected leftover: \(item.url.path) - \(protErr.localizedDescription)")
                    logManager.log(
                        sourceModule: "App Uninstaller",
                        path: item.url.path,
                        sizeBytes: item.size,
                        destination: .trash,
                        isSuccess: false,
                        errorMessage: protErr.localizedDescription
                    )
                    errorsCount += 1
                    if firstLeftoverError == nil { firstLeftoverError = protErr.localizedDescription }
                    remainingLeftovers.append(item)
                    continue
                }
                
                if isDryRun {
                    dryRunTargets.append(("Trash Leftover", item.url.path))
                    logManager.log(
                        sourceModule: "App Uninstaller",
                        path: item.url.path,
                        sizeBytes: item.size,
                        destination: .simulated,
                        isSuccess: true
                    )
                    reclaimedBytes += item.size
                    reclaimedFiles += max(1, item.fileCount)
                } else {
                    do {
                        if fm.fileExists(atPath: item.url.path) {
                            try performTrash(item.url)
                            logManager.log(
                                sourceModule: "App Uninstaller",
                                path: item.url.path,
                                sizeBytes: item.size,
                                destination: .trash,
                                isSuccess: true
                            )
                            reclaimedBytes += item.size
                            reclaimedFiles += max(1, item.fileCount)
                        }
                    } catch {
                        AppLogger.cleanup.error("Error moving leftover to Trash: \(item.url.path) - \(error.localizedDescription)")
                        logManager.log(
                            sourceModule: "App Uninstaller",
                            path: item.url.path,
                            sizeBytes: item.size,
                            destination: .trash,
                            isSuccess: false,
                            errorMessage: error.localizedDescription
                        )
                        errorsCount += 1
                        if firstLeftoverError == nil { firstLeftoverError = error.localizedDescription }
                        remainingLeftovers.append(item)
                    }
                }
            }
            
            // Trash Application Bundle
            var bundleTrashSucceeded = false
            var bundleErrorMessage: String? = nil
            
            if trashBundle {
                if app.isSystemApp {
                    errorsCount += 1
                    let msg = "System application \(app.name) is protected and cannot be uninstalled."
                    bundleErrorMessage = msg
                    logManager.log(
                        sourceModule: "App Uninstaller",
                        path: app.bundleURL.path,
                        sizeBytes: app.appSize,
                        destination: .trash,
                        isSuccess: false,
                        errorMessage: msg
                    )
                } else if let protErr = PathProtection.evaluatePath(url: app.bundleURL, homeDirectory: home) {
                    AppLogger.security.warning("Cannot delete protected application: \(app.bundleURL.path) - \(protErr.localizedDescription)")
                    logManager.log(
                        sourceModule: "App Uninstaller",
                        path: app.bundleURL.path,
                        sizeBytes: app.appSize,
                        destination: .trash,
                        isSuccess: false,
                        errorMessage: protErr.localizedDescription
                    )
                    errorsCount += 1
                    bundleErrorMessage = protErr.localizedDescription
                } else if isDryRun {
                    dryRunTargets.append(("Trash App Bundle", app.bundleURL.path))
                    logManager.log(
                        sourceModule: "App Uninstaller",
                        path: app.bundleURL.path,
                        sizeBytes: app.appSize,
                        destination: .simulated,
                        isSuccess: true
                    )
                    reclaimedBytes += app.appSize
                    reclaimedFiles += 1
                    bundleTrashSucceeded = true
                } else {
                    do {
                        if fm.fileExists(atPath: app.bundleURL.path) {
                            try performTrash(app.bundleURL)
                            logManager.log(
                                sourceModule: "App Uninstaller",
                                path: app.bundleURL.path,
                                sizeBytes: app.appSize,
                                destination: .trash,
                                isSuccess: true
                            )
                            reclaimedBytes += app.appSize
                            reclaimedFiles += 1
                        }
                        bundleTrashSucceeded = true
                    } catch {
                        AppLogger.cleanup.error("Error moving app bundle to Trash: \(app.bundleURL.path) - \(error.localizedDescription)")
                        logManager.log(
                            sourceModule: "App Uninstaller",
                            path: app.bundleURL.path,
                            sizeBytes: app.appSize,
                            destination: .trash,
                            isSuccess: false,
                            errorMessage: error.localizedDescription
                        )
                        errorsCount += 1
                        bundleErrorMessage = error.localizedDescription
                    }
                }
            }
            
            return (
                reclaimedBytes: reclaimedBytes,
                reclaimedFiles: reclaimedFiles,
                errorsCount: errorsCount,
                remainingLeftovers: remainingLeftovers,
                dryRunTargets: dryRunTargets,
                bundleTrashSucceeded: bundleTrashSucceeded,
                bundleErrorMessage: bundleErrorMessage,
                firstLeftoverError: firstLeftoverError
            )
        }.value
        
        for target in outcome.dryRunTargets {
            DryRunManager.shared.logSimulation(action: target.action, target: target.path)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: outcome.reclaimedBytes,
            reclaimedFilesCount: outcome.reclaimedFiles,
            errorsCount: outcome.errorsCount,
            duration: elapsed,
            cleanedCategorySizes: [:],
            isDryRun: isDryRun
        )
        
        let shouldRemoveApp = trashBundle && (outcome.bundleTrashSucceeded || (isDryRun && !app.isSystemApp && outcome.bundleErrorMessage == nil))
        
        if shouldRemoveApp {
            self.installedApps.removeAll { $0.id == app.id }
            if self.selectedAppId == app.id {
                self.selectedAppId = self.filteredApps.first?.id
            }
        } else if let idx = self.installedApps.firstIndex(where: { $0.id == app.id }) {
            self.installedApps[idx].leftovers = outcome.remainingLeftovers
        }
        
        if let bundleErr = outcome.bundleErrorMessage {
            self.scanError = "Could not move \(app.name) to Trash: \(bundleErr)"
        } else if outcome.errorsCount > 0 {
            self.scanError = outcome.firstLeftoverError ?? "Could not move \(outcome.errorsCount) leftover item(s) to Trash."
        }
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showCelebration = outcome.errorsCount == 0 && outcome.reclaimedFiles > 0 && (!trashBundle || shouldRemoveApp)
        
        if let bundleErr = outcome.bundleErrorMessage {
            self.statusMessage = "Failed to uninstall \(app.name): \(bundleErr)"
        } else if isDryRun {
            self.statusMessage = "Dry-Run: Simulated uninstallation of \(app.name) (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)))."
        } else if trashBundle {
            self.statusMessage = "Uninstalled \(app.name). Reclaimed \(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)) moved to macOS Trash."
        } else {
            self.statusMessage = "Cleaned selected leftovers for \(app.name) (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)))."
        }
        
        // Refresh StorageModel
        StorageModel.shared.refresh()
        return outcome.errorsCount == 0
    }
    
    // MARK: - Trash Selected Orphaned Groups
    public func trashSelectedOrphans() async -> Bool {
        await trashSelectedOrphans(trashHandler: nil)
    }
    
    public func trashSelectedOrphans(trashHandler: (@Sendable (URL) throws -> Void)?) async -> Bool {
        guard !isCleaning else { return false }
        isCleaning = true
        scanError = nil
        let isDryRun = DryRunManager.shared.isEnabled
        statusMessage = isDryRun ?
            "Simulating orphaned leftover removal (Dry-Run mode)..." :
            "Safely moving selected orphaned leftover files to macOS Trash..."
        
        let startTime = Date()
        let groupsSnapshot = self.orphanedGroups
        let home = self.homeURL
        let logManager = self.deletionLogManager
        
        let outcome = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let performTrash: @Sendable (URL) throws -> Void = trashHandler ?? { url in
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
            
            var reclaimedBytes: Int64 = 0
            var reclaimedFiles: Int = 0
            var errorsCount: Int = 0
            var remainingGroups: [OrphanedAppGroup] = []
            var dryRunTargets: [String] = []
            var firstErrorMessage: String? = nil
            
            for var group in groupsSnapshot {
                var remainingItems: [AppLeftoverItem] = []
                for item in group.items {
                    guard item.isSelected else {
                        remainingItems.append(item)
                        continue
                    }
                    
                    if let protErr = PathProtection.evaluatePath(url: item.url, homeDirectory: home) {
                        AppLogger.security.warning("Skipping protected orphan: \(item.url.path) - \(protErr.localizedDescription)")
                        logManager.log(
                            sourceModule: "App Uninstaller",
                            path: item.url.path,
                            sizeBytes: item.size,
                            destination: .trash,
                            isSuccess: false,
                            errorMessage: protErr.localizedDescription
                        )
                        errorsCount += 1
                        if firstErrorMessage == nil { firstErrorMessage = protErr.localizedDescription }
                        remainingItems.append(item)
                        continue
                    }
                    
                    if isDryRun {
                        dryRunTargets.append(item.url.path)
                        logManager.log(
                            sourceModule: "App Uninstaller",
                            path: item.url.path,
                            sizeBytes: item.size,
                            destination: .simulated,
                            isSuccess: true
                        )
                        reclaimedBytes += item.size
                        reclaimedFiles += max(1, item.fileCount)
                    } else {
                        do {
                            if fm.fileExists(atPath: item.url.path) {
                                try performTrash(item.url)
                                logManager.log(
                                    sourceModule: "App Uninstaller",
                                    path: item.url.path,
                                    sizeBytes: item.size,
                                    destination: .trash,
                                    isSuccess: true
                                )
                                reclaimedBytes += item.size
                                reclaimedFiles += max(1, item.fileCount)
                            }
                        } catch {
                            AppLogger.cleanup.error("Error moving orphan to Trash: \(item.url.path) - \(error.localizedDescription)")
                            logManager.log(
                                sourceModule: "App Uninstaller",
                                path: item.url.path,
                                sizeBytes: item.size,
                                destination: .trash,
                                isSuccess: false,
                                errorMessage: error.localizedDescription
                            )
                            errorsCount += 1
                            if firstErrorMessage == nil { firstErrorMessage = error.localizedDescription }
                            remainingItems.append(item)
                        }
                    }
                }
                
                if !remainingItems.isEmpty {
                    group.items = remainingItems
                    group.isSelected = remainingItems.allSatisfy { $0.isSelected }
                    remainingGroups.append(group)
                }
            }
            
            return (
                reclaimedBytes: reclaimedBytes,
                reclaimedFiles: reclaimedFiles,
                errorsCount: errorsCount,
                remainingGroups: remainingGroups,
                dryRunTargets: dryRunTargets,
                firstErrorMessage: firstErrorMessage
            )
        }.value
        
        for target in outcome.dryRunTargets {
            DryRunManager.shared.logSimulation(action: "Trash Orphaned Item", target: target)
        }
        
        self.orphanedGroups = outcome.remainingGroups
        if outcome.errorsCount > 0 {
            self.scanError = outcome.firstErrorMessage ?? "Could not move \(outcome.errorsCount) orphaned item(s) to Trash."
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let result = CleanResult(
            reclaimedBytes: outcome.reclaimedBytes,
            reclaimedFilesCount: outcome.reclaimedFiles,
            errorsCount: outcome.errorsCount,
            duration: elapsed,
            cleanedCategorySizes: [:],
            isDryRun: isDryRun
        )
        
        self.lastCleanResult = result
        self.isCleaning = false
        self.showCelebration = outcome.errorsCount == 0 && outcome.reclaimedFiles > 0
        self.statusMessage = isDryRun ?
            "Dry-Run: Simulated \(outcome.reclaimedFiles) orphaned files (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file)))." :
            "Successfully moved \(outcome.reclaimedFiles) orphaned files (\(ByteCountFormatter.string(fromByteCount: outcome.reclaimedBytes, countStyle: .file))) to Trash."
        
        StorageModel.shared.refresh()
        return outcome.errorsCount == 0
    }
}
