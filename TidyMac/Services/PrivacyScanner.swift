import Foundation
import SwiftUI
import AppKit
import SQLite3

public final class PrivacyScanner: ObservableObject {
    public static let shared = PrivacyScanner()
    
    @Published public var items: [PrivacyItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isClearing: Bool = false
    @Published public var lastReclaimedBytes: Int64 = 0
    @Published public var showSuccessAlert: Bool = false
    @Published public var runningBrowserWarning: BrowserType? = nil
    @Published public var scanError: String? = nil
    @Published public var deletionErrors: [String] = []
    @Published public var lastErrorsCount: Int = 0
    @Published public private(set) var runningBrowsers: Set<BrowserType> = []
    
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private let home: URL
    private let deletionLogManager: DeletionLogManager
    private let trashHandler: @Sendable (URL) throws -> Void
    private let scanQueue = DispatchQueue(label: "com.tidymac.privacyscanner.scan", qos: .userInitiated)
    private var scanGeneration: Int = 0
    private var workspaceObservers: [NSObjectProtocol] = []
    
    private convenience init() {
        self.init(homeDirectory: FileManager.default.homeDirectoryForCurrentUser, autoScan: true)
    }
    
    public init(
        homeDirectory: URL,
        autoScan: Bool = true,
        deletionLogManager: DeletionLogManager = .shared,
        trashHandler: (@Sendable (URL) throws -> Void)? = nil
    ) {
        self.home = homeDirectory
        self.deletionLogManager = deletionLogManager
        self.trashHandler = trashHandler ?? { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        setupDefaultItems()
        refreshRunningBrowsers()
        observeWorkspaceNotifications()
        if autoScan {
            scan()
        }
    }
    
    deinit {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - Setup Default Items
    private func setupDefaultItems() {
        self.items = [
            // Safari
            PrivacyItem(
                id: "safari_history",
                browser: .safari,
                category: .history,
                title: "Safari Browsing History",
                description: "List of visited websites, timestamps, and page titles",
                relativePaths: [
                    "Library/Safari/History.db",
                    "Library/Safari/History.db-wal",
                    "Library/Safari/History.db-shm",
                    "Library/Safari/CloudHistory.db"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "safari_cookies",
                browser: .safari,
                category: .cookies,
                title: "Safari Cookies & Local Storage",
                description: "Session cookies, persistent tracking tokens, and website databases",
                relativePaths: [
                    "Library/Cookies/Cookies.binarycookies",
                    "Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies",
                    "Library/Safari/LocalStorage",
                    "Library/Safari/Databases"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "safari_downloads",
                browser: .safari,
                category: .downloads,
                title: "Safari Download History",
                description: "Record of files and media downloaded via Safari",
                relativePaths: [
                    "Library/Safari/Downloads.plist"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "safari_caches",
                browser: .safari,
                category: .recentCache,
                title: "Safari Web Cache & Icons",
                description: "Cached web page assets, favicons, and quick-look previews",
                relativePaths: [
                    "Library/Caches/com.apple.Safari",
                    "Library/Containers/com.apple.Safari/Data/Library/Caches",
                    "Library/Safari/Template Icons",
                    "Library/Safari/Favicon Cache",
                    "Library/Safari/Touch Icons Cache"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            
            // Google Chrome (all profiles: Default, Profile *)
            PrivacyItem(
                id: "chrome_history",
                browser: .chrome,
                category: .history,
                title: "Chrome Browsing History",
                description: "Visited URL logs, search history, and omnibox navigation indices across all profiles",
                relativePaths: [
                    "Library/Application Support/Google/Chrome"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "chrome_cookies",
                browser: .chrome,
                category: .cookies,
                title: "Chrome Cookies & Storage",
                description: "Site authentication cookies, IndexedDB, and HTML5 storage across all profiles",
                relativePaths: [
                    "Library/Application Support/Google/Chrome"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "chrome_downloads",
                browser: .chrome,
                category: .downloads,
                title: "Chrome Download History",
                description: "Chrome download records and pending download service states across all profiles",
                relativePaths: [
                    "Library/Application Support/Google/Chrome"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "chrome_caches",
                browser: .chrome,
                category: .recentCache,
                title: "Chrome Cache & Top Sites",
                description: "HTTP disk cache, compiled code cache, and thumbnail previews across all profiles",
                relativePaths: [
                    "Library/Caches/Google/Chrome",
                    "Library/Application Support/Google/Chrome"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            
            // Mozilla Firefox
            PrivacyItem(
                id: "firefox_history",
                browser: .firefox,
                category: .history,
                title: "Firefox Browsing History",
                description: "Visited URLs and history visits in Places database (bookmarks preserved)",
                relativePaths: [
                    "Library/Application Support/Firefox/Profiles"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "firefox_cookies",
                browser: .firefox,
                category: .cookies,
                title: "Firefox Cookies & Site Data",
                description: "Cookies SQLite databases and site-specific storage partitions",
                relativePaths: [
                    "Library/Application Support/Firefox/Profiles"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "firefox_downloads",
                browser: .firefox,
                category: .downloads,
                title: "Firefox Download History",
                description: "Download metadata records and unfinished transfer logs",
                relativePaths: [
                    "Library/Application Support/Firefox/Profiles"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "firefox_caches",
                browser: .firefox,
                category: .recentCache,
                title: "Firefox Web Cache",
                description: "Temporary web assets, image cache, and form input history",
                relativePaths: [
                    "Library/Caches/Firefox/Profiles"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            
            // macOS Recent Items
            PrivacyItem(
                id: "macos_recent_documents",
                browser: .recentItems,
                category: .history,
                title: "Recent Documents & Files",
                description: "Finder and system-wide recent document shortcuts (.sfl3)",
                relativePaths: [
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl3",
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl2",
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments"
                ],
                isEnabled: true,
                isAvailable: false
            ),
            PrivacyItem(
                id: "macos_recent_apps",
                browser: .recentItems,
                category: .recentCache,
                title: "Recent Applications & Servers",
                description: "Recently opened applications and connected network server history",
                relativePaths: [
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentApplications.sfl3",
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentApplications.sfl2",
                    "Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentServers.sfl3",
                    "Library/Preferences/com.apple.recentitems.plist"
                ],
                isEnabled: true,
                isAvailable: false
            )
        ]
    }
    
    // MARK: - Browser Running Check & Live Workspace Observation
    private func observeWorkspaceNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        
        let launchObserver = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let launchedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.handleWorkspaceAppChange(launchedApp: launchedApp, terminatedApp: nil)
        }
        
        let terminateObserver = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.handleWorkspaceAppChange(launchedApp: nil, terminatedApp: terminatedApp)
        }
        
        workspaceObservers = [launchObserver, terminateObserver]
    }
    
    private func handleWorkspaceAppChange(
        launchedApp: NSRunningApplication?,
        terminatedApp: NSRunningApplication?
    ) {
        var updated = currentRunningBrowsers(excluding: terminatedApp)
        if let bundleId = launchedApp?.bundleIdentifier,
           let browser = BrowserType.allCases.first(where: { $0.bundleIdentifier == bundleId }),
           launchedApp?.isTerminated != true {
            updated.insert(browser)
        }
        
        if self.runningBrowsers != updated {
            self.runningBrowsers = updated
        }
        
        if let warningBrowser = self.runningBrowserWarning, !updated.contains(warningBrowser) {
            self.runningBrowserWarning = nil
        }
    }
    
    private func currentRunningBrowsers(excluding terminatedApp: NSRunningApplication? = nil) -> Set<BrowserType> {
        var running = Set<BrowserType>()
        for browser in BrowserType.allCases {
            guard let bundleId = browser.bundleIdentifier else { continue }
            let activeApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                .filter { app in
                    !app.isTerminated && app != terminatedApp
                }
            if !activeApps.isEmpty {
                running.insert(browser)
            }
        }
        return running
    }
    
    public func refreshRunningBrowsers() {
        let running = currentRunningBrowsers()
        if Thread.isMainThread {
            if self.runningBrowsers != running {
                self.runningBrowsers = running
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.runningBrowsers != running {
                    self.runningBrowsers = running
                }
            }
        }
    }
    
    public func isBrowserRunning(_ browser: BrowserType) -> Bool {
        guard let bundleId = browser.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { !$0.isTerminated }
            .isEmpty
    }
    
    public func quitBrowser(_ browser: BrowserType) {
        guard let bundleId = browser.bundleIdentifier else { return }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in apps {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshRunningBrowsers()
            self?.scan()
        }
    }
    
    // MARK: - Scan Traces
    private struct ScanItemResult {
        let id: String
        let fileCount: Int
        let sizeBytes: Int64
        let isAvailable: Bool
    }
    
    public func scan() {
        scan(completion: nil)
    }
    
    public func scanAsync() async {
        await withCheckedContinuation { continuation in
            scan {
                continuation.resume()
            }
        }
    }
    
    private func scan(completion: (() -> Void)?) {
        let startOnMain = { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            
            self.scanGeneration += 1
            let generation = self.scanGeneration
            self.isScanning = true
            let snapshot = self.items
            
            self.scanQueue.async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        completion?()
                    }
                    return
                }
                
                let results = self.computeScanResults(for: snapshot)
                
                DispatchQueue.main.async {
                    if generation == self.scanGeneration {
                        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
                        var merged = self.items
                        for idx in merged.indices {
                            if let res = resultsByID[merged[idx].id] {
                                merged[idx].fileCount = res.fileCount
                                merged[idx].sizeBytes = res.sizeBytes
                                merged[idx].isAvailable = res.isAvailable
                            }
                        }
                        self.items = merged
                        self.isScanning = false
                    }
                    completion?()
                }
            }
        }
        
        if Thread.isMainThread {
            startOnMain()
        } else {
            DispatchQueue.main.async(execute: startOnMain)
        }
    }
    
    private func computeScanResults(for snapshot: [PrivacyItem]) -> [ScanItemResult] {
        var results: [ScanItemResult] = []
        results.reserveCapacity(snapshot.count)
        
        for item in snapshot {
            let count: Int
            let totalBytes: Int64
            let available: Bool
            
            switch item.browser {
            case .firefox:
                (count, totalBytes, available) = scanFirefoxItem(item: item)
            case .chrome:
                let targets = chromeTargetURLs(for: item.category)
                (count, totalBytes, available) = scanTargetURLs(targets)
            case .safari, .recentItems:
                let targets = item.relativePaths.map { home.appendingPathComponent($0) }
                (count, totalBytes, available) = scanTargetURLs(targets)
            }
            
            results.append(ScanItemResult(
                id: item.id,
                fileCount: count,
                sizeBytes: totalBytes,
                isAvailable: available
            ))
        }
        
        return results
    }
    
    private func scanTargetURLs(_ urls: [URL]) -> (count: Int, bytes: Int64, available: Bool) {
        let fm = FileManager.default
        var count = 0
        var totalBytes: Int64 = 0
        var foundAny = false
        
        for fullURL in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullURL.path, isDirectory: &isDir) else {
                continue
            }
            
            if isDir.boolValue {
                let res = SizeCalculator.calculateSize(of: fullURL, fm: fm)
                let hasEntries = res.filesCount > 0 || !((try? fm.contentsOfDirectory(atPath: fullURL.path))?.isEmpty ?? true)
                if hasEntries {
                    foundAny = true
                    count += res.filesCount
                    totalBytes += res.bytes
                }
            } else {
                foundAny = true
                let res = SizeCalculator.calculateSize(of: fullURL, fm: fm)
                count += max(1, res.filesCount)
                totalBytes += res.bytes
            }
        }
        
        return (count, totalBytes, foundAny)
    }
    
    // MARK: - Chrome Multi-Profile Discovery
    private static func chromeProfileDirectories(in baseURL: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return entries.filter { url in
            let name = url.lastPathComponent
            guard name == "Default" || name.hasPrefix("Profile ") else { return false }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDir
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    private func chromeTargetURLs(for category: PrivacyCategory) -> [URL] {
        Self.chromeTargetURLs(for: category, home: home)
    }
    
    private static func chromeTargetURLs(for category: PrivacyCategory, home: URL) -> [URL] {
        let appSupportBase = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        let cacheBase = home.appendingPathComponent("Library/Caches/Google/Chrome")
        
        let appSupportProfiles = chromeProfileDirectories(in: appSupportBase)
        let cacheProfiles = chromeProfileDirectories(in: cacheBase)
        
        var targets: [URL] = []
        
        switch category {
        case .history:
            for profile in appSupportProfiles {
                targets.append(profile.appendingPathComponent("History"))
                targets.append(profile.appendingPathComponent("History-journal"))
                targets.append(profile.appendingPathComponent("History Provider Cache"))
            }
        case .cookies:
            for profile in appSupportProfiles {
                targets.append(profile.appendingPathComponent("Cookies"))
                targets.append(profile.appendingPathComponent("Cookies-journal"))
                targets.append(profile.appendingPathComponent("Network/Cookies"))
                targets.append(profile.appendingPathComponent("Network/Cookies-journal"))
                targets.append(profile.appendingPathComponent("IndexedDB"))
                targets.append(profile.appendingPathComponent("Local Storage"))
            }
        case .downloads:
            for profile in appSupportProfiles {
                targets.append(profile.appendingPathComponent("Download Service"))
            }
        case .recentCache:
            for cacheProfile in cacheProfiles {
                targets.append(cacheProfile.appendingPathComponent("Cache"))
                targets.append(cacheProfile.appendingPathComponent("Code Cache"))
                targets.append(cacheProfile.appendingPathComponent("GPUCache"))
            }
            for profile in appSupportProfiles {
                targets.append(profile.appendingPathComponent("Top Sites"))
                targets.append(profile.appendingPathComponent("Shortcuts"))
            }
        }
        
        return targets
    }
    
    // MARK: - Firefox Profile Discovery & Scan
    private static func firefoxProfileDirectories(in baseURL: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return entries.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
    }
    
    private func scanFirefoxItem(item: PrivacyItem) -> (count: Int, bytes: Int64, available: Bool) {
        let fm = FileManager.default
        let profilesURL = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        let cacheProfilesURL = home.appendingPathComponent("Library/Caches/Firefox/Profiles")
        
        var count = 0
        var bytes: Int64 = 0
        var available = false
        
        switch item.category {
        case .history:
            for profile in Self.firefoxProfileDirectories(in: profilesURL) {
                let placesURL = profile.appendingPathComponent("places.sqlite")
                guard fm.fileExists(atPath: placesURL.path) else { continue }
                
                let hasHistory = firefoxPlacesHasHistory(at: placesURL)
                guard hasHistory else { continue }
                
                available = true
                let dbFiles = ["places.sqlite", "places.sqlite-wal", "places.sqlite-shm"]
                for fileName in dbFiles {
                    let fileURL = profile.appendingPathComponent(fileName)
                    if fm.fileExists(atPath: fileURL.path) {
                        count += 1
                        bytes += SizeCalculator.calculateSize(of: fileURL, fm: fm).bytes
                    }
                }
            }
        case .cookies:
            for profile in Self.firefoxProfileDirectories(in: profilesURL) {
                let cookieFiles = ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]
                for fileName in cookieFiles {
                    let fileURL = profile.appendingPathComponent(fileName)
                    if fm.fileExists(atPath: fileURL.path) {
                        available = true
                        count += 1
                        bytes += SizeCalculator.calculateSize(of: fileURL, fm: fm).bytes
                    }
                }
                let storageURL = profile.appendingPathComponent("storage")
                if fm.fileExists(atPath: storageURL.path) {
                    let res = SizeCalculator.calculateSize(of: storageURL, fm: fm)
                    let hasEntries = res.filesCount > 0 || !((try? fm.contentsOfDirectory(atPath: storageURL.path))?.isEmpty ?? true)
                    if hasEntries {
                        available = true
                        count += res.filesCount
                        bytes += res.bytes
                    }
                }
            }
        case .downloads:
            for profile in Self.firefoxProfileDirectories(in: profilesURL) {
                let downloadsURL = profile.appendingPathComponent("downloads.json")
                if fm.fileExists(atPath: downloadsURL.path) {
                    available = true
                    count += 1
                    bytes += SizeCalculator.calculateSize(of: downloadsURL, fm: fm).bytes
                }
            }
        case .recentCache:
            for cacheProfile in Self.firefoxProfileDirectories(in: cacheProfilesURL) {
                let res = SizeCalculator.calculateSize(of: cacheProfile, fm: fm)
                let hasEntries = res.filesCount > 0 || !((try? fm.contentsOfDirectory(atPath: cacheProfile.path))?.isEmpty ?? true)
                if hasEntries {
                    available = true
                    count += res.filesCount
                    bytes += res.bytes
                }
            }
        }
        
        return (count, bytes, available)
    }
    
    // MARK: - Firefox places.sqlite Helpers
    private static func sqliteTableExists(_ tableName: String, on db: OpaquePointer) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, tableName, -1, Self.sqliteTransient)
        return sqlite3_step(stmt) == SQLITE_ROW
    }
    
    private static func sqliteTableColumns(_ tableName: String, on db: OpaquePointer) -> Set<String> {
        var cols = Set<String>()
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(tableName));", -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return cols
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(stmt, 1) {
                cols.insert(String(cString: namePtr))
            }
        }
        return cols
    }
    
    private static func executeSQL(_ sql: String, on db: OpaquePointer) -> String? {
        var errPtr: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errPtr)
        if rc != SQLITE_OK {
            let message = errPtr.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(db))
            sqlite3_free(errPtr)
            return message
        }
        return nil
    }
    
    private static func sqliteHasRows(_ sql: String, on db: OpaquePointer) -> Bool? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) > 0
        } else if stepRC == SQLITE_DONE {
            return false
        }
        return nil
    }
    
    /// Checks read-only whether Firefox `places.sqlite` contains browsing history visits
    /// or unbookmarked URLs. Falls back to `true` if the DB is currently locked.
    private func firefoxPlacesHasHistory(at placesURL: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(placesURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            return true
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)
        
        let hasHistoryVisits = Self.sqliteTableExists("moz_historyvisits", on: db)
        let hasPlaces = Self.sqliteTableExists("moz_places", on: db)
        let hasBookmarks = Self.sqliteTableExists("moz_bookmarks", on: db)
        
        if hasHistoryVisits {
            if let hasVisits = Self.sqliteHasRows("SELECT EXISTS(SELECT 1 FROM moz_historyvisits LIMIT 1);", on: db) {
                if hasVisits { return true }
            } else {
                return true
            }
        }
        
        if hasPlaces && hasBookmarks {
            let sql = """
            SELECT EXISTS(
                SELECT 1 FROM moz_places p
                WHERE NOT EXISTS (SELECT 1 FROM moz_bookmarks b WHERE b.fk = p.id)
                LIMIT 1
            );
            """
            if let hasUnbookmarked = Self.sqliteHasRows(sql, on: db) {
                if hasUnbookmarked { return true }
            } else {
                return true
            }
        }
        
        return false
    }
    
    /// Clears Firefox browsing history inside `places.sqlite` without deleting the file
    /// or touching bookmarked `moz_places` and `moz_bookmarks` rows.
    private static func cleanFirefoxPlacesDatabase(
        at placesURL: URL,
        deletionLogManager: DeletionLogManager
    ) -> (success: Bool, reclaimed: Int64, cleaned: Bool, error: String?) {
        guard !PathProtection.isProtected(url: placesURL) else {
            let msg = "Refusing to modify protected path: \(placesURL.path)"
            AppLogger.security.warning("\(msg)")
            deletionLogManager.log(
                sourceModule: "Privacy",
                path: placesURL.path,
                sizeBytes: 0,
                destination: .permanent,
                isSuccess: false,
                errorMessage: msg
            )
            return (false, 0, false, msg)
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: placesURL.path) else {
            return (true, 0, false, nil)
        }
        
        let relatedURLs = [
            placesURL,
            URL(fileURLWithPath: placesURL.path + "-wal"),
            URL(fileURLWithPath: placesURL.path + "-shm")
        ]
        let beforeBytes = relatedURLs.reduce(Int64(0)) { $0 + SizeCalculator.calculateSize(of: $1, fm: fm).bytes }
        
        var changedRows: Int32 = 0
        var openSucceeded = false
        
        // Scope SQLite connection so it closes cleanly before measuring post-VACUUM/checkpoint disk size.
        do {
            var db: OpaquePointer?
            let openRC = sqlite3_open_v2(placesURL.path, &db, SQLITE_OPEN_READWRITE, nil)
            guard openRC == SQLITE_OK, let db else {
                let errMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error \(openRC)"
                if let db { sqlite3_close(db) }
                let msg = "Failed to open Firefox \(placesURL.lastPathComponent): \(errMsg)"
                AppLogger.cleanup.error("\(msg)")
                deletionLogManager.log(
                    sourceModule: "Privacy",
                    path: placesURL.path,
                    sizeBytes: 0,
                    destination: .permanent,
                    isSuccess: false,
                    errorMessage: msg
                )
                return (false, 0, false, msg)
            }
            openSucceeded = true
            defer { sqlite3_close(db) }
            sqlite3_busy_timeout(db, 2000)
            
            let hasHistoryVisits = sqliteTableExists("moz_historyvisits", on: db)
            let hasPlaces = sqliteTableExists("moz_places", on: db)
            let hasBookmarks = sqliteTableExists("moz_bookmarks", on: db)
            let hasInputHistory = sqliteTableExists("moz_inputhistory", on: db)
            
            guard hasHistoryVisits || (hasPlaces && hasBookmarks) else {
                return (true, 0, false, nil)
            }
            
            let changesBefore = sqlite3_total_changes(db)
            
            if let err = executeSQL("BEGIN IMMEDIATE;", on: db) {
                let msg = "Failed to begin Firefox history cleanup transaction: \(err)"
                AppLogger.cleanup.error("\(msg)")
                deletionLogManager.log(
                    sourceModule: "Privacy",
                    path: placesURL.path,
                    sizeBytes: 0,
                    destination: .permanent,
                    isSuccess: false,
                    errorMessage: msg
                )
                return (false, 0, false, msg)
            }
            
            if hasHistoryVisits {
                if let err = executeSQL("DELETE FROM moz_historyvisits;", on: db) {
                    _ = executeSQL("ROLLBACK;", on: db)
                    let msg = "Failed to clear Firefox history visits: \(err)"
                    AppLogger.cleanup.error("\(msg)")
                    deletionLogManager.log(
                        sourceModule: "Privacy",
                        path: placesURL.path,
                        sizeBytes: 0,
                        destination: .permanent,
                        isSuccess: false,
                        errorMessage: msg
                    )
                    return (false, 0, false, msg)
                }
            }
            
            if hasPlaces && hasBookmarks {
                let deletePlacesSQL = hasHistoryVisits ?
                    """
                    DELETE FROM moz_places
                    WHERE NOT EXISTS (SELECT 1 FROM moz_bookmarks b WHERE b.fk = moz_places.id)
                      AND NOT EXISTS (SELECT 1 FROM moz_historyvisits v WHERE v.place_id = moz_places.id);
                    """ :
                    """
                    DELETE FROM moz_places
                    WHERE NOT EXISTS (SELECT 1 FROM moz_bookmarks b WHERE b.fk = moz_places.id);
                    """
                if let err = executeSQL(deletePlacesSQL, on: db) {
                    _ = executeSQL("ROLLBACK;", on: db)
                    let msg = "Failed to clean unbookmarked Firefox places: \(err)"
                    AppLogger.cleanup.error("\(msg)")
                    deletionLogManager.log(
                        sourceModule: "Privacy",
                        path: placesURL.path,
                        sizeBytes: 0,
                        destination: .permanent,
                        isSuccess: false,
                        errorMessage: msg
                    )
                    return (false, 0, false, msg)
                }
                
                let placeCols = sqliteTableColumns("moz_places", on: db)
                var resetAssignments: [String] = []
                if placeCols.contains("visit_count") {
                    resetAssignments.append("visit_count = 0")
                }
                if placeCols.contains("last_visit_date") {
                    resetAssignments.append("last_visit_date = NULL")
                }
                if !resetAssignments.isEmpty {
                    let updateSQL = "UPDATE moz_places SET \(resetAssignments.joined(separator: ", "));"
                    if let err = executeSQL(updateSQL, on: db) {
                        _ = executeSQL("ROLLBACK;", on: db)
                        let msg = "Failed to reset Firefox bookmarked visit counts: \(err)"
                        AppLogger.cleanup.error("\(msg)")
                        deletionLogManager.log(
                            sourceModule: "Privacy",
                            path: placesURL.path,
                            sizeBytes: 0,
                            destination: .permanent,
                            isSuccess: false,
                            errorMessage: msg
                        )
                        return (false, 0, false, msg)
                    }
                }
            }
            
            if hasInputHistory && hasPlaces {
                let cleanInputSQL = """
                DELETE FROM moz_inputhistory
                WHERE NOT EXISTS (SELECT 1 FROM moz_places p WHERE p.id = moz_inputhistory.place_id);
                """
                if let err = executeSQL(cleanInputSQL, on: db) {
                    _ = executeSQL("ROLLBACK;", on: db)
                    let msg = "Failed to clean Firefox input history: \(err)"
                    AppLogger.cleanup.error("\(msg)")
                    deletionLogManager.log(
                        sourceModule: "Privacy",
                        path: placesURL.path,
                        sizeBytes: 0,
                        destination: .permanent,
                        isSuccess: false,
                        errorMessage: msg
                    )
                    return (false, 0, false, msg)
                }
            }
            
            if let err = executeSQL("COMMIT;", on: db) {
                _ = executeSQL("ROLLBACK;", on: db)
                let msg = "Failed to commit Firefox history cleanup: \(err)"
                AppLogger.cleanup.error("\(msg)")
                deletionLogManager.log(
                    sourceModule: "Privacy",
                    path: placesURL.path,
                    sizeBytes: 0,
                    destination: .permanent,
                    isSuccess: false,
                    errorMessage: msg
                )
                return (false, 0, false, msg)
            }
            
            changedRows = sqlite3_total_changes(db) - changesBefore
            
            if let walErr = executeSQL("PRAGMA wal_checkpoint(TRUNCATE);", on: db) {
                AppLogger.cleanup.debug("Firefox places.sqlite wal_checkpoint skipped/warning: \(walErr)")
            }
            if let vacuumErr = executeSQL("VACUUM;", on: db) {
                AppLogger.cleanup.warning("Firefox places.sqlite VACUUM failed: \(vacuumErr)")
            }
        }
        
        let afterBytes = openSucceeded ?
            relatedURLs.reduce(Int64(0)) { $0 + SizeCalculator.calculateSize(of: $1, fm: fm).bytes } :
            beforeBytes
        let reclaimed = max(0, beforeBytes - afterBytes)
        let didClean = changedRows > 0 || reclaimed > 0
        
        if didClean {
            deletionLogManager.log(
                sourceModule: "Privacy",
                path: placesURL.path,
                sizeBytes: reclaimed,
                destination: .permanent,
                isSuccess: true
            )
        }
        
        AppLogger.cleanup.info("Cleaned Firefox browsing history in \(placesURL.path) while preserving bookmarks (reclaimed \(reclaimed) bytes)")
        return (true, reclaimed, didClean, nil)
    }
    
    // MARK: - Safe Item Deletion Helpers
    private static func safelyDelete(
        url: URL,
        itemTitle: String,
        deletionLogManager: DeletionLogManager,
        trashHandler: @Sendable (URL) throws -> Void
    ) -> (success: Bool, reclaimed: Int64, error: String?) {
        guard !PathProtection.isProtected(url: url) else {
            let msg = "Refusing to delete protected path: \(url.path)"
            AppLogger.security.warning("\(msg)")
            deletionLogManager.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: 0,
                destination: .trash,
                isSuccess: false,
                errorMessage: msg
            )
            return (false, 0, msg)
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return (true, 0, nil)
        }
        
        let sizeBytes = SizeCalculator.calculateSize(of: url, fm: fm).bytes
        
        do {
            try trashHandler(url)
            deletionLogManager.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: sizeBytes,
                destination: .trash,
                isSuccess: true
            )
            AppLogger.cleanup.info("Moved privacy item to Trash: \(url.path)")
            return (true, sizeBytes, nil)
        } catch {
            let errorMsg = "Failed to move \(url.lastPathComponent) to Trash: \(error.localizedDescription)"
            deletionLogManager.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: sizeBytes,
                destination: .trash,
                isSuccess: false,
                errorMessage: errorMsg
            )
            AppLogger.cleanup.error("\(errorMsg)")
            return (false, 0, errorMsg)
        }
    }

    // MARK: - Cleaning Selected Items
    public func clearSelected() {
        guard !isClearing else { return }
        
        // First check if any selected browser is currently running
        for browser in BrowserType.allCases where browser != .recentItems {
            let hasSelectedItems = items.contains { $0.browser == browser && $0.isEnabled && $0.isAvailable }
            if hasSelectedItems && isBrowserRunning(browser) {
                runningBrowserWarning = browser
                return
            }
        }
        
        isClearing = true
        showSuccessAlert = false
        scanError = nil
        deletionErrors.removeAll()
        lastErrorsCount = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (totalReclaimed, _, errorsCount) = self.performSynchronousClean()
            
            DispatchQueue.main.async {
                self.lastReclaimedBytes = totalReclaimed
                self.lastErrorsCount = errorsCount
                self.isClearing = false
                self.showSuccessAlert = (errorsCount == 0)
                if errorsCount > 0 {
                    self.scanError = "\(errorsCount) privacy item(s) could not be removed (files may be locked or permission restricted)."
                }
                self.scan()
            }
        }
    }
    
    /// Asynchronously cleans selected privacy items off the main thread.
    public func performCleanAsync() async -> (reclaimedBytes: Int64, filesCount: Int, errorsCount: Int) {
        let itemsSnapshot = await MainActor.run { self.items }
        let home = self.home
        let deletionLogManager = self.deletionLogManager
        let trashHandler = self.trashHandler
        let outcome = await Task.detached(priority: .userInitiated) {
            Self.cleanItemsSnapshot(
                itemsSnapshot,
                home: home,
                deletionLogManager: deletionLogManager,
                trashHandler: trashHandler
            )
        }.value
        await MainActor.run {
            self.deletionErrors = outcome.errors
            self.lastErrorsCount = outcome.errors.count
        }
        return (outcome.reclaimedBytes, outcome.filesCount, outcome.errors.count)
    }
    
    /// Synchronously cleans selected privacy items and returns accurate stats
    public func performSynchronousClean() -> (reclaimedBytes: Int64, filesCount: Int, errorsCount: Int) {
        let itemsSnapshot: [PrivacyItem]
        if Thread.isMainThread {
            itemsSnapshot = self.items
        } else {
            itemsSnapshot = DispatchQueue.main.sync { self.items }
        }
        
        let outcome = Self.cleanItemsSnapshot(
            itemsSnapshot,
            home: home,
            deletionLogManager: deletionLogManager,
            trashHandler: trashHandler
        )
        
        if Thread.isMainThread {
            self.deletionErrors = outcome.errors
            self.lastErrorsCount = outcome.errors.count
        } else {
            DispatchQueue.main.async {
                self.deletionErrors = outcome.errors
                self.lastErrorsCount = outcome.errors.count
            }
        }
        
        return (outcome.reclaimedBytes, outcome.filesCount, outcome.errors.count)
    }
    
    private static func cleanItemsSnapshot(
        _ itemsSnapshot: [PrivacyItem],
        home: URL,
        deletionLogManager: DeletionLogManager,
        trashHandler: @Sendable (URL) throws -> Void
    ) -> (reclaimedBytes: Int64, filesCount: Int, errors: [String]) {
        let isDryRun = DryRunManager.shared.isEnabled
        var totalReclaimed: Int64 = 0
        var totalFilesCleaned: Int = 0
        var errors: [String] = []
        
        for item in itemsSnapshot where item.isEnabled && item.isAvailable {
            if isDryRun {
                DryRunManager.shared.logSimulation(action: "Clean Privacy Trace", target: item.title)
                let logPath = item.relativePaths.first.map { home.appendingPathComponent($0).path } ?? item.title
                deletionLogManager.log(
                    sourceModule: "Privacy",
                    path: logPath,
                    sizeBytes: item.sizeBytes,
                    destination: .simulated,
                    isSuccess: true
                )
                totalReclaimed += item.sizeBytes
                totalFilesCleaned += item.fileCount
                continue
            }
            
            switch item.browser {
            case .firefox:
                let (bytes, files, errs) = clearFirefoxItem(
                    item: item,
                    home: home,
                    deletionLogManager: deletionLogManager,
                    trashHandler: trashHandler
                )
                totalReclaimed += bytes
                totalFilesCleaned += files
                errors.append(contentsOf: errs)
            case .chrome:
                let targetURLs = chromeTargetURLs(for: item.category, home: home)
                let (bytes, files, errs) = cleanTargetURLs(
                    targetURLs,
                    itemTitle: item.title,
                    deletionLogManager: deletionLogManager,
                    trashHandler: trashHandler
                )
                totalReclaimed += bytes
                totalFilesCleaned += files
                errors.append(contentsOf: errs)
            case .safari, .recentItems:
                let targetURLs = item.relativePaths.map { home.appendingPathComponent($0) }
                let (bytes, files, errs) = cleanTargetURLs(
                    targetURLs,
                    itemTitle: item.title,
                    deletionLogManager: deletionLogManager,
                    trashHandler: trashHandler
                )
                totalReclaimed += bytes
                totalFilesCleaned += files
                errors.append(contentsOf: errs)
            }
        }
        
        // Restart sharedfilelistd if recent items cleared (skip if dry-run)
        if !isDryRun && itemsSnapshot.contains(where: { $0.browser == .recentItems && $0.isEnabled && $0.isAvailable }) {
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["sharedfilelistd"]
            killTask.standardOutput = FileHandle.nullDevice
            killTask.standardError = FileHandle.nullDevice
            try? killTask.run()
            killTask.waitUntilExit()
        }
        
        return (totalReclaimed, totalFilesCleaned, errors)
    }
    
    private static func cleanTargetURLs(
        _ urls: [URL],
        itemTitle: String,
        deletionLogManager: DeletionLogManager,
        trashHandler: @Sendable (URL) throws -> Void
    ) -> (reclaimedBytes: Int64, filesCount: Int, errors: [String]) {
        let fm = FileManager.default
        var reclaimed: Int64 = 0
        var count = 0
        var errors: [String] = []
        
        for fullURL in urls {
            if PathProtection.isProtected(url: fullURL) {
                let msg = "Refusing to delete protected path: \(fullURL.path)"
                AppLogger.security.warning("\(msg)")
                deletionLogManager.log(
                    sourceModule: "Privacy",
                    path: fullURL.path,
                    sizeBytes: 0,
                    destination: .trash,
                    isSuccess: false,
                    errorMessage: msg
                )
                continue
            }
            
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullURL.path, isDirectory: &isDir) else {
                continue
            }
            
            if isDir.boolValue {
                do {
                    let contents = try fm.contentsOfDirectory(at: fullURL, includingPropertiesForKeys: nil)
                    for file in contents {
                        let result = safelyDelete(
                            url: file,
                            itemTitle: itemTitle,
                            deletionLogManager: deletionLogManager,
                            trashHandler: trashHandler
                        )
                        if result.success {
                            reclaimed += result.reclaimed
                            count += 1
                        } else if let err = result.error {
                            errors.append(err)
                        }
                    }
                } catch {
                    let errMsg = "Failed to inspect \(fullURL.lastPathComponent): \(error.localizedDescription)"
                    AppLogger.cleanup.error("\(errMsg)")
                    errors.append(errMsg)
                }
            } else {
                let result = safelyDelete(
                    url: fullURL,
                    itemTitle: itemTitle,
                    deletionLogManager: deletionLogManager,
                    trashHandler: trashHandler
                )
                if result.success {
                    reclaimed += result.reclaimed
                    count += 1
                } else if let err = result.error {
                    errors.append(err)
                }
            }
        }
        
        return (reclaimed, count, errors)
    }
    
    private static func clearFirefoxItem(
        item: PrivacyItem,
        home: URL,
        deletionLogManager: DeletionLogManager,
        trashHandler: @Sendable (URL) throws -> Void
    ) -> (reclaimedBytes: Int64, filesCount: Int, errors: [String]) {
        let fm = FileManager.default
        let profilesURL = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        let cacheProfilesURL = home.appendingPathComponent("Library/Caches/Firefox/Profiles")
        
        var reclaimed: Int64 = 0
        var count = 0
        var errs: [String] = []
        
        switch item.category {
        case .history:
            for profile in firefoxProfileDirectories(in: profilesURL) {
                let placesURL = profile.appendingPathComponent("places.sqlite")
                guard fm.fileExists(atPath: placesURL.path) else { continue }
                
                let res = cleanFirefoxPlacesDatabase(at: placesURL, deletionLogManager: deletionLogManager)
                if res.success {
                    reclaimed += res.reclaimed
                    if res.cleaned {
                        count += 1
                    }
                } else if let err = res.error {
                    errs.append(err)
                }
            }
        case .cookies:
            for profile in firefoxProfileDirectories(in: profilesURL) {
                var targetURLs = ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]
                    .map { profile.appendingPathComponent($0) }
                targetURLs.append(profile.appendingPathComponent("storage"))
                
                for url in targetURLs where fm.fileExists(atPath: url.path) {
                    let res = safelyDelete(
                        url: url,
                        itemTitle: item.title,
                        deletionLogManager: deletionLogManager,
                        trashHandler: trashHandler
                    )
                    if res.success {
                        reclaimed += res.reclaimed
                        count += 1
                    } else if let err = res.error {
                        errs.append(err)
                    }
                }
            }
        case .downloads:
            for profile in firefoxProfileDirectories(in: profilesURL) {
                let url = profile.appendingPathComponent("downloads.json")
                if fm.fileExists(atPath: url.path) {
                    let res = safelyDelete(
                        url: url,
                        itemTitle: item.title,
                        deletionLogManager: deletionLogManager,
                        trashHandler: trashHandler
                    )
                    if res.success {
                        reclaimed += res.reclaimed
                        count += 1
                    } else if let err = res.error {
                        errs.append(err)
                    }
                }
            }
        case .recentCache:
            for cacheURL in firefoxProfileDirectories(in: cacheProfilesURL) {
                let res = safelyDelete(
                    url: cacheURL,
                    itemTitle: item.title,
                    deletionLogManager: deletionLogManager,
                    trashHandler: trashHandler
                )
                if res.success {
                    reclaimed += res.reclaimed
                    count += 1
                } else if let err = res.error {
                    errs.append(err)
                }
            }
        }
        
        return (reclaimed, count, errs)
    }
    
    // MARK: - Toggle Helpers
    public func toggleAll(for browser: BrowserType, isEnabled: Bool) {
        for i in 0..<items.count {
            if items[i].browser == browser {
                items[i].isEnabled = isEnabled
            }
        }
    }
}
