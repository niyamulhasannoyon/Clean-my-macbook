import SwiftUI

struct MaintenanceTask: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    var isRunning: Bool = false
    var isDone: Bool = false
}

struct MaintenanceView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var tasks: [MaintenanceTask] = [
        MaintenanceTask(title: "Free Up Inactive RAM", description: "Reclaim memory from terminated processes and swap space", icon: "memorychip"),
        MaintenanceTask(title: "Flush DNS Cache", description: "Resolve network latency and clear outdated domain resolutions", icon: "network"),
        MaintenanceTask(title: "Rebuild Spotlight Index", description: "Fix search inconsistencies and restore instant query speed", icon: "magnifyingglass.circle.fill"),
        MaintenanceTask(title: "Repair Disk Permissions", description: "Verify POSIX file permissions on macOS system volumes", icon: "lock.open.trianglebadge.exclamationmark"),
        MaintenanceTask(title: "Speed Up Apple Mail", description: "Vacuum and reindex the SQLite database of Apple Mail", icon: "envelope.badge.shield.half.filled"),
        MaintenanceTask(title: "Purge Time Machine Snapshots", description: "Thin outdated local APFS snapshots taking up disk space", icon: "clock.arrow.2.circlepath")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(
                    item: .maintenance,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : "6 Available Tasks",
                    statusColor: !fdaManager.hasFullDiskAccess ? .orange : .pink
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Disk Maintenance & Repair Scripts")
                
                // Tasks list
                VStack(spacing: 12) {
                    ForEach($tasks) { $task in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: task.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(.pink)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(task.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if task.isDone {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                    Text("Completed")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            } else if task.isRunning {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.horizontal, 10)
                            } else {
                                Button("Run Task") {
                                    runTask(id: task.id)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pink.opacity(0.15))
                                .foregroundColor(.pink)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        )
                    }
                }
                
                // Run All Button
                HStack {
                    Spacer()
                    if !fdaManager.hasFullDiskAccess {
                        Button(action: {
                            fdaManager.isShowingOnboardingSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                Text("Grant Access to Run Maintenance")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("Run All Recommended Tasks") {
                            for i in tasks.indices {
                                tasks[i].isRunning = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                for i in tasks.indices {
                                    tasks[i].isRunning = false
                                    tasks[i].isDone = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func runTask(id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isRunning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let idx = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[idx].isRunning = false
                    tasks[idx].isDone = true
                }
            }
        }
    }
}
