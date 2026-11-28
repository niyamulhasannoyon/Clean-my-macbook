import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

enum PerformanceTab: String, CaseIterable, Identifiable {
    case liveMonitor = "Live Hardware & Apps"
    case startupItems = "Login Items & Launch Agents"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .liveMonitor: return "speedometer"
        case .startupItems: return "gearshape.arrow.triangle.2.circlepath"
        }
    }
}

struct PerformanceView: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared
    @State private var selectedTab: PerformanceTab = .liveMonitor
    @State private var selectedFilter: LaunchItemLocation = .all
    @State private var appToQuit: ProcessItem? = nil
    @State private var showingQuitConfirmation: Bool = false
    @State private var searchText: String = ""
    
    var filteredLaunchItems: [LaunchItem] {
        monitor.launchItems.filter { item in
            let matchesFilter = (selectedFilter == .all) || (item.location == selectedFilter)
            let matchesSearch = searchText.isEmpty ||
                item.displayName.localizedCaseInsensitiveContains(searchText) ||
                item.label.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                HeaderBannerView(
                    item: .performance,
                    statusText: "CPU: \(monitor.cpu.formattedPercent) • RAM: \(monitor.memory.formattedUsed)",
                    statusColor: .mint
                )
                
                // Dry-Run Notice
                DryRunBanner()
                
                // Mode Segmented Control
                Picker("", selection: $selectedTab) {
                    ForEach(PerformanceTab.allCases) { tab in
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                if selectedTab == .liveMonitor {
                    liveMonitorSection
                } else {
                    startupItemsSection
                }
            }
            .padding(24)
        }
        .onAppear {
            monitor.startMonitoring()
            monitor.refreshHardwareStats()
            monitor.fetchProcesses()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
        .confirmationDialog(
            "Quit \(appToQuit?.name ?? "Application")?",
            isPresented: $showingQuitConfirmation,
            presenting: appToQuit
        ) { app in
            Button("Quit App", role: .destructive) {
                monitor.quitApp(process: app, force: false)
            }
            Button("Force Quit App", role: .destructive) {
                monitor.quitApp(process: app, force: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { app in
            Text("Closing \(app.name) (PID: \(app.pid)) will reclaim \(app.formattedMemory) of physical memory.")
        }
    }
    
    // MARK: - Live Monitor Section
    private var liveMonitorSection: some View {
        VStack(spacing: 20) {
            // Hardware Gauges
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                // CPU Gauge
                VStack(spacing: 12) {
                    CircularProgressView(
                        progress: monitor.cpu.usageRatio,
                        lineWidth: 9,
                        gradientColors: [.mint, .teal],
                        title: "CPU Load"
                    )
                    .frame(width: 95, height: 95)
                    
                    VStack(spacing: 2) {
                        Text(monitor.cpu.formattedPercent)
                            .font(.system(size: 15, weight: .bold))
                        Text(monitor.cpu.modelDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        VStack(spacing: 1) {
                            Text("User")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.userPercent))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        VStack(spacing: 1) {
                            Text("System")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.systemPercent))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        VStack(spacing: 1) {
                            Text("Idle")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.idlePercent))
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
                
                // RAM Gauge
                VStack(spacing: 12) {
                    CircularProgressView(
                        progress: monitor.memory.usageRatio,
                        lineWidth: 9,
                        gradientColors: [.blue, .purple],
                        title: "RAM Usage"
                    )
                    .frame(width: 95, height: 95)
                    
                    VStack(spacing: 2) {
                        Text("\(monitor.memory.formattedUsed) / \(monitor.memory.formattedTotal)")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(monitor.memory.formattedFree) Available")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        VStack(spacing: 1) {
                            Text("Active")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.memory.formattedActive)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        VStack(spacing: 1) {
                            Text("Wired")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.memory.formattedWired)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        VStack(spacing: 1) {
                            Text("Compress")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.memory.formattedCompressed)
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
                
                // Disk Gauge
                VStack(spacing: 12) {
                    CircularProgressView(
                        progress: monitor.disk.usageRatio,
                        lineWidth: 9,
                        gradientColors: [.orange, .pink],
                        title: "Storage"
                    )
                    .frame(width: 95, height: 95)
                    
                    VStack(spacing: 2) {
                        Text("\(monitor.disk.formattedUsed) / \(monitor.disk.formattedTotal)")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(monitor.disk.formattedFree) Free Space")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 3) {
                        Text("Root Volume (APFS)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%% Used", monitor.disk.usageRatio * 100))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
            }
            
            // Top Memory-Hungry Applications Table
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Top Memory-Hungry Applications")
                            .font(.system(size: 15, weight: .bold))
                        Text("Real-time active GUI applications sorted by memory footprint (RSS)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("Live Updating")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Button(action: {
                        monitor.fetchProcesses()
                        monitor.refreshHardwareStats()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh running applications")
                }
                
                Divider()
                
                // Process List
                if monitor.topProcesses.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Inspecting running applications...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(monitor.topProcesses) { app in
                            HStack(spacing: 12) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(app.name)
                                            .font(.system(size: 13, weight: .semibold))
                                        
                                        Text("PID: \(app.pid)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    
                                    if !app.bundleIdentifier.isEmpty {
                                        Text(app.bundleIdentifier)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                // Memory Badge
                                Text(app.formattedMemory)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(width: 90, alignment: .trailing)
                                
                                // Quit Button
                                Button(action: {
                                    appToQuit = app
                                    showingQuitConfirmation = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle")
                                        Text("Quit App")
                                    }
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundColor(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            )
                        }
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
    
    // MARK: - Startup Items Section
    private var startupItemsSection: some View {
        VStack(spacing: 16) {
            // Summary Banner
            HStack(spacing: 14) {
                let total = monitor.launchItems.count
                let enabledCount = monitor.launchItems.filter { $0.isEnabled }.count
                let disabledCount = total - enabledCount
                
                MetricTileView(
                    title: "Startup Services",
                    value: "\(total) Items",
                    subtitle: "Launch Agents & Daemons",
                    icon: "gearshape.arrow.triangle.2.circlepath",
                    iconColor: .mint
                )
                
                MetricTileView(
                    title: "Active Services",
                    value: "\(enabledCount) Enabled",
                    subtitle: "\(disabledCount) Disabled",
                    icon: "bolt.fill",
                    iconColor: .orange
                )
            }
            
            // Filters and Search Bar
            HStack(spacing: 12) {
                Picker("Filter Location", selection: $selectedFilter) {
                    ForEach(LaunchItemLocation.allCases) { loc in
                        Text(loc.rawValue).tag(loc)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search startup items...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                
                Button(action: {
                    monitor.fetchLaunchItems()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .padding(6)
                }
                .buttonStyle(.plain)
                .help("Refresh Startup Items")
            }
            
            // Notice about system daemons
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Disabling unnecessary login items and launch agents reduces boot time and frees background memory. Modifying system daemons requires administrator privileges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // List of Launch Items
            if monitor.isLoadingLaunchItems {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning launch agents and daemons...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(30)
            } else if filteredLaunchItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No startup items found matching criteria")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredLaunchItems) { item in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(item.location == .userAgent ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: item.location.icon)
                                    .foregroundColor(item.location == .userAgent ? .blue : .orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(item.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text(item.location.rawValue)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(item.location == .userAgent ? .blue : .orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((item.location == .userAgent ? Color.blue : Color.orange).opacity(0.12))
                                        .clipShape(Capsule())
                                    
                                    if item.location.requiresAdmin {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                            .help("Admin password required to toggle")
                                    }
                                }
                                
                                Text(item.label)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Text(item.program)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Toggle
                            if item.isToggling {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 8)
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { newValue in
                                        monitor.toggleLaunchItem(item: item, enable: newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        )
                    }
                }
            }
        }
    }
}
