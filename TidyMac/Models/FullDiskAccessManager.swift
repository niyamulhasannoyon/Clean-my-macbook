import Foundation
import AppKit

/// Manages detection and system settings redirection for macOS Full Disk Access (FDA).
/// FDA is required on macOS to inspect and clean TCC-protected directories such as
/// ~/Library/Safari, ~/Library/Mail, ~/Library/Application Support, system logs, and caches.
final class FullDiskAccessManager: ObservableObject {
    static let shared = FullDiskAccessManager()
    
    /// Published state indicating whether Full Disk Access is currently granted.
    @Published var hasFullDiskAccess: Bool = false
    
    /// Controls presentation of the Full Disk Access Onboarding / Guide sheet.
    @Published var isShowingOnboardingSheet: Bool = false
    
    /// Indicates whether a permission verification check is actively running.
    @Published var isChecking: Bool = false
    
    /// The timestamp of the most recent access verification.
    @Published var lastChecked: Date? = nil
    
    /// Diagnostic probe results mapping test path descriptions to their read outcome.
    @Published var probeDiagnostics: [String: Bool] = [:]
    
    /// macOS System Settings deep-link URL for Privacy & Security > Full Disk Access.
    static let systemSettingsFDAURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    
    private init() {
        // Perform initial check on launch
        checkAccess()
        
        // Automatically re-verify when the app returns to foreground
        // (e.g. after the user toggles Full Disk Access in System Settings and switches back).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidBecomeActive() {
        checkAccess()
    }
    
    /// Tests for Full Disk Access by attempting to read protected user and system locations.
    /// Returns true if Full Disk Access is verified.
    @discardableResult
    func checkAccess() -> Bool {
        isChecking = true
        let (granted, diagnostics) = performFDACheck()
        
        DispatchQueue.main.async {
            self.hasFullDiskAccess = granted
            self.probeDiagnostics = diagnostics
            self.lastChecked = Date()
            self.isChecking = false
        }
        
        return granted
    }
    
    /// Low-level test probing known Apple TCC-protected locations.
    /// Under macOS (Ventura, Sonoma, Sequoia), without Full Disk Access,
    /// read operations on these paths fail with Cocoa Error 257 (POSIX EPERM: Operation not permitted).
    private func performFDACheck() -> (Bool, [String: Bool]) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
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
            let exists = FileManager.default.fileExists(atPath: probe.path, isDirectory: &isDir)
            guard exists else { continue }
            
            testedLocationsCount += 1
            
            if isDir.boolValue {
                do {
                    _ = try FileManager.default.contentsOfDirectory(atPath: probe.path)
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
    func openSystemSettings() {
        if !NSWorkspace.shared.open(Self.systemSettingsFDAURL) {
            // Fallback for older macOS versions or alternate deep-link
            if let fallbackURL = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(fallbackURL)
            }
        }
    }
}
