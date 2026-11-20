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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var totalReclaimed: Int64 = 0
            
            for item in self.items where item.isEnabled {
                totalReclaimed += item.sizeBytes
                
                if item.browser == .firefox {
                    self.clearFirefoxItem(item: item)
                } else {
                    for relPath in item.relativePaths {
                        let fullURL = self.home.appendingPathComponent(relPath)
                        let path = fullURL.path
                        
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                            if isDir.boolValue {
                                if let contents = try? FileManager.default.contentsOfDirectory(at: fullURL, includingPropertiesForKeys: nil) {
                                    for file in contents {
                                        try? FileManager.default.removeItem(at: file)
                                    }
                                }
                            } else {
                                try? FileManager.default.removeItem(at: fullURL)
                            }
                        }
                    }
                }
            }
            
            // Restart sharedfilelistd if recent items cleared
            if self.items.contains(where: { $0.browser == .recentItems && $0.isEnabled }) {
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                killTask.arguments = ["sharedfilelistd"]
                try? killTask.run()
                killTask.waitUntilExit()
            }
            
            DispatchQueue.main.async {
                self.lastReclaimedBytes = totalReclaimed
                self.isClearing = false
                self.showSuccessAlert = true
                self.scan()
            }
        }
    }
    
    private func clearFirefoxItem(item: PrivacyItem) {
        let profilesURL = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard let profiles = try? FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for profile in profiles {
            switch item.category {
            case .history:
                let files = ["places.sqlite", "places.sqlite-wal", "places.sqlite-shm"]
                for f in files {
                    try? FileManager.default.removeItem(at: profile.appendingPathComponent(f))
                }
            case .cookies:
                let files = ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]
                for f in files {
                    try? FileManager.default.removeItem(at: profile.appendingPathComponent(f))
                }
                let storageURL = profile.appendingPathComponent("storage")
                try? FileManager.default.removeItem(at: storageURL)
            case .downloads:
                let f = profile.appendingPathComponent("downloads.json")
                try? FileManager.default.removeItem(at: f)
            case .recentCache:
                let cacheURL = home.appendingPathComponent("Library/Caches/Firefox/Profiles").appendingPathComponent(profile.lastPathComponent)
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }
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
