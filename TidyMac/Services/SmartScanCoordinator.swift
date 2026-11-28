import Foundation
import SwiftUI
import AppKit

@MainActor
public final class SmartScanCoordinator: ObservableObject {
    public static let shared = SmartScanCoordinator()
    
    @Published public var state: SmartScanState = .idle
    @Published public var summary: SmartScanSummary = SmartScanSummary()
    @Published public var progress: Double = 0.0
    @Published public var currentStepMessage: String = "Ready to run all-in-one Smart Scan"
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var isShowingReviewSheet: Bool = false
    @Published public var activeReviewTab: SmartScanModule = .systemJunk
    @Published public var errorMessage: String? = nil
    
    private let junkScanner = SystemJunkScanner.shared
    private let largeFilesScanner = LargeOldFilesScanner.shared
    private let privacyScanner = PrivacyScanner.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let maintenanceService = MaintenanceService.shared
    
    public init() {}
    
    // MARK: - Start Unified Smart Scan
    public func startSmartScan() async {
        guard state == .idle || state == .completed else { return }
        
        state = .scanning(step: "Initiating Smart Scan...", progress: 0.05, currentModule: .systemJunk)
        progress = 0.05
        currentStepMessage = "Preparing unified system scan..."
        summary = SmartScanSummary()
        
        let startTime = Date()
        
        // 1. Scan System Junk
        progress = 0.10
        currentStepMessage = "1/4: Scanning System Junk (User caches, system logs, trash)..."
        state = .scanning(step: currentStepMessage, progress: 0.15, currentModule: .systemJunk)
        
        await junkScanner.startScan()
        summary.junkBytes = junkScanner.totalSelectedSize
        summary.junkFilesCount = junkScanner.totalSelectedFilesCount
        summary.isJunkSelected = junkScanner.totalSelectedFilesCount > 0
        
        // 2. Scan Large & Old Files (kept unselected by default so users explicitly review personal files)
        progress = 0.40
        currentStepMessage = "2/4: Locating Large & Old Files (>100MB, archives, downloads)..."
        state = .scanning(step: currentStepMessage, progress: 0.45, currentModule: .largeFiles)
        
        await largeFilesScanner.startScan()
        summary.largeFilesFoundBytes = largeFilesScanner.totalSize
        summary.largeFilesFoundCount = largeFilesScanner.files.count
        summary.largeFilesBytes = largeFilesScanner.selectedSize
        summary.largeFilesCount = largeFilesScanner.selectedFiles.count
        summary.isLargeFilesSelected = false
        
        // 3. Scan Privacy Traces
        progress = 0.70
        currentStepMessage = "3/4: Inspecting Browser Traces & Privacy Items..."
        state = .scanning(step: currentStepMessage, progress: 0.75, currentModule: .privacy)
        
        await privacyScanner.scanAsync()
        let enabledAvailablePrivacy = privacyScanner.items.filter { $0.isEnabled && $0.isAvailable }
        let privBytes = enabledAvailablePrivacy.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let privCount = enabledAvailablePrivacy.reduce(0) { $0 + $1.fileCount }
        summary.privacyBytes = privBytes
        summary.privacyFilesCount = privCount
        summary.isPrivacySelected = privCount > 0 || privBytes > 0
        
        // 4. Performance & Hardware Analysis
        progress = 0.90
        currentStepMessage = "4/4: Evaluating Memory Pressure & Startup Routines..."
        state = .scanning(step: currentStepMessage, progress: 0.95, currentModule: .performance)
        
        performanceMonitor.refreshHardwareStats()
        performanceMonitor.fetchLaunchItems()
        
        // Actual inactive RAM from macOS VM stats (informational only, never conflated with disk space)
        summary.purgeableRAMBytes = Int64(clamping: performanceMonitor.memory.inactiveBytes)
        summary.performanceTasksCount = 1
        
        progress = 1.0
        let elapsed = Date().timeIntervalSince(startTime)
        currentStepMessage = "Smart Scan completed in \(String(format: "%.1f", elapsed))s! \(summary.formattedTotalCleanable) cleanable."
        
        // Transition to completed summary screen
        state = .completed
    }
    
    // MARK: - Execute Clean All
    public func performCleanAll() async {
        guard state == .completed else { return }
        
        let isDryRun = DryRunManager.shared.isEnabled
        state = .cleaning(step: isDryRun ? "Simulating Smart Cleanup (Dry-Run mode)..." : "Starting Smart Cleanup...", progress: 0.05)
        progress = 0.05
        
        let startTime = Date()
        var totalReclaimed: Int64 = 0
        var totalFilesCleaned: Int = 0
        var errors: Int = 0
        
        // 1. Clean System Junk
        if summary.isJunkSelected && junkScanner.totalSelectedFilesCount > 0 {
            state = .cleaning(step: isDryRun ? "[Dry-Run] Simulating System Junk cleanup..." : "Cleaning System Junk & Caches...", progress: 0.25)
            progress = 0.25
            await junkScanner.performClean()
            if let junkResult = junkScanner.lastCleanResult {
                totalReclaimed += junkResult.reclaimedBytes
                totalFilesCleaned += junkResult.reclaimedFilesCount
                errors += junkResult.errorsCount
            }
        }
        
        // 2. Clean Large Files
        if summary.isLargeFilesSelected && !largeFilesScanner.selectedFiles.isEmpty {
            state = .cleaning(step: isDryRun ? "[Dry-Run] Simulating Large Files removal..." : "Moving selected Large Files to Trash...", progress: 0.55)
            progress = 0.55
            await largeFilesScanner.moveSelectedToTrash()
            if let largeResult = largeFilesScanner.lastCleanResult {
                totalReclaimed += largeResult.reclaimedBytes
                totalFilesCleaned += largeResult.reclaimedFilesCount
                errors += largeResult.errorsCount
            }
        }
        
        // 3. Clean Privacy Traces
        if summary.isPrivacySelected {
            state = .cleaning(step: isDryRun ? "[Dry-Run] Simulating privacy cleanup..." : "Clearing browser cookies and history...", progress: 0.80)
            progress = 0.80
            
            // Check if any selected browser is currently open
            let activeBrowsers = BrowserType.allCases.filter { b in
                b != .recentItems && privacyScanner.isBrowserRunning(b) && privacyScanner.items.contains { $0.browser == b && $0.isEnabled && $0.isAvailable }
            }
            
            if !activeBrowsers.isEmpty && !isDryRun {
                AppLogger.cleanup.warning("Smart Scan: skipped privacy cleanup for active browsers to protect unsaved work: \(activeBrowsers.map { $0.rawValue })")
            } else {
                let (reclaimed, files, cleanErrors) = await privacyScanner.performCleanAsync()
                totalReclaimed += reclaimed
                totalFilesCleaned += files
                errors += cleanErrors
            }
        }
        
        // 4. Flush DNS Cache
        if summary.isPerformanceSelected {
            state = .cleaning(step: isDryRun ? "[Dry-Run] Simulating DNS cache flush..." : "Flushing DNS Cache...", progress: 0.95)
            progress = 0.95
            
            if isDryRun {
                DryRunManager.shared.logSimulation(action: "Flush DNS Cache", target: "System DNS Resolver")
            } else {
                await Task.detached(priority: .userInitiated) {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
                    proc.arguments = ["-flushcache"]
                    try? proc.run()
                    proc.waitUntilExit()
                }.value
                AppLogger.performance.info("Smart Scan: flushed DNS cache")
            }
            // Inactive RAM is memory, NOT disk storage: do not add to totalReclaimed disk bytes.
        }
        
        progress = 1.0
        let elapsed = Date().timeIntervalSince(startTime)
        
        let finalResult = CleanResult(
            reclaimedBytes: totalReclaimed,
            reclaimedFilesCount: totalFilesCleaned,
            errorsCount: errors,
            duration: elapsed,
            cleanedCategorySizes: [:],
            isDryRun: isDryRun
        )
        
        self.lastCleanResult = finalResult
        StorageModel.shared.refresh()
        
        // Show celebration
        state = .celebration
    }
    
    // MARK: - Reset to Idle
    public func reset() {
        state = .idle
        progress = 0.0
        currentStepMessage = "Ready to run all-in-one Smart Scan"
        lastCleanResult = nil
    }
}
