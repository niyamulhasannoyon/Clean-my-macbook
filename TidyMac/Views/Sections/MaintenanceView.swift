import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

struct MaintenanceView: View {
    @ObservedObject private var service = MaintenanceService.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    
    @State private var expandedLogs: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                HeaderBannerView(
                    item: .maintenance,
                    statusText: "\(service.tasks.count) Maintenance Routines",
                    statusColor: .pink
                )
                
                // Dry-Run Notice
                DryRunBanner()
                
                // Explanatory Banner
                HStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundColor(.pink)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("System-Level Maintenance & Optimization")
                            .font(.system(size: 14, weight: .semibold))
                        Text("These scripts optimize macOS system databases, caches, and indexes. Tasks marked with an admin badge will request your standard macOS Touch ID or admin password before executing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(Color.pink.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                )
                
                // Tasks List
                VStack(spacing: 16) {
                    ForEach(service.tasks) { task in
                        VStack(alignment: .leading, spacing: 12) {
                            // Top Row: Icon, Title, Badges, Action Button
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(task.tintColor.opacity(0.14))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: task.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(task.tintColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(task.title)
                                            .font(.system(size: 15, weight: .bold))
                                        
                                        if task.requiresAdmin {
                                            HStack(spacing: 3) {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 9))
                                                Text("Admin Required")
                                                    .font(.system(size: 10, weight: .semibold))
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .clipShape(Capsule())
                                        } else {
                                            HStack(spacing: 3) {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 9))
                                                Text("User Mode")
                                                    .font(.system(size: 10, weight: .semibold))
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                        }
                                    }
                                    
                                    Text(task.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Status / Run Button
                                switch task.status {
                                case .idle:
                                    Button("Run Task") {
                                        service.runTask(id: task.id)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(task.tintColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .buttonStyle(.plain)
                                    .disabled(service.isRunningAny)
                                    
                                case .running:
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Executing...")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    
                                case .success:
                                    HStack(spacing: 8) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Completed")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.12))
                                        .clipShape(Capsule())
                                        
                                        Button("Rerun") {
                                            service.runTask(id: task.id)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .buttonStyle(.plain)
                                        .disabled(service.isRunningAny)
                                    }
                                    
                                case .failed(let err):
                                    HStack(spacing: 8) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text("Failed")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(Capsule())
                                        .help(err)
                                        
                                        Button("Retry") {
                                            service.runTask(id: task.id)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.pink)
                                        .buttonStyle(.plain)
                                        .disabled(service.isRunningAny)
                                    }
                                    
                                case .cancelled:
                                    HStack(spacing: 8) {
                                        Text("Cancelled")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                        
                                        Button("Try Again") {
                                            service.runTask(id: task.id)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.pink)
                                        .buttonStyle(.plain)
                                        .disabled(service.isRunningAny)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // What the command does & when to use it
                            VStack(alignment: .leading, spacing: 6) {
                                Text("What this command does:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Text(task.purpose)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                                
                                HStack(alignment: .top, spacing: 4) {
                                    Text("When to run:")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.secondary)
                                    Text(task.whenToUse)
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .padding(.top, 2)
                            }
                            
                            // Terminal Command Box
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Command:")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(task.terminalCommand, forType: .string)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "doc.on.doc")
                                            Text("Copy")
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(task.terminalCommand)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color.cyan)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(6)
                            }
                            
                            // Output log if available
                            if !task.outputLog.isEmpty {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedLogs.contains(task.id) },
                                        set: { if $0 { expandedLogs.insert(task.id) } else { expandedLogs.remove(task.id) } }
                                    )
                                ) {
                                    ScrollView {
                                        Text(task.outputLog)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.green.opacity(0.9))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                    }
                                    .frame(maxHeight: 100)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(6)
                                } label: {
                                    Text("Execution Log Output")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        )
                    }
                }
                
                // Bottom Run All Button
                HStack {
                    Spacer()
                    Button(action: {
                        service.runAllTasks()
                    }) {
                        HStack(spacing: 8) {
                            if service.isRunningAny {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Executing Tasks...")
                            } else {
                                Image(systemName: "bolt.fill")
                                Text("Run All Maintenance Tasks")
                            }
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isRunningAny)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
    }
}
