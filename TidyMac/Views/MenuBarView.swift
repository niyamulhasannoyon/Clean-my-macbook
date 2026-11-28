import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

struct MenuBarView: View {
    @ObservedObject var storage = StorageModel.shared
    @ObservedObject var fdaManager = FullDiskAccessManager.shared
    @ObservedObject var performanceMonitor = PerformanceMonitor.shared
    @ObservedObject var junkScanner = SystemJunkScanner.shared
    @ObservedObject var dryRun = DryRunManager.shared
    @State private var cleanFeedback: String? = nil
    @State private var cleanFeedbackIsError: Bool = false
    @State private var isCleaning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                TidyMacAppIconView(size: 30, shadowRadius: 2)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("TidyMac")
                        .font(.system(size: 13, weight: .bold))
                    Text("System Status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(fdaManager.hasFullDiskAccess ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(fdaManager.hasFullDiskAccess ? "Protected" : "Access Needed")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((fdaManager.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.12))
                .clipShape(Capsule())
            }
            
            Divider()
            
            // Storage Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Macintosh HD", systemImage: "internaldrive.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(storage.percentUsedString) Used")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: storage.usedFraction)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text("\(storage.formattedFree) Free")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Total: \(storage.formattedTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            // Memory Section
            VStack(alignment: .leading, spacing: 6) {
                let clampedMemoryRatio = min(1.0, max(0.0, performanceMonitor.memory.usageRatio))
                HStack {
                    Label("RAM Usage", systemImage: "memorychip")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.0f%% Used", clampedMemoryRatio * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: clampedMemoryRatio)
                    .progressViewStyle(.linear)
                    .tint(.purple)
                
                HStack {
                    Text("\(performanceMonitor.memory.formattedUsed) of \(performanceMonitor.memory.formattedTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(performanceMonitor.memory.formattedFree) Available")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            if let feedback = cleanFeedback {
                HStack(spacing: 6) {
                    Image(systemName: cleanFeedbackIsError ? "exclamationmark.triangle.fill" : (dryRun.isEnabled ? "shield.checkered" : "checkmark.circle.fill"))
                        .foregroundColor(cleanFeedbackIsError ? .orange : (dryRun.isEnabled ? .orange : .green))
                    Text(feedback)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }
            
            // Quick action buttons
            VStack(spacing: 8) {
                if !fdaManager.hasFullDiskAccess {
                    Button(action: {
                        openMainWindow()
                        fdaManager.isShowingOnboardingSheet = true
                    }) {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Full Disk Access Required")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    let isBusy = isCleaning || junkScanner.isScanning || junkScanner.isCleaning
                    Button(action: quickClean) {
                        HStack {
                            if isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: dryRun.isEnabled ? "shield.checkered" : "trash")
                            }
                            Text(quickCleanButtonTitle)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(dryRun.isEnabled ? Color.orange : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                }
                
                HStack(spacing: 8) {
                    Button(action: openMainWindow) {
                        HStack {
                            Image(systemName: "macwindow")
                            Text("Open TidyMac")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: quitApp) {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear {
            storage.refresh()
            performanceMonitor.refreshHardwareStats()
        }
    }
    
    private var quickCleanButtonTitle: String {
        if junkScanner.isScanning {
            return "Scanning System Junk..."
        }
        if isCleaning || junkScanner.isCleaning {
            return dryRun.isEnabled ? "Simulating Cleanup..." : "Cleaning System..."
        }
        if junkScanner.totalSelectedSize > 0 {
            return dryRun.isEnabled
                ? "Quick Clean (\(junkScanner.formattedTotalSelectedSize)) [Dry-Run]"
                : "Quick Clean (\(junkScanner.formattedTotalSelectedSize))"
        }
        return dryRun.isEnabled ? "Quick Clean (Dry-Run)" : "Quick Clean System Junk"
    }
    
    private func quickClean() {
        guard !isCleaning && !junkScanner.isScanning && !junkScanner.isCleaning else { return }
        isCleaning = true
        cleanFeedback = nil
        cleanFeedbackIsError = false
        
        Task {
            if junkScanner.categories.allSatisfy({ $0.items.isEmpty }) {
                await junkScanner.startScan()
            }
            
            guard junkScanner.totalSelectedFilesCount > 0 else {
                isCleaning = false
                cleanFeedback = junkScanner.totalFoundFilesCount > 0
                    ? "No junk items selected for cleanup"
                    : "System is already clean!"
                storage.refresh()
                performanceMonitor.refreshHardwareStats()
                return
            }
            
            await junkScanner.performClean()
            isCleaning = false
            
            if let result = junkScanner.lastCleanResult {
                if result.isDryRun {
                    cleanFeedback = "[Dry-Run] Simulated \(result.formattedReclaimedSize) (\(result.reclaimedFilesCount) items)"
                } else if result.reclaimedBytes > 0 {
                    cleanFeedback = result.errorsCount > 0
                        ? "Freed \(result.formattedReclaimedSize) (\(result.errorsCount) skipped)"
                        : "Freed \(result.formattedReclaimedSize) of system junk!"
                } else if result.errorsCount > 0 {
                    cleanFeedbackIsError = true
                    cleanFeedback = "Cleanup failed for \(result.errorsCount) item(s)"
                } else {
                    cleanFeedback = "System is already clean!"
                }
            }
            
            storage.refresh()
            performanceMonitor.refreshHardwareStats()
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
