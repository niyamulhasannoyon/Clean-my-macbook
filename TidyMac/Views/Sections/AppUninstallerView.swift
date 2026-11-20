import SwiftUI
import AppKit

public struct AppUninstallerView: View {
    @StateObject private var scanner = AppUninstallerScanner.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    
    @State private var showUninstallConfirmAlert: Bool = false
    @State private var showOrphansConfirmAlert: Bool = false
    @State private var appToUninstall: InstalledApp? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HeaderBannerView(
                        item: .appUninstaller,
                        statusText: headerStatusText,
                        statusColor: .orange
                    )
                    
                    // Dry-Run Simulation Notice
                    DryRunBanner()
                    
                    // Full Disk Access Banner
                    FDAPermissionBanner(featureName: "App Uninstaller & Residual Removal")
                    
                    // Error Banner
                    if let err = scanner.scanError {
                        ModuleErrorBanner(
                            message: err,
                            onRetry: {
                                Task { await scanner.scanAll() }
                            },
                            onDismiss: {
                                scanner.scanError = nil
                            }
                        )
                    }
                    
                    // Main Tab Selector & Action Control Bar
                    HStack(spacing: 12) {
                        // Segmented Tab Picker
                        Picker("View", selection: $scanner.selectedTab) {
                            Text("Installed Applications (\(scanner.totalInstalledAppsCount))")
                                .tag(AppUninstallerTab.installedApps)
                            Text("Orphaned Leftovers (\(scanner.orphanedGroups.count))")
                                .tag(AppUninstallerTab.orphanedLeftovers)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 420)
                        
                        Spacer()
                        
                        // Rescan Button
                        Button(action: {
                            Task {
                                await scanner.scanAll()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: scanner.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                    .rotationEffect(.degrees(scanner.isScanning ? 360 : 0))
                                    .animation(
                                        scanner.isScanning ?
                                            Animation.linear(duration: 1.0).repeatForever(autoreverses: false) :
                                            .default,
                                        value: scanner.isScanning
                                    )
                                Text(scanner.isScanning ? "Scanning..." : "Rescan Apps")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(scanner.isScanning || scanner.isCleaning)
                    }
                    
                    // Search & Sorting Bar
                    searchAndSortBar
                    
                    // Scanning Progress Indicator
                    if scanner.isScanning {
                        VStack(spacing: 8) {
                            ProgressView(value: scanner.scanProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.orange)
                            HStack {
                                Text(scanner.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(scanner.scanProgress * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                    }
                    
                    // Tab Content
                    if scanner.selectedTab == .installedApps {
                        installedAppsMasterDetailView
                    } else {
                        orphanedLeftoversView
                    }
                }
                .padding(24)
            }
            
            // Celebration Reclaimed Space Overlay
            if scanner.showCelebration, let result = scanner.lastCleanResult {
                ReclaimedCelebrationView(result: result) {
                    scanner.showCelebration = false
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task {
            if scanner.installedApps.isEmpty && !scanner.isScanning {
                await scanner.scanAll()
            }
        }
        // Confirmation alert for uninstalling an application
        .confirmationDialog(
            "Uninstall Application?",
            isPresented: $showUninstallConfirmAlert,
            titleVisibility: .visible
        ) {
            Button("Move App & Leftovers to Trash", role: .destructive) {
                if let app = appToUninstall {
                    Task {
                        _ = await scanner.trashApp(app: app, trashBundle: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let app = appToUninstall {
                Text("Are you sure you want to move \(app.name) and its selected leftover files (\(app.formattedSelectedSize)) to macOS Trash? You can restore them from Trash if needed.")
            } else {
                Text("Are you sure you want to proceed with trashing?")
            }
        }
        // Confirmation alert for orphaned residuals
        .confirmationDialog(
            "Move Orphaned Residuals to Trash?",
            isPresented: $showOrphansConfirmAlert,
            titleVisibility: .visible
        ) {
            Button("Move Selected to Trash", role: .destructive) {
                Task {
                    _ = await scanner.trashSelectedOrphans()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move the selected orphaned files (\(scanner.formattedSelectedOrphanedSize)) from uninstalled applications to macOS Trash.")
        }
    }
    
    // MARK: - Header Status Text
    private var headerStatusText: String {
        if scanner.isScanning {
            return "Scanning..."
        }
        if scanner.selectedTab == .installedApps {
            return "\(scanner.totalInstalledAppsCount) Apps (\(scanner.formattedTotalReclaimableSpace))"
        } else {
            return "\(scanner.orphanedGroups.count) Orphaned Groups (\(scanner.formattedTotalOrphanedSize))"
        }
    }
    
    // MARK: - Search & Filter Control Bar
    private var searchAndSortBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(
                    scanner.selectedTab == .installedApps ? "Search applications by name or bundle id..." : "Search orphaned leftover residuals...",
                    text: $scanner.searchText
                )
                .textFieldStyle(.plain)
                
                if !scanner.searchText.isEmpty {
                    Button(action: { scanner.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            if scanner.selectedTab == .installedApps {
                // Sort menu
                Menu {
                    Picker("Sort by", selection: $scanner.sortOption) {
                        ForEach(AppSortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(scanner.sortOption.rawValue)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                // Toggle for system apps
                Toggle(isOn: $scanner.showSystemApps) {
                    Text("Show System Apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
            }
        }
    }
    
    // MARK: - Installed Apps Master-Detail Layout
    private var installedAppsMasterDetailView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Master: Apps List
            VStack(spacing: 10) {
                if scanner.filteredApps.isEmpty {
                    emptyStateCard(
                        icon: "magnifyingglass",
                        title: "No Applications Found",
                        subtitle: scanner.searchText.isEmpty ? "No applications located in /Applications or ~/Applications." : "No apps match '\(scanner.searchText)'."
                    )
                } else {
                    ForEach(scanner.filteredApps) { app in
                        AppRowCard(
                            app: app,
                            isSelected: scanner.selectedAppId == app.id
                        ) {
                            scanner.selectedAppId = app.id
                        }
                    }
                }
            }
            .frame(width: 330)
            
            // Detail: Selected App Details & Leftovers
            if let selectedApp = scanner.selectedApp {
                AppDetailCard(
                    app: selectedApp,
                    onUninstall: {
                        appToUninstall = selectedApp
                        showUninstallConfirmAlert = true
                    },
                    onRefreshLeftovers: {
                        Task {
                            await scanner.refreshLeftovers(for: selectedApp)
                        }
                    }
                )
            } else {
                emptyStateCard(
                    icon: "app.badge.xmark",
                    title: "No App Selected",
                    subtitle: "Select an installed application from the list on the left to inspect its leftover files and uninstall."
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Orphaned Leftovers Tab View
    private var orphanedLeftoversView: some View {
        VStack(spacing: 16) {
            // Explanatory Banner
            HStack(spacing: 14) {
                Image(systemName: "archivebox.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orphaned Application Residuals")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("These leftover caches, application support directories, preferences, and container data remain from apps you have previously deleted. You can safely trash them to reclaim disk space.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !scanner.orphanedGroups.isEmpty {
                    Button(action: {
                        let allSelected = scanner.orphanedGroups.allSatisfy { $0.isSelected }
                        for idx in scanner.orphanedGroups.indices {
                            scanner.orphanedGroups[idx].isSelected = !allSelected
                            for itemIdx in scanner.orphanedGroups[idx].items.indices {
                                scanner.orphanedGroups[idx].items[itemIdx].isSelected = !allSelected
                            }
                        }
                    }) {
                        Text(scanner.orphanedGroups.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            
            // Action Bar for Orphaned residuals
            if !scanner.orphanedGroups.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected for Cleanup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scanner.formattedSelectedOrphanedSize)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showOrphansConfirmAlert = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Move Selected to Trash (\(scanner.formattedSelectedOrphanedSize))")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(scanner.selectedOrphanedSize > 0 ? Color.red : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.selectedOrphanedSize == 0 || scanner.isCleaning)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            }
            
            // Orphaned Groups List
            if scanner.filteredOrphanedGroups.isEmpty {
                emptyStateCard(
                    icon: "checkmark.seal.fill",
                    title: "No Orphaned Residuals Found",
                    subtitle: "All leftover directories in Application Support, Caches, Containers, and Preferences belong to currently installed applications."
                )
            } else {
                ForEach($scanner.orphanedGroups) { $group in
                    OrphanedGroupCard(group: $group)
                }
            }
        }
    }
    
    // MARK: - Reusable Empty State Card
    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}

// MARK: - App Row Card in Master List
struct AppRowCard: View {
    let app: InstalledApp
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Real macOS App Icon
                AppIconThumbnail(url: app.bundleURL, size: 38)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if app.isSystemApp {
                            Text("System")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        } else if app.isUserApp {
                            Text("~/Apps")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text("v\(app.version)")
                        if app.leftoversCount > 0 {
                            Text("•")
                            Text("\(app.leftoversCount) leftovers (\(app.formattedLeftoversSize))")
                                .foregroundColor(.orange)
                        } else {
                            Text("•")
                            Text("No leftovers")
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                
                Spacer()
                
                Text(app.formattedTotalSize)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected ?
                            Color.orange.opacity(0.12) :
                            Color(nsColor: .controlBackgroundColor).opacity(0.4)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Detail Card
struct AppDetailCard: View {
    @ObservedObject private var scanner = AppUninstallerScanner.shared
    let app: InstalledApp
    let onUninstall: () -> Void
    let onRefreshLeftovers: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // App Header Information Card
            HStack(spacing: 16) {
                AppIconThumbnail(url: app.bundleURL, size: 54)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 18, weight: .bold))
                        
                        if app.isSystemApp {
                            Text("System Protected")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    
                    if !app.bundleIdentifier.isEmpty {
                        Text(app.bundleIdentifier)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Version: \(app.version)")
                        Text("•")
                        Text(app.bundleURL.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Show in Finder Button
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Show in Finder")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            
            // Storage Statistics Tiles
            HStack(spacing: 12) {
                MetricTile(
                    title: "Application Bundle",
                    value: app.formattedAppSize,
                    icon: "app.fill",
                    tint: .blue,
                    caption: app.bundleURL.lastPathComponent
                )
                
                MetricTile(
                    title: "Residual Leftovers",
                    value: app.formattedLeftoversSize,
                    icon: "folder.badge.gearshape",
                    tint: .purple,
                    caption: "\(app.leftoversCount) items across Library"
                )
                
                MetricTile(
                    title: "Total Space Required",
                    value: app.formattedTotalSize,
                    icon: "chart.pie.fill",
                    tint: .orange,
                    caption: "Reclaimable on uninstall"
                )
            }
            
            // Leftovers List & Breakdown
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Associated Residual & Service Files")
                            .font(.headline)
                        Text("Detected across ~/Library/Application Support, Caches, Preferences, Containers, Logs, LaunchAgents, and Saved Application State.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !app.leftovers.isEmpty {
                        Button(action: {
                            toggleAllLeftovers()
                        }) {
                            Text(isAllLeftoversSelected ? "Deselect All" : "Select All")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                
                if app.leftovers.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No leftover service files found. This application has not accumulated residual data in ~/Library.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    // Itemized Leftovers List
                    VStack(spacing: 8) {
                        ForEach(app.leftovers.indices, id: \.self) { idx in
                            LeftoverItemRow(item: bindingForLeftover(idx: idx))
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            
            // Action & Uninstall Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Selected for Trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(app.formattedSelectedSize)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if app.isSystemApp {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                        Text("System Application (Protected)")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.secondary)
                    .cornerRadius(10)
                } else {
                    Button(action: onUninstall) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Uninstall App & Trash Leftovers (\(app.formattedSelectedSize))")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var isAllLeftoversSelected: Bool {
        app.leftovers.allSatisfy { $0.isSelected }
    }
    
    private func toggleAllLeftovers() {
        guard let appIdx = scanner.installedApps.firstIndex(where: { $0.id == app.id }) else { return }
        let target = !isAllLeftoversSelected
        for lIdx in scanner.installedApps[appIdx].leftovers.indices {
            scanner.installedApps[appIdx].leftovers[lIdx].isSelected = target
        }
    }
    
    private func bindingForLeftover(idx: Int) -> Binding<AppLeftoverItem> {
        Binding(
            get: {
                if let appIdx = scanner.installedApps.firstIndex(where: { $0.id == app.id }),
                   idx < scanner.installedApps[appIdx].leftovers.count {
                    return scanner.installedApps[appIdx].leftovers[idx]
                }
                return app.leftovers[idx]
            },
            set: { updatedItem in
                if let appIdx = scanner.installedApps.firstIndex(where: { $0.id == app.id }),
                   idx < scanner.installedApps[appIdx].leftovers.count {
                    scanner.installedApps[appIdx].leftovers[idx] = updatedItem
                }
            }
        )
    }
}

// MARK: - Leftover Item Row
struct LeftoverItemRow: View {
    @Binding var item: AppLeftoverItem
    
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.category.tintColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: item.category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(item.category.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.category.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.category.tintColor)
                    
                    Text("—")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Text(item.displayPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Size & Finder Button
            HStack(spacing: 8) {
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isSelected ? Color.blue.opacity(0.04) : Color.clear)
        )
    }
}

// MARK: - Orphaned Group Card
struct OrphanedGroupCard: View {
    @Binding var group: OrphanedAppGroup
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Group Header
            HStack(spacing: 12) {
                Toggle("", isOn: $group.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .onChange(of: group.isSelected) { newValue in
                        for idx in group.items.indices {
                            group.items[idx].isSelected = newValue
                        }
                    }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "ghost.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(group.items.count) leftover locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let bid = group.bundleIdentifier {
                        Text(bid)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Text(group.formattedTotalSize)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            
            // Sub-items
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach($group.items) { $item in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $item.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .padding(.leading, 12)
                            
                            Image(systemName: item.category.icon)
                                .font(.system(size: 12))
                                .foregroundColor(item.category.tintColor)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayPath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(item.category.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Show in Finder")
                            .padding(.trailing, 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                )
                .padding(.top, 4)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}

// MARK: - Metric Tile View
struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let caption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(caption)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
    }
}

// MARK: - Native App Icon Thumbnail
struct AppIconThumbnail: View {
    let url: URL
    let size: CGFloat
    
    var body: some View {
        if FileManager.default.fileExists(atPath: url.path) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: size, height: size)
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.orange)
            }
        }
    }
}
