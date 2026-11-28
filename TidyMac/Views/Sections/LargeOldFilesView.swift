import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

public struct LargeOldFilesView: View {
    @StateObject private var scanner = LargeOldFilesScanner.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var showTrashConfirmation: Bool = false
    @State private var itemToTrash: LargeOldFileItem? = nil
    @State private var showSingleTrashConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HeaderBannerView(
                        item: .largeOldFiles,
                        statusText: headerStatusText,
                        statusColor: headerStatusColor
                    )
                    
                    // Dry-Run Notice
                    DryRunBanner()
                    
                    // Full Disk Access Banner
                    FDAPermissionBanner(featureName: "Large & Old Files Deep Scan")
                    
                    // Error Banner
                    if let err = scanner.scanError {
                        ModuleErrorBanner(
                            message: err,
                            onRetry: {
                                Task { await scanner.startScan() }
                            },
                            onDismiss: {
                                scanner.scanError = nil
                            }
                        )
                    }
                    
                    // Metric Summary Cards
                    HStack(spacing: 12) {
                        MetricTileView(
                            title: "Total Matches",
                            value: scanner.formattedTotalSize,
                            subtitle: "\(scanner.files.count) files found",
                            icon: "folder.badge.clock",
                            iconColor: .teal
                        )
                        
                        MetricTileView(
                            title: "100 MB+ Files",
                            value: "\(scanner.largeFilesCount) Files",
                            subtitle: "Massive disk occupiers",
                            icon: "arrow.up.circle.fill",
                            iconColor: .purple
                        )
                        
                        MetricTileView(
                            title: "1+ Year Old",
                            value: "\(scanner.oldFilesCount) Files",
                            subtitle: "Untouched for >365 days",
                            icon: "clock.badge.exclamationmark",
                            iconColor: .orange
                        )
                        
                        MetricTileView(
                            title: "Selected to Trash",
                            value: scanner.formattedSelectedSize,
                            subtitle: "\(scanner.selectedFiles.count) selected",
                            icon: "trash.fill",
                            iconColor: .red
                        )
                    }
                    
                    // Top Action Control Bar
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            // Search Field
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Filter by file name or path...", text: $scanner.searchKeyword)
                                    .textFieldStyle(.plain)
                                if !scanner.searchKeyword.isEmpty {
                                    Button(action: { scanner.searchKeyword = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            
                            Spacer()
                            
                            // Scan Button
                            Button(action: {
                                Task {
                                    await scanner.startScan()
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
                                    Text(scanner.isScanning ? "Scanning..." : (scanner.files.isEmpty ? "Scan Home Folder" : "Rescan"))
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.teal.opacity(0.15))
                                .foregroundColor(.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.isScanning || scanner.isCleaning)
                            
                            // Move Selected to Trash Button
                            Button(action: {
                                showTrashConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    if scanner.isCleaning {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "trash.fill")
                                    }
                                    Text("Move to Trash (\(scanner.formattedSelectedSize))")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(scanner.selectedFiles.isEmpty ? Color.secondary.opacity(0.2) : Color.red)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.selectedFiles.isEmpty || scanner.isCleaning)
                        }
                        
                        // Filters & Sort Bar
                        HStack(spacing: 12) {
                            // Criteria Filter (All / 100MB+ / 1+ Year Old)
                            Picker("", selection: $scanner.criteriaFilter) {
                                ForEach(LargeOldCriteriaFilter.allCases) { criteria in
                                    Text(criteria.rawValue).tag(criteria)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320)
                            
                            Spacer()
                            
                            // Sort Menu
                            Menu {
                                ForEach(LargeOldSortOption.allCases) { opt in
                                    Button(action: { scanner.sortOption = opt }) {
                                        HStack {
                                            Text(opt.rawValue)
                                            if scanner.sortOption == opt {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(scanner.sortOption.rawValue)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            
                            // Select All / Deselect All
                            Button(action: {
                                let allSelected = scanner.filteredFiles.allSatisfy { $0.isSelected }
                                scanner.toggleSelectAll(!allSelected)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: scanner.filteredFiles.allSatisfy { $0.isSelected } ? "checkmark.square.fill" : "square")
                                    Text(scanner.filteredFiles.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All")
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.filteredFiles.isEmpty)
                        }
                        
                        // File Type Category Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                CategoryPill(title: "All", isSelected: scanner.selectedCategory == "All") {
                                    scanner.selectedCategory = "All"
                                }
                                
                                ForEach(LargeOldFileType.allCases) { type in
                                    CategoryPill(
                                        title: type.rawValue,
                                        icon: type.icon,
                                        color: type.color,
                                        isSelected: scanner.selectedCategory == type.rawValue
                                    ) {
                                        scanner.selectedCategory = type.rawValue
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    )
                    
                    // Scanning State Visualizer
                    if scanner.isScanning {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            Text(scanner.statusMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else if scanner.files.isEmpty {
                        // Empty State
                        VStack(spacing: 14) {
                            Image(systemName: "folder.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(.teal.opacity(0.6))
                            Text("No Large or Old Files Scanned Yet")
                                .font(.headline)
                            Text("Click 'Scan Home Folder' to locate files larger than 100 MB or older than 1 year.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                Task {
                                    await scanner.startScan()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Start Scan Now")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        )
                    } else if scanner.filteredFiles.isEmpty {
                        // Filter Empty State
                        VStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No files match the selected filters")
                                .font(.headline)
                            Button("Reset Filters") {
                                scanner.selectedCategory = "All"
                                scanner.criteriaFilter = .all
                                scanner.searchKeyword = ""
                            }
                            .font(.subheadline)
                            .foregroundColor(.teal)
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(36)
                    } else {
                        // File Items List
                        VStack(spacing: 8) {
                            ForEach(scanner.filteredFiles) { file in
                                LargeOldFileRow(
                                    file: file,
                                    onToggle: {
                                        if let idx = scanner.files.firstIndex(where: { $0.id == file.id }) {
                                            scanner.files[idx].isSelected.toggle()
                                        }
                                    },
                                    onReveal: {
                                        scanner.revealInFinder(url: file.url)
                                    },
                                    onOpen: {
                                        scanner.openFile(url: file.url)
                                    },
                                    onTrash: {
                                        itemToTrash = file
                                        showSingleTrashConfirmation = true
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            
            // Celebration Reclaimed Overlay
            if scanner.showCelebration, let result = scanner.lastCleanResult {
                ReclaimedCelebrationView(result: result) {
                    scanner.showCelebration = false
                }
            }
        }
        // Confirmation Alert for Batch Trash
        .alert("Move Selected Files to Trash?", isPresented: $showTrashConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move \(scanner.selectedFiles.count) Files to Trash", role: .destructive) {
                Task {
                    await scanner.moveSelectedToTrash()
                }
            }
        } message: {
            Text("Are you sure you want to move \(scanner.selectedFiles.count) selected files (\(scanner.formattedSelectedSize)) to macOS Trash? You can easily restore them at any time from your macOS Trash bin.")
        }
        // Confirmation Alert for Single Trash
        .alert("Move File to Trash?", isPresented: $showSingleTrashConfirmation) {
            Button("Cancel", role: .cancel) { itemToTrash = nil }
            Button("Move to Trash", role: .destructive) {
                if let item = itemToTrash {
                    scanner.moveToTrash(item: item)
                }
                itemToTrash = nil
            }
        } message: {
            if let item = itemToTrash {
                Text("Are you sure you want to move '\(item.name)' (\(item.formattedSize)) to macOS Trash?")
            } else {
                Text("Are you sure you want to move this file to macOS Trash?")
            }
        }
    }
    
    private var headerStatusText: String {
        if !fdaManager.hasFullDiskAccess {
            return "Access Required"
        } else if scanner.isScanning {
            return "Scanning..."
        } else if scanner.files.isEmpty {
            return "Ready"
        } else {
            return "\(scanner.formattedTotalSize) Found"
        }
    }
    
    private var headerStatusColor: Color {
        if !fdaManager.hasFullDiskAccess {
            return .orange
        } else if scanner.files.isEmpty {
            return .secondary
        } else {
            return .teal
        }
    }
}

// MARK: - Category Pill Component
private struct CategoryPill: View {
    let title: String
    var icon: String? = nil
    var color: Color = .primary
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white : color)
                }
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.teal : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Large Old File Row Component
private struct LargeOldFileRow: View {
    let file: LargeOldFileItem
    let onToggle: () -> Void
    let onReveal: () -> Void
    let onOpen: () -> Void
    let onTrash: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundColor(file.isSelected ? .teal : .secondary)
            }
            .buttonStyle(.plain)
            
            // File Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(file.fileType.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: file.fileType.icon)
                    .foregroundColor(file.fileType.color)
                    .font(.system(size: 16))
            }
            
            // Name, Path, and Tags
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    
                    // Badges for 100MB+ and 1+ Year Old
                    if file.isLarge {
                        Text("100MB+")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                    
                    if file.isOld {
                        Text("1+ Year Old")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text(file.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("•")
                    Text("Modified: \(file.formattedDate) (\(file.formattedAge))")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // File Size
            Text(file.formattedSize)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(minWidth: 70, alignment: .trailing)
            
            // Action Buttons (Reveal in Finder, Open, Move to Trash)
            HStack(spacing: 6) {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open File")
                
                Button(action: onTrash) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Move to macOS Trash")
            }
            .opacity(isHovering || file.isSelected ? 1.0 : 0.6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    file.isSelected ?
                        Color.teal.opacity(0.08) :
                        (isHovering ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(file.isSelected ? Color.teal.opacity(0.4) : Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
        .onHover { isHovering = $0 }
        // Context Menu
        .contextMenu {
            Button("Reveal in Finder") { onReveal() }
            Button("Open File") { onOpen() }
            Divider()
            Button("Move to Trash", role: .destructive) { onTrash() }
        }
    }
}
