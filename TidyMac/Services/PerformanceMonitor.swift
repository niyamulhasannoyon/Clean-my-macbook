import Foundation
import SwiftUI
import AppKit
import Darwin

public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    @Published public var memory: MemoryMetrics = MemoryMetrics()
    @Published public var cpu: CPUMetrics = CPUMetrics()
    @Published public var disk: DiskMetrics = DiskMetrics()
    @Published public var topProcesses: [ProcessItem] = []
    @Published public var launchItems: [LaunchItem] = []
    @Published public var isLoadingLaunchItems: Bool = false
    @Published public var statusMessage: String? = nil
    
    private var timer: Timer?
    private var isMonitoringRequested: Bool = false
    private let monitoringLock = NSLock()
    private var fetchGeneration: UInt64 = 0
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? = nil
    
    public var isMonitoring: Bool {
        timer != nil
    }
    
    private init() {
        refreshHardwareStats()
        fetchProcesses()
        fetchLaunchItems()
    }
    
    deinit {
        monitoringLock.lock()
        isMonitoringRequested = false
        monitoringLock.unlock()
        let activeTimer = timer
        timer = nil
        if let activeTimer {
            if Thread.isMainThread {
                activeTimer.invalidate()
            } else {
                DispatchQueue.main.async {
                    activeTimer.invalidate()
                }
            }
        }
    }
    
    public func startMonitoring() {
        monitoringLock.lock()
        isMonitoringRequested = true
        monitoringLock.unlock()
        
        let startOnMain = { [weak self] in
            guard let self = self else { return }
            self.monitoringLock.lock()
            let shouldStart = self.isMonitoringRequested
            self.monitoringLock.unlock()
            guard shouldStart, self.timer == nil else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.refreshHardwareStats()
                self?.fetchProcesses()
            }
        }
        
        if Thread.isMainThread {
            startOnMain()
        } else {
            DispatchQueue.main.async(execute: startOnMain)
        }
    }
    
    public func stopMonitoring() {
        monitoringLock.lock()
        isMonitoringRequested = false
        monitoringLock.unlock()
        
        let stopOnMain = { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
        
        if Thread.isMainThread {
            stopOnMain()
        } else {
            DispatchQueue.main.async(execute: stopOnMain)
        }
    }
    
    // MARK: - Hardware Metrics Refresh
    public func refreshHardwareStats() {
        updateMemory()
        updateCPU()
        updateDisk()
    }
    
    // MARK: - Memory Statistics (host_statistics64)
    private func updateMemory() {
        let total = ProcessInfo.processInfo.physicalMemory
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64()
        
        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize
        
        let used = wired + active + compressed
        let totalFree = free + inactive
        
        let metrics = MemoryMetrics(
            totalBytes: total,
            usedBytes: min(used, total),
            freeBytes: totalFree,
            wiredBytes: wired,
            activeBytes: active,
            inactiveBytes: inactive,
            compressedBytes: compressed
        )
        if Thread.isMainThread {
            self.memory = metrics
        } else {
            DispatchQueue.main.async {
                self.memory = metrics
            }
        }
    }
    
    // MARK: - CPU Statistics (host_cpu_load_info)
    private func updateCPU() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateCPU()
            }
            return
        }
        
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()
        
        let kerr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return }
        
        let user = cpuLoad.cpu_ticks.0
        let system = cpuLoad.cpu_ticks.1
        let idle = cpuLoad.cpu_ticks.2
        let nice = cpuLoad.cpu_ticks.3
        
        if let prev = previousCPUTicks {
            let userDelta = Double(user >= prev.user ? user - prev.user : 0)
            let systemDelta = Double(system >= prev.system ? system - prev.system : 0)
            let idleDelta = Double(idle >= prev.idle ? idle - prev.idle : 0)
            let niceDelta = Double(nice >= prev.nice ? nice - prev.nice : 0)
            
            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
            if totalDelta > 0 {
                let userPct = (userDelta + niceDelta) / totalDelta
                let sysPct = systemDelta / totalDelta
                let idlePct = idleDelta / totalDelta
                let totalUsage = userPct + sysPct
                
                self.cpu = CPUMetrics(
                    usageRatio: min(1.0, max(0.0, totalUsage)),
                    coreCount: ProcessInfo.processInfo.activeProcessorCount,
                    userPercent: userPct * 100,
                    systemPercent: sysPct * 100,
                    idlePercent: idlePct * 100
                )
            }
        }
        
        previousCPUTicks = (user, system, idle, nice)
    }
    
    // MARK: - Disk Usage
    private func updateDisk() {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            let used = max(0, total - available)
            let metrics = DiskMetrics(
                totalBytes: total,
                freeBytes: available,
                usedBytes: used
            )
            
            if Thread.isMainThread {
                self.disk = metrics
            } else {
                DispatchQueue.main.async {
                    self.disk = metrics
                }
            }
        }
    }
    
    // MARK: - Top Memory-Hungry Apps (proc_pidinfo)
    private struct RunningAppSnapshot {
        let pid: pid_t
        let name: String
        let bundleIdentifier: String
        let icon: NSImage
    }
    
    @MainActor
    private static func captureRunningAppSnapshots() -> [RunningAppSnapshot] {
        let myPid = ProcessInfo.processInfo.processIdentifier
        let defaultIcon = NSWorkspace.shared.icon(for: .application)
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular && app.processIdentifier != myPid else {
                return nil
            }
            return RunningAppSnapshot(
                pid: app.processIdentifier,
                name: app.localizedName ?? "App",
                bundleIdentifier: app.bundleIdentifier ?? "",
                icon: app.icon ?? defaultIcon
            )
        }
    }
    
    public func fetchProcesses() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let snapshots = Self.captureRunningAppSnapshots()
            let pids = snapshots.map { $0.pid }
            
            let memoryByPid: [pid_t: UInt64] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInteractive).async {
                    var result: [pid_t: UInt64] = [:]
                    result.reserveCapacity(pids.count)
                    
                    for pid in pids {
                        var taskInfo = proc_taskinfo()
                        let size = MemoryLayout<proc_taskinfo>.stride
                        let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
                        result[pid] = (ret == size) ? taskInfo.pti_resident_size : 0
                    }
                    
                    continuation.resume(returning: result)
                }
            }
            
            var items = snapshots.map { app in
                ProcessItem(
                    pid: app.pid,
                    name: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    memoryBytes: memoryByPid[app.pid] ?? 0,
                    icon: app.icon
                )
            }
            
            items.sort { $0.memoryBytes > $1.memoryBytes }
            self.topProcesses = items
        }
    }
    
    // MARK: - Quit App
    public func quitApp(process: ProcessItem, force: Bool = false) {
        if let app = NSRunningApplication(processIdentifier: process.pid) {
            if force {
                app.forceTerminate()
            } else {
                app.terminate()
            }
        }
        
        // Refresh immediately after 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchProcesses()
            self?.refreshHardwareStats()
        }
    }
    
    // MARK: - Startup & Launch Agents Manager
    public static func scanLaunchItems(
        in scanLocations: [(location: LaunchItemLocation, url: URL)],
        fileManager: FileManager = .default
    ) -> [LaunchItem] {
        var items: [LaunchItem] = []
        
        for entry in scanLocations {
            guard let files = try? fileManager.contentsOfDirectory(at: entry.url, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for file in files {
                let filename = file.lastPathComponent
                guard filename.hasSuffix(".plist") || filename.hasSuffix(".plist.disabled") else {
                    continue
                }
                
                let isDisabledByExtension = filename.hasSuffix(".disabled")
                var isEnabled = !isDisabledByExtension
                var label = filename.replacingOccurrences(of: ".plist.disabled", with: "").replacingOccurrences(of: ".plist", with: "")
                var program = ""
                
                if let data = try? Data(contentsOf: file),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    if let plistLabel = plist["Label"] as? String {
                        label = plistLabel
                    }
                    if let disabledVal = plist["Disabled"] as? Bool, disabledVal == true {
                        isEnabled = false
                    }
                    if let prog = plist["Program"] as? String {
                        program = prog
                    } else if let args = plist["ProgramArguments"] as? [String], let first = args.first {
                        program = first
                    }
                }
                
                let displayName = Self.formatDisplayName(from: label)
                
                items.append(LaunchItem(
                    id: file.path,
                    label: label,
                    displayName: displayName,
                    path: file.path,
                    location: entry.location,
                    program: program.isEmpty ? file.path : program,
                    isEnabled: isEnabled
                ))
            }
        }
        
        items.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return items
    }
    
    public func fetchLaunchItems() {
        let beginOnMain: () -> UInt64 = { [weak self] in
            guard let self = self else { return 0 }
            self.fetchGeneration &+= 1
            self.isLoadingLaunchItems = true
            return self.fetchGeneration
        }
        
        if Thread.isMainThread {
            let generation = beginOnMain()
            dispatchLaunchItemScan(generation: generation)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let generation = beginOnMain()
                self.dispatchLaunchItemScan(generation: generation)
            }
        }
    }
    
    private func dispatchLaunchItemScan(generation: UInt64) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let scanLocations: [(location: LaunchItemLocation, url: URL)] = [
                (.userAgent, home.appendingPathComponent("Library/LaunchAgents")),
                (.systemAgent, URL(fileURLWithPath: "/Library/LaunchAgents")),
                (.systemDaemon, URL(fileURLWithPath: "/Library/LaunchDaemons"))
            ]
            
            let items = Self.scanLaunchItems(in: scanLocations)
            
            DispatchQueue.main.async {
                guard self.fetchGeneration == generation else { return }
                self.launchItems = items
                self.isLoadingLaunchItems = false
            }
        }
    }
    
    public static func formatDisplayName(from label: String) -> String {
        let parts = label.split(separator: ".")
        if let last = parts.last {
            let cleaned = String(last)
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return label
    }
    
    // MARK: - Safe Shell & Path Helpers (Delegated to SecurityEscaping)
    public static func isValidLaunchItemPath(_ path: String) -> Bool {
        return SecurityEscaping.isValidLaunchItemPath(path)
    }
    
    public static func posixShellQuote(_ string: String) -> String {
        return SecurityEscaping.posixShellQuote(string)
    }
    
    public static func appleScriptStringEscape(_ string: String) -> String {
        return SecurityEscaping.appleScriptStringEscape(string)
    }
    
    public static func buildSystemLaunchItemToggleCommand(
        path: String,
        enable: Bool
    ) -> (shellCommand: String, targetPath: String, didRename: Bool) {
        let quotedPath = posixShellQuote(path)
        if enable {
            if path.hasSuffix(".disabled") {
                let target = String(path.dropLast(".disabled".count))
                let quotedTarget = posixShellQuote(target)
                let command = "mv -f \(quotedPath) \(quotedTarget) && /bin/launchctl load \(quotedTarget)"
                return (command, target, true)
            } else {
                let command = "/bin/launchctl load \(quotedPath)"
                return (command, path, false)
            }
        } else {
            if path.hasSuffix(".disabled") {
                let command = "/bin/launchctl unload \(quotedPath) || true"
                return (command, path, false)
            } else {
                let target = path + ".disabled"
                let quotedTarget = posixShellQuote(target)
                let command = "/bin/launchctl unload \(quotedPath) || true; mv -f \(quotedPath) \(quotedTarget)"
                return (command, target, true)
            }
        }
    }
    
    // MARK: - Toggle Launch Item Enable / Disable
    public func toggleLaunchItem(item: LaunchItem, enable: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.toggleLaunchItem(item: item, enable: enable)
            }
            return
        }
        
        guard let index = launchItems.firstIndex(where: { $0.id == item.id }) else { return }
        let path = item.path
        
        if !PerformanceMonitor.isValidLaunchItemPath(path) {
            AppLogger.security.error("Blocked launch item toggle for unsafe path: \(path)")
            launchItems[index].isToggling = false
            fetchLaunchItems()
            return
        }
        
        if DryRunManager.shared.isEnabled {
            DryRunManager.shared.logSimulation(
                action: enable ? "Enable Launch Item" : "Disable Launch Item",
                target: path
            )
            launchItems[index].isToggling = false
            launchItems[index].isEnabled = enable
            statusMessage = "[Dry-Run] Simulated \(enable ? "enabling" : "disabling") '\(item.displayName)'."
            return
        }
        
        launchItems[index].isToggling = true
        let isUserAgent = (item.location == .userAgent)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var success = false
            var newPath = path
            var didRename = false
            
            if isUserAgent {
                // User Launch Agent: Can modify directly without root
                if enable {
                    if path.hasSuffix(".disabled") {
                        let target = String(path.dropLast(".disabled".count))
                        if (try? FileManager.default.moveItem(atPath: path, toPath: target)) != nil {
                            newPath = target
                            didRename = true
                            success = true
                            let p = Process()
                            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                            p.arguments = ["load", target]
                            p.standardOutput = FileHandle.nullDevice
                            p.standardError = FileHandle.nullDevice
                            try? p.run()
                            p.waitUntilExit()
                        }
                    } else {
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                        p.arguments = ["load", path]
                        p.standardOutput = FileHandle.nullDevice
                        p.standardError = FileHandle.nullDevice
                        do {
                            try p.run()
                            p.waitUntilExit()
                            success = (p.terminationStatus == 0)
                        } catch {
                            success = false
                        }
                    }
                } else {
                    // Disable: unload (ignoring already-unloaded failure) and rename to .plist.disabled
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                    p.arguments = ["unload", path]
                    p.standardOutput = FileHandle.nullDevice
                    p.standardError = FileHandle.nullDevice
                    try? p.run()
                    p.waitUntilExit()
                    
                    if path.hasSuffix(".disabled") {
                        success = true
                    } else {
                        let target = path + ".disabled"
                        if (try? FileManager.default.moveItem(atPath: path, toPath: target)) != nil {
                            newPath = target
                            didRename = true
                            success = true
                        }
                    }
                }
            } else {
                // System item: Requires Administrator Privileges
                let commandPlan = Self.buildSystemLaunchItemToggleCommand(path: path, enable: enable)
                let shellCommand = commandPlan.shellCommand
                let target = commandPlan.targetPath
                didRename = commandPlan.didRename
                newPath = target
                
                let source = "do shell script \"\(PerformanceMonitor.appleScriptStringEscape(shellCommand))\" with administrator privileges"
                var errorDict: NSDictionary?
                if let appleScript = NSAppleScript(source: source) {
                    appleScript.executeAndReturnError(&errorDict)
                    success = (errorDict == nil)
                    if let err = errorDict {
                        AppLogger.security.warning("AppleScript launch item toggle error: \(err)")
                    } else {
                        AppLogger.security.info("Successfully toggled system launch item: \(target) (enable: \(enable))")
                    }
                }
            }
            
            DispatchQueue.main.async {
                if let idx = self.launchItems.firstIndex(where: { $0.id == item.id }) {
                    self.launchItems[idx].isToggling = false
                    if success {
                        self.launchItems[idx].isEnabled = enable
                        self.launchItems[idx].path = newPath
                    }
                }
                if !success || didRename {
                    self.fetchLaunchItems()
                }
            }
        }
    }
}
