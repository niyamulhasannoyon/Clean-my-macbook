import Foundation
import SwiftUI
import AppKit

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
    
    private let home = FileManager.default.homeDirectoryForCurrentUser
    
    private init() {
        setupDefaultItems()
        scan()
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
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
            ),
            
            // Google Chrome
            PrivacyItem(
                id: "chrome_history",
                browser: .chrome,
                category: .history,
                title: "Chrome Browsing History",
                description: "Visited URL logs, search history, and omnibox navigation indices",
                relativePaths: [
                    "Library/Application Support/Google/Chrome/Default/History",
                    "Library/Application Support/Google/Chrome/Default/History-journal",
                    "Library/Application Support/Google/Chrome/Default/History Provider Cache"
                ],
                isEnabled: true
            ),
            PrivacyItem(
                id: "chrome_cookies",
                browser: .chrome,
                category: .cookies,
                title: "Chrome Cookies & Storage",
                description: "Site authentication cookies, IndexedDB, and HTML5 storage",
                relativePaths: [
                    "Library/Application Support/Google/Chrome/Default/Cookies",
                    "Library/Application Support/Google/Chrome/Default/Cookies-journal",
                    "Library/Application Support/Google/Chrome/Default/Network/Cookies",
                    "Library/Application Support/Google/Chrome/Default/Network/Cookies-journal",
                    "Library/Application Support/Google/Chrome/Default/IndexedDB",
                    "Library/Application Support/Google/Chrome/Default/Local Storage"
                ],
                isEnabled: true
            ),
            PrivacyItem(
                id: "chrome_downloads",
                browser: .chrome,
                category: .downloads,
                title: "Chrome Download History",
                description: "Chrome download records and pending download service states",
                relativePaths: [
                    "Library/Application Support/Google/Chrome/Default/Download Service"
                ],
                isEnabled: true
            ),
            PrivacyItem(
                id: "chrome_caches",
                browser: .chrome,
                category: .recentCache,
                title: "Chrome Cache & Top Sites",
                description: "HTTP disk cache, compiled code cache, and thumbnail previews",
                relativePaths: [
                    "Library/Caches/Google/Chrome/Default/Cache",
                    "Library/Caches/Google/Chrome/Default/Code Cache",
                    "Library/Caches/Google/Chrome/Default/GPUCache",
                    "Library/Application Support/Google/Chrome/Default/Top Sites",
                    "Library/Application Support/Google/Chrome/Default/Shortcuts"
                ],
                isEnabled: true
            ),
            
            // Mozilla Firefox
            PrivacyItem(
                id: "firefox_history",
                browser: .firefox,
                category: .history,
                title: "Firefox Browsing History",
                description: "Places SQLite database storing visited URLs and frecency scores",
                relativePaths: [
                    "Library/Application Support/Firefox/Profiles"
                ],
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
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
                isEnabled: true
            )
        ]
    }
    
    // MARK: - Browser Running Check
    public func isBrowserRunning(_ browser: BrowserType) -> Bool {
        guard let bundleId = browser.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    public func quitBrowser(_ browser: BrowserType) {
        guard let bundleId = browser.bundleIdentifier else { return }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in apps {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scan()
        }
    }
    
    // MARK: - Scan Traces
    public func scan() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var updatedItems = self.items
            
            for i in 0..<updatedItems.count {
                let item = updatedItems[i]
                var count = 0
                var totalBytes: Int64 = 0
                var foundAny = false
                
                // Specific handling for Firefox profiles
                if item.browser == .firefox {
                    let (fCount, fBytes, available) = self.scanFirefoxItem(item: item)
                    count = fCount
                    totalBytes = fBytes
                    foundAny = available
                } else {
                    for relPath in item.relativePaths {
                        let fullURL = self.home.appendingPathComponent(relPath)
                        let path = fullURL.path
                        
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                            foundAny = true
                            if isDir.boolValue {
                                let (dirCount, dirBytes) = self.sizeOfDirectory(at: fullURL)
                                count += dirCount
                                totalBytes += dirBytes
                            } else {
                                count += 1
                                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                                   let size = attrs[.size] as? Int64 {
                                    totalBytes += size
                                }
                            }
                        }
                    }
                }
                
                updatedItems[i].fileCount = count
                updatedItems[i].sizeBytes = totalBytes
                updatedItems[i].isAvailable = foundAny
            }
            
            DispatchQueue.main.async {
                self.items = updatedItems
                self.isScanning = false
            }
        }
    }
    
    private func scanFirefoxItem(item: PrivacyItem) -> (count: Int, bytes: Int64, available: Bool) {
        let profilesURL = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard let profiles = try? FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) else {
            return (0, 0, false)
        }
        
        var count = 0
        var bytes: Int64 = 0
        var available = false
        
        for profile in profiles {
            available = true
            switch item.category {
            case .history:
                let files = ["places.sqlite", "places.sqlite-wal", "places.sqlite-shm"]
                for f in files {
                    let u = profile.appendingPathComponent(f)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: u.path),
                       let size = attrs[.size] as? Int64 {
                        count += 1
                        bytes += size
                    }
                }
            case .cookies:
                let files = ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]
                for f in files {
                    let u = profile.appendingPathComponent(f)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: u.path),
                       let size = attrs[.size] as? Int64 {
                        count += 1
                        bytes += size
                    }
                }
                let storageURL = profile.appendingPathComponent("storage")
                let (dCount, dBytes) = sizeOfDirectory(at: storageURL)
                count += dCount
                bytes += dBytes
            case .downloads:
                let f = profile.appendingPathComponent("downloads.json")
                if let attrs = try? FileManager.default.attributesOfItem(atPath: f.path),
                   let size = attrs[.size] as? Int64 {
                    count += 1
                    bytes += size
                }
            case .recentCache:
                let cacheURL = home.appendingPathComponent("Library/Caches/Firefox/Profiles").appendingPathComponent(profile.lastPathComponent)
                let (cCount, cBytes) = sizeOfDirectory(at: cacheURL)
                count += cCount
                bytes += cBytes
            }
        }
        return (count, bytes, available)
    }
    
    private func sizeOfDirectory(at url: URL) -> (count: Int, bytes: Int64) {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }
        
        var count = 0
        var bytes: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }
            count += 1
            bytes += Int64(values.fileSize ?? 0)
        }
        return (count, bytes)
    }
    
    // MARK: - Safe Item Deletion Helpers
    private func safelyDelete(url: URL, itemTitle: String) -> (success: Bool, reclaimed: Int64, error: String?) {
        guard !PathProtection.isProtected(url: url) else {
            let msg = "Refusing to delete protected path: \(url.path)"
            AppLogger.security.warning("\(msg)")
            return (false, 0, msg)
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return (true, 0, nil)
        }
        
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let sizeBytes = Int64(size)
        
        // 1. Prefer moving to Trash so users can undo if needed
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            DeletionLogManager.shared.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: sizeBytes,
                destination: .trash,
                isSuccess: true
            )
            AppLogger.cleanup.info("Moved privacy item to Trash: \(url.path)")
            return (true, sizeBytes, nil)
        } catch {
            AppLogger.cleanup.debug("trashItem failed for \(url.path), falling back to removeItem: \(error.localizedDescription)")
        }
        
        // 2. Direct removal fallback
        do {
            try fm.removeItem(at: url)
            DeletionLogManager.shared.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: sizeBytes,
                destination: .permanent,
                isSuccess: true
            )
            AppLogger.cleanup.info("Removed privacy file: \(url.path)")
            return (true, sizeBytes, nil)
        } catch {
            let errorMsg = "Failed to remove \(url.lastPathComponent): \(error.localizedDescription)"
            DeletionLogManager.shared.log(
                sourceModule: "Privacy",
                path: url.path,
                sizeBytes: sizeBytes,
                destination: .permanent,
                isSuccess: false,
                errorMessage: errorMsg
            )
            AppLogger.cleanup.error("\(errorMsg)")
            return (false, 0, errorMsg)
        }
    }

    // MARK: - Cleaning Selected Items
    public func clearSelected() {
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
    
    /// Synchronously cleans selected privacy items and returns accurate stats
    public func performSynchronousClean() -> (reclaimedBytes: Int64, filesCount: Int, errorsCount: Int) {
        let isDryRun = DryRunManager.shared.isEnabled
        var totalReclaimed: Int64 = 0
        var totalFilesCleaned: Int = 0
        var errors: [String] = []
        
        for item in self.items where item.isEnabled && item.isAvailable {
            if isDryRun {
                DryRunManager.shared.logSimulation(action: "Clean Privacy Trace", target: item.title)
                totalReclaimed += item.sizeBytes
                totalFilesCleaned += item.fileCount
                continue
            }
            
            if item.browser == .firefox {
                let (bytes, files, errs) = self.clearFirefoxItem(item: item)
                totalReclaimed += bytes
                totalFilesCleaned += files
                errors.append(contentsOf: errs)
            } else {
                for relPath in item.relativePaths {
                    let fullURL = self.home.appendingPathComponent(relPath)
                    let path = fullURL.path
                    
                    if PathProtection.isProtected(url: fullURL) {
                        AppLogger.security.warning("Skipping protected privacy path: \(path)")
                        continue
                    }
                    
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            if let contents = try? FileManager.default.contentsOfDirectory(at: fullURL, includingPropertiesForKeys: [.fileSizeKey]) {
                                for file in contents {
                                    let result = self.safelyDelete(url: file, itemTitle: item.title)
                                    if result.success {
                                        totalReclaimed += result.reclaimed
                                        totalFilesCleaned += 1
                                    } else if let err = result.error {
                                        errors.append(err)
                                    }
                                }
                            }
                        } else {
                            let result = self.safelyDelete(url: fullURL, itemTitle: item.title)
                            if result.success {
                                totalReclaimed += result.reclaimed
                                totalFilesCleaned += 1
                            } else if let err = result.error {
                                errors.append(err)
                            }
                        }
                    }
                }
            }
        }
        
        // Restart sharedfilelistd if recent items cleared (skip if dry-run)
        if !isDryRun && self.items.contains(where: { $0.browser == .recentItems && $0.isEnabled }) {
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["sharedfilelistd"]
            try? killTask.run()
            killTask.waitUntilExit()
        }
        
        DispatchQueue.main.async {
            self.deletionErrors = errors
            self.lastErrorsCount = errors.count
        }
        
        return (totalReclaimed, totalFilesCleaned, errors.count)
    }
    
    private func clearFirefoxItem(item: PrivacyItem) -> (reclaimedBytes: Int64, filesCount: Int, errors: [String]) {
        let profilesURL = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard let profiles = try? FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) else {
            return (0, 0, [])
        }
        
        var reclaimed: Int64 = 0
        var count = 0
        var errs: [String] = []
        
        for profile in profiles {
            var targetURLs: [URL] = []
            switch item.category {
            case .history:
                let files = ["places.sqlite", "places.sqlite-wal", "places.sqlite-shm"]
                targetURLs = files.map { profile.appendingPathComponent($0) }
            case .cookies:
                let files = ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]
                targetURLs = files.map { profile.appendingPathComponent($0) }
                targetURLs.append(profile.appendingPathComponent("storage"))
            case .downloads:
                targetURLs.append(profile.appendingPathComponent("downloads.json"))
            case .recentCache:
                let cacheURL = home.appendingPathComponent("Library/Caches/Firefox/Profiles").appendingPathComponent(profile.lastPathComponent)
                targetURLs.append(cacheURL)
            }
            
            for url in targetURLs {
                let res = safelyDelete(url: url, itemTitle: item.title)
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
