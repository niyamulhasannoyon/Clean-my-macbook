import Foundation
import AppKit

/// Manages detection and system settings redirection for macOS Full Disk Access (FDA).
/// FDA is required on macOS to inspect and clean TCC-protected directories such as
/// ~/Library/Safari, ~/Library/Mail, ~/Library/Application Support, system logs, and caches.
public final class FullDiskAccessManager: ObservableObject {
    public static let shared = FullDiskAccessManager()
    
    /// Published state indicating whether Full Disk Access is currently granted.
    @Published public var hasFullDiskAccess: Bool = false
    
    /// Controls presentation of the Full Disk Access Onboarding / Guide sheet.
    @Published public var isShowingOnboardingSheet: Bool = false
    
    /// Indicates whether a permission verification check is actively running.
    @Published public var isChecking: Bool = false
    
    /// The timestamp of the most recent access verification.
    @Published public var lastChecked: Date? = nil
    
    /// Diagnostic probe results mapping test path descriptions to their read outcome.
    @Published public var probeDiagnostics: [String: Bool] = [:]
    
    /// macOS System Settings deep-link URL for Privacy & Security > Full Disk Access.
    public static let systemSettingsFDAURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    
    private let checkQueue = DispatchQueue(label: "com.tidymac.fda.check", qos: .userInitiated)
    private var checkGeneration: UInt64 = 0
    private let probeRunner: () -> (Bool, [String: Bool])
    
    private convenience init() {
        self.init(runInitialCheck: true, observeNotifications: true, probeRunner: nil)
    }
    
    public init(
        runInitialCheck: Bool = false,
        observeNotifications: Bool = false,
        probeRunner: (() -> (Bool, [String: Bool]))? = nil
    ) {
        self.probeRunner = probeRunner ?? Self.performFDACheck
        
        if runInitialCheck {
            checkAccess()
        }
        
        if observeNotifications {
            // Automatically re-verify when the app returns to foreground
            // (e.g. after the user toggles Full Disk Access in System Settings and switches back).
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidBecomeActive),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        checkAccess()
    }
    
    /// Tests for Full Disk Access asynchronously on a background queue without blocking the main thread.
    public func checkAccess(completion: ((Bool) -> Void)? = nil) {
        let startCheckOnMain = { [weak self] in
            guard let self = self else {
                completion?(false)
                return
            }
            
            self.checkGeneration &+= 1
            let generation = self.checkGeneration
            self.isChecking = true
            let runner = self.probeRunner
            
            self.checkQueue.async { [weak self] in
                let (granted, diagnostics) = runner()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        completion?(granted)
                        return
                    }
                    
                    if self.checkGeneration == generation {
                        self.hasFullDiskAccess = granted
                        self.probeDiagnostics = diagnostics
                        self.lastChecked = Date()
                        self.isChecking = false
                    }
                    completion?(granted)
                }
            }
        }
        
        if Thread.isMainThread {
            startCheckOnMain()
        } else {
            DispatchQueue.main.async(execute: startCheckOnMain)
        }
    }
    
    /// Low-level test probing known Apple TCC-protected locations.
    /// Under macOS (Ventura, Sonoma, Sequoia), without Full Disk Access,
    /// read operations on these paths fail with Cocoa Error 257 (POSIX EPERM: Operation not permitted).
    private static func performFDACheck() -> (Bool, [String: Bool]) {
        let fm = FileManager()
        let home = fm.homeDirectoryForCurrentUser
        
        // Candidate paths protected by Apple TCC
        let testProbes: [(name: String, path: String, isFolder: Bool)] = [
            ("Safari", home.appendingPathComponent("Library/Safari").path, true),
            ("Safari Bookmarks", home.appendingPathComponent("Library/Safari/Bookmarks.plist").path, false),
            ("Mail", home.appendingPathComponent("Library/Mail").path, true),
            ("Suggestions", home.appendingPathComponent("Library/Suggestions").path, true),
            ("System TCC", "/Library/Application Support/com.apple.TCC", true)
        ]
        
        var diagnostics: [String: Bool] = [:]
        var readSuccessCount = 0
        var testedLocationsCount = 0
        
        for probe in testProbes {
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: probe.path, isDirectory: &isDir)
            guard exists else { continue }
            
            testedLocationsCount += 1
            
            if isDir.boolValue {
                do {
                    _ = try fm.contentsOfDirectory(atPath: probe.path)
                    diagnostics[probe.name] = true
                    readSuccessCount += 1
                } catch {
                    diagnostics[probe.name] = false
                }
            } else {
                do {
                    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: probe.path))
                    try handle.close()
                    diagnostics[probe.name] = true
                    readSuccessCount += 1
                } catch {
                    diagnostics[probe.name] = false
                }
            }
        }
        
        // If at least one existing protected location was successfully read, Full Disk Access is present.
        // If tested locations exist but all failed due to permissions, Full Disk Access is absent.
        let granted = (testedLocationsCount > 0 && readSuccessCount > 0)
        return (granted, diagnostics)
    }
    
    /// Opens macOS System Settings directly to Privacy & Security > Full Disk Access.
    public func openSystemSettings() {
        if !NSWorkspace.shared.open(Self.systemSettingsFDAURL) {
            // Fallback for older macOS versions or alternate deep-link
            if let fallbackURL = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(fallbackURL)
            }
        }
    }
}
