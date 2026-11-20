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
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? = nil
    
    private init() {
        refreshHardwareStats()
        fetchProcesses()
        fetchLaunchItems()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshHardwareStats()
            self?.fetchProcesses()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
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
        
        DispatchQueue.main.async {
            self.memory = MemoryMetrics(
                totalBytes: total,
                usedBytes: min(used, total),
                freeBytes: totalFree,
                wiredBytes: wired,
                activeBytes: active,
                inactiveBytes: inactive,
                compressedBytes: compressed
            )
        }
    }
    
    // MARK: - CPU Statistics (host_cpu_load_info)
    private func updateCPU() {
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
                
                DispatchQueue.main.async {
                    self.cpu = CPUMetrics(
                        usageRatio: min(1.0, max(0.0, totalUsage)),
                        coreCount: ProcessInfo.processInfo.activeProcessorCount,
                        userPercent: userPct * 100,
                        systemPercent: sysPct * 100,
                        idlePercent: idlePct * 100
                    )
                }
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
            
            DispatchQueue.main.async {
                self.disk = DiskMetrics(
                    totalBytes: total,
                    freeBytes: available,
                    usedBytes: used
                )
            }
        }
    }
    
    // MARK: - Top Memory-Hungry Apps (proc_pidinfo)
    public func fetchProcesses() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let myPid = ProcessInfo.processInfo.processIdentifier
            let apps = NSWorkspace.shared.runningApplications.filter { app in
                app.activationPolicy == .regular && app.processIdentifier != myPid
            }
            
            var items: [ProcessItem] = []
            
            for app in apps {
                let pid = app.processIdentifier
                var taskInfo = proc_taskinfo()
                let size = MemoryLayout<proc_taskinfo>.stride
                let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
                
                let rss = (ret == size) ? taskInfo.pti_resident_size : 0
                let name = app.localizedName ?? "App"
                let bundleId = app.bundleIdentifier ?? ""
                let icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
                
                items.append(ProcessItem(
                    pid: pid,
                    name: name,
                    bundleIdentifier: bundleId,
                    memoryBytes: rss,
                    icon: icon
                ))
            }
            
            items.sort { $0.memoryBytes > $1.memoryBytes }
            
            DispatchQueue.main.async {
                self?.topProcesses = items
            }
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
    public func fetchLaunchItems() {
        isLoadingLaunchItems = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var items: [LaunchItem] = []
            
            let home = FileManager.default.homeDirectoryForCurrentUser
            let scanLocations: [(location: LaunchItemLocation, url: URL)] = [
                (.userAgent, home.appendingPathComponent("Library/LaunchAgents")),
                (.systemAgent, URL(fileURLWithPath: "/Library/LaunchAgents")),
                (.systemDaemon, URL(fileURLWithPath: "/Library/LaunchDaemons"))
            ]
            
            for entry in scanLocations {
                guard let files = try? FileManager.default.contentsOfDirectory(at: entry.url, includingPropertiesForKeys: nil) else {
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
                    
                    let displayName = self.formatDisplayName(from: label)
                    
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
            
            DispatchQueue.main.async {
                self.launchItems = items
                self.isLoadingLaunchItems = false
            }
        }
    }
    
    private func formatDisplayName(from label: String) -> String {
        let parts = label.split(separator: ".")
        if let last = parts.last {
            let cleaned = String(last)
                .replacingOccurrences(of: "com", with: "")
                .replacingOccurrences(of: "org", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return label
    }
    
    // MARK: - Toggle Launch Item Enable / Disable
    public func toggleLaunchItem(item: LaunchItem, enable: Bool) {
        guard let index = launchItems.firstIndex(where: { $0.id == item.id }) else { return }
        launchItems[index].isToggling = true
        
        let path = item.path
        let isUserAgent = (item.location == .userAgent)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var success = false
            var newPath = path
            
            if isUserAgent {
                // User Launch Agent: Can modify directly without root
                if enable {
                    // Rename from .plist.disabled to .plist
                    if path.hasSuffix(".disabled") {
                        let target = String(path.dropLast(".disabled".count))
                        if (try? FileManager.default.moveItem(atPath: path, toPath: target)) != nil {
                            newPath = target
                            success = true
                            let p = Process()
                            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                            p.arguments = ["load", target]
                            try? p.run()
                            p.waitUntilExit()
                        }
                    } else {
                        success = true
                    }
                } else {
                    // Disable: unload and rename to .plist.disabled
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                    p.arguments = ["unload", path]
                    try? p.run()
                    p.waitUntilExit()
                    
                    let target = path + ".disabled"
                    if (try? FileManager.default.moveItem(atPath: path, toPath: target)) != nil {
                        newPath = target
                        success = true
                    }
                }
            } else {
                // System item: Requires Administrator Privileges
                let script: String
                if enable {
                    let target = path.hasSuffix(".disabled") ? String(path.dropLast(".disabled".count)) : path
                    script = "mv -f \"\(path)\" \"\(target)\" && launchctl load \"\(target)\""
                    newPath = target
                } else {
                    let target = path + ".disabled"
                    script = "launchctl unload \"\(path)\" && mv -f \"\(path)\" \"\(target)\""
                    newPath = target
                }
                
                let source = "do shell script \"\(script)\" with administrator privileges"
                var errorDict: NSDictionary?
                if let appleScript = NSAppleScript(source: source) {
                    appleScript.executeAndReturnError(&errorDict)
                    success = (errorDict == nil)
                }
            }
            
            DispatchQueue.main.async {
                guard let idx = self.launchItems.firstIndex(where: { $0.id == item.id }) else { return }
                self.launchItems[idx].isToggling = false
                if success {
                    self.launchItems[idx].isEnabled = enable
                    self.launchItems[idx].path = newPath
                } else {
                    // Revert state on failure
                    self.fetchLaunchItems()
                }
            }
        }
    }
}
