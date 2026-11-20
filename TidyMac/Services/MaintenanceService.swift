import Foundation
import SwiftUI
import AppKit

public final class MaintenanceService: ObservableObject {
    public static let shared = MaintenanceService()
    
    @Published public var tasks: [MaintenanceTask] = []
    @Published public var isRunningAny: Bool = false
    @Published public var activeTaskId: String? = nil
    
    private init() {
        setupTasks()
    }
    
    private func setupTasks() {
        self.tasks = [
            MaintenanceTask(
                id: "flush_dns",
                title: "Flush DNS Cache",
                subtitle: "Clear domain resolver cache and reload mDNSResponder",
                purpose: "macOS stores domain-to-IP mappings locally. Outdated DNS caches cause website load errors, slow connection handshakes, or 404s after DNS record updates. This command flushes the system resolver and signals mDNSResponder to refresh DNS tables immediately.",
                whenToUse: "Run when experiencing website timeouts, unable to reach newly configured domains, or facing sudden internet latency.",
                terminalCommand: "/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder",
                requiresAdmin: true,
                icon: "network",
                tintColor: .blue
            ),
            MaintenanceTask(
                id: "rebuild_spotlight",
                title: "Rebuild Spotlight Index (mdutil)",
                subtitle: "Force a clean metadata re-index on the root volume",
                purpose: "Spotlight catalogues documents, emails, and applications for instant query speed. If searches in Spotlight, Alfred, or Raycast fail to find existing files, the metadata database may be corrupted. Invoking 'mdutil -E /' flushes corrupted index tables and triggers a complete background re-indexing.",
                whenToUse: "Run when files or apps do not appear in Spotlight queries, or search queries return inaccurate results.",
                terminalCommand: "/usr/bin/mdutil -E /",
                requiresAdmin: true,
                icon: "magnifyingglass.circle.fill",
                tintColor: .purple
            ),
            MaintenanceTask(
                id: "reindex_launch_services",
                title: "Reindex Launch Services (lsregister)",
                subtitle: "Rebuild application bindings and repair 'Open With' contextual menu",
                purpose: "Launch Services tracks default application bindings, file type associations, and contextual menu handlers. Using 'lsregister -kill -r' rebuilds the database, removes ghost uninstalled apps, fixes duplicated entries in the 'Open With' right-click menu, and restarts Finder.",
                whenToUse: "Run if you see duplicate apps in the 'Open With' menu, generic blank document icons, or file type misassociations.",
                terminalCommand: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && /usr/bin/killall Finder",
                requiresAdmin: false,
                icon: "macwindow.badge.plus",
                tintColor: .teal
            ),
            MaintenanceTask(
                id: "repair_disk_permissions",
                title: "Repair Permissions & Verify Volume",
                subtitle: "Reset user home folder ACLs and run APFS First Aid check",
                purpose: "Modern macOS systems utilize a cryptographically sealed, immutable read-only APFS system volume protected by SIP. This task resets user permissions and Access Control Lists (ACLs) on your home folder with 'diskutil resetUserPermissions' and verifies volume structural health.",
                whenToUse: "Run when facing 'Permission Denied' errors in your home folder or after restoring files from backups.",
                terminalCommand: "/usr/sbin/diskutil resetUserPermissions / $(id -u) && /usr/sbin/diskutil verifyVolume /",
                requiresAdmin: true,
                icon: "lock.open.trianglebadge.exclamationmark",
                tintColor: .orange
            ),
            MaintenanceTask(
                id: "periodic_scripts",
                title: "Run Periodic Maintenance Scripts",
                subtitle: "Trigger daily, weekly, and monthly BSD Unix maintenance routines",
                purpose: "macOS inherits traditional BSD maintenance scripts configured to run daily, weekly, and monthly during middle-of-the-night hours. If your Mac is often asleep or turned off overnight, these jobs are missed. This command immediately executes daily, weekly, and monthly scripts to rotate old log files, clean temporary crash dumps, and vacuum maintenance databases.",
                whenToUse: "Run once a month or whenever performing comprehensive system tune-ups to keep Unix subsystems clean.",
                terminalCommand: "/usr/sbin/periodic daily weekly monthly",
                requiresAdmin: true,
                icon: "clock.arrow.2.circlepath",
                tintColor: .pink
            )
        ]
    }
    
    // MARK: - Run Single Task
    public func runTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[index]
        
        tasks[index].status = .running
        tasks[index].outputLog = "Starting execution...\nCommand: \(task.terminalCommand)\n"
        isRunningAny = true
        activeTaskId = id
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (success, output, cancelled) = self.executeCommand(
                command: task.terminalCommand,
                asAdmin: task.requiresAdmin
            )
            
            DispatchQueue.main.async {
                guard let idx = self.tasks.firstIndex(where: { $0.id == id }) else { return }
                self.tasks[idx].lastRun = Date()
                self.tasks[idx].outputLog += output
                
                if cancelled {
                    self.tasks[idx].status = .cancelled
                    self.tasks[idx].outputLog += "\n[Authorization Cancelled by User]"
                } else if success {
                    self.tasks[idx].status = .success(message: "Task completed successfully!")
                    self.tasks[idx].outputLog += "\n[Status: SUCCESS]"
                } else {
                    self.tasks[idx].status = .failed(error: output.isEmpty ? "Unknown execution error" : output)
                    self.tasks[idx].outputLog += "\n[Status: FAILED]"
                }
                
                self.isRunningAny = false
                self.activeTaskId = nil
            }
        }
    }
    
    // MARK: - Run All Tasks Sequentially
    public func runAllTasks() {
        guard !isRunningAny else { return }
        isRunningAny = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for task in self.tasks {
                DispatchQueue.main.async {
                    if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[idx].status = .running
                        self.tasks[idx].outputLog = "Starting execution...\nCommand: \(task.terminalCommand)\n"
                        self.activeTaskId = task.id
                    }
                }
                
                let (success, output, cancelled) = self.executeCommand(
                    command: task.terminalCommand,
                    asAdmin: task.requiresAdmin
                )
                
                var shouldStop = false
                DispatchQueue.main.sync {
                    if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[idx].lastRun = Date()
                        self.tasks[idx].outputLog += output
                        
                        if cancelled {
                            self.tasks[idx].status = .cancelled
                            self.tasks[idx].outputLog += "\n[Authorization Cancelled by User]"
                            shouldStop = true
                        } else if success {
                            self.tasks[idx].status = .success(message: "Task completed successfully!")
                            self.tasks[idx].outputLog += "\n[Status: SUCCESS]"
                        } else {
                            self.tasks[idx].status = .failed(error: output)
                            self.tasks[idx].outputLog += "\n[Status: FAILED]"
                        }
                    }
                }
                
                if shouldStop {
                    break
                }
            }
            
            DispatchQueue.main.async {
                self.isRunningAny = false
                self.activeTaskId = nil
            }
        }
    }
    
    // MARK: - Command Execution
    private func executeCommand(command: String, asAdmin: Bool) -> (success: Bool, output: String, cancelled: Bool) {
        if asAdmin {
            // Use AppleScript for elevated administrator prompt
            let escapedCommand = command
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            
            let scriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"
            var errorDict: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource) else {
                return (false, "Failed to initialize AppleScript engine", false)
            }
            
            let descriptor = script.executeAndReturnError(&errorDict)
            if let error = errorDict {
                let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Execution error"
                if code == -128 { // User canceled password dialog
                    return (false, "User canceled authorization prompt", true)
                }
                return (false, "Error (\(code)): \(msg)", false)
            }
            
            let output = descriptor.stringValue ?? "Command executed without output."
            return (true, output, false)
        } else {
            // Standard user process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let success = process.terminationStatus == 0
                return (success, output.isEmpty ? "Done." : output, false)
            } catch {
                return (false, "Failed to launch process: \(error.localizedDescription)", false)
            }
        }
    }
}
