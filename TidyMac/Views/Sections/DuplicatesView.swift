import SwiftUI
import AppKit

public struct DuplicatesView: View {
    @StateObject private var scanner = DuplicateScanner.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var showDeleteConfirmationSheet: Bool = false
    @State private var singleFileToTrash: (DuplicateFileItem, DuplicateGroup)? = nil
    @State private var showSingleTrashConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HeaderBannerView(
                        item: .duplicates,
                        statusText: headerStatusText,
                        statusColor: headerStatusColor
                    )
                    
                    // Dry-Run Notice
                    DryRunBanner()
                    
                    // Full Disk Access Banner
                    FDAPermissionBanner(featureName: "Duplicate File Finder")
                    
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
                    
                    // Metric Summary Tiles
                    HStack(spacing: 12) {
                        MetricTileView(
                            title: "Wasted Space",
                            value: scanner.formattedTotalWastedSpace,
                            subtitle: "\(scanner.totalDuplicateFilesCount) files in \(scanner.duplicateGroups.count) groups",
                            icon: "square.2.layers.3d.top.filled",
                            iconColor: .indigo
                        )
                        
                        MetricTileView(
                            title: "Selected to Clean",
                            value: scanner.formattedSelectedRemovalSize,
                            subtitle: "\(scanner.totalSelectedRemovalCount) duplicate copies selected",
                            icon: "checkmark.circle.badge.xmark.fill",
                            iconColor: .orange
                        )
                        
                        MetricTileView(
                            title: "Detection Pipeline",
                            value: "3-Stage",
                            subtitle: "Size → Partial → SHA-256",
                            icon: "shield.lefthalf.filled",
                            iconColor: .teal
                        )
                    }
                    
                    // Action Control & Auto-Select Bar
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            // Search Keyword Field
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search duplicate name or folder...", text: $scanner.searchKeyword)
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
                                    Text(scanner.isScanning ? "Scanning..." : (scanner.duplicateGroups.isEmpty ? "Scan Duplicates" : "Rescan"))
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.indigo.opacity(0.15))
                                .foregroundColor(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.isScanning || scanner.isCleaning)
                            
                            // Clean Button (Opens Confirmation Modal)
                            Button(action: {
                                showDeleteConfirmationSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    if scanner.isCleaning {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "trash.fill")
                                    }
                                    Text("Clean Duplicates (\(scanner.formattedSelectedRemovalSize))")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(scanner.totalSelectedRemovalCount == 0 ? Color.secondary.opacity(0.2) : Color.indigo)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.totalSelectedRemovalCount == 0 || scanner.isCleaning)
                        }
                        
                        // "Keep One" Strategy and Bulk Actions Bar
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.indigo)
                                Text("Auto-Select (Keep One):")
                                    .font(.caption.weight(.semibold))
                                
                                Menu {
                                    ForEach(DuplicateKeepStrategy.allCases) { strategy in
                                        Button(action: {
                                            scanner.applyKeepOneAutoSelect(strategy: strategy)
                                        }) {
                                            HStack {
                                                Text(strategy.rawValue)
                                                if scanner.selectedKeepStrategy == strategy {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(scanner.selectedKeepStrategy.rawValue)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.indigo.opacity(0.12))
                                    .foregroundColor(.indigo)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                            
                            Spacer()
                            
                            // Deselect All Button
                            Button("Deselect All") {
                                for gIdx in scanner.duplicateGroups.indices {
                                    for fIdx in scanner.duplicateGroups[gIdx].files.indices {
                                        scanner.duplicateGroups[gIdx].files[fIdx].isSelectedForRemoval = false
                                        scanner.duplicateGroups[gIdx].files[fIdx].isKeptOriginal = false
                                    }
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .disabled(scanner.totalSelectedRemovalCount == 0)
                            
                            // Apply Default Keep One
                            Button("Auto-Select All") {
                                scanner.applyKeepOneAutoSelect()
                            }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.plain)
                            .foregroundColor(.indigo)
                            .disabled(scanner.duplicateGroups.isEmpty)
                        }
                        
                        // Filter Categories Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["All", "Documents", "Photos", "Videos", "Archives", "Audio", "Other"], id: \.self) { cat in
                                    Button(action: { scanner.filterCategory = cat }) {
                                        Text(cat)
                                            .font(.caption.weight(scanner.filterCategory == cat ? .semibold : .regular))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(scanner.filterCategory == cat ? Color.indigo : Color(nsColor: .controlBackgroundColor))
                                            .foregroundColor(scanner.filterCategory == cat ? .white : .primary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.primary.opacity(scanner.filterCategory == cat ? 0 : 0.08), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
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
                        VStack(spacing: 14) {
                            ProgressView(value: scanner.progress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.indigo)
                                .frame(maxWidth: 380)
                            
                            VStack(spacing: 4) {
                                Text(scanner.currentStage.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(scanner.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        )
                    } else if scanner.duplicateGroups.isEmpty {
                        // Empty State
                        VStack(spacing: 14) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.indigo.opacity(0.6))
                            Text("No Duplicate Groups Found")
                                .font(.headline)
                            Text("Click 'Scan Duplicates' to discover identical files across your Home directory using full SHA-256 verification. Apple Photos libraries are safely excluded.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 500)
                            
                            Button(action: {
                                Task {
                                    await scanner.startScan()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Start Duplicate Scan")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(Color.indigo)
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
                    } else if scanner.filteredGroups.isEmpty {
                        // Filter Empty State
                        VStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No duplicate groups match your search or filter")
                                .font(.headline)
                            Button("Reset Filters") {
                                scanner.filterCategory = "All"
                                scanner.searchKeyword = ""
                            }
                            .font(.subheadline)
                            .foregroundColor(.indigo)
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(36)
                    } else {
                        // Duplicate Groups List
                        VStack(spacing: 12) {
                            ForEach(scanner.filteredGroups.indices, id: \.self) { idx in
                                let group = scanner.filteredGroups[idx]
                                DuplicateGroupCard(
                                    group: group,
                                    onToggleFile: { file in
                                        scanner.toggleFileSelection(groupId: group.id, fileId: file.id)
                                    },
                                    onKeepOneForGroup: { strat in
                                        if let realIdx = scanner.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                                            scanner.applyKeepOneToGroup(at: realIdx, strategy: strat)
                                        }
                                    },
                                    onRevealFile: { file in
                                        scanner.revealInFinder(url: file.url)
                                    },
                                    onTrashSingleFile: { file in
                                        singleFileToTrash = (file, group)
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
        // Confirmation Alert for Batch Deletion (MANDATORY per user prompt)
        .alert("Confirm Moving Duplicates to Trash", isPresented: $showDeleteConfirmationSheet) {
            Button("Cancel", role: .cancel) {}
            Button("Move \(scanner.totalSelectedRemovalCount) Duplicates to Trash", role: .destructive) {
                Task {
                    await scanner.moveSelectedDuplicatesToTrash(userConfirmed: true)
                }
            }
        } message: {
            Text("Are you sure you want to move \(scanner.totalSelectedRemovalCount) duplicate files (\(scanner.formattedSelectedRemovalSize)) to macOS Trash?\n\nOne original copy in each group will be safely preserved. The duplicates can be restored at any time from your macOS Trash bin.")
        }
        // Confirmation Alert for Single File Deletion
        .alert("Move Duplicate File to Trash?", isPresented: $showSingleTrashConfirmation) {
            Button("Cancel", role: .cancel) { singleFileToTrash = nil }
            Button("Move to Trash", role: .destructive) {
                if let (file, group) = singleFileToTrash {
                    let fm = FileManager.default
                    do {
                        try fm.trashItem(at: file.url, resultingItemURL: nil)
                        if let gIdx = scanner.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                            scanner.duplicateGroups[gIdx].files.removeAll { $0.id == file.id }
                            if scanner.duplicateGroups[gIdx].files.count < 2 {
                                scanner.duplicateGroups.remove(at: gIdx)
                            }
                        }
                        scanner.statusMessage = "Moved '\(file.name)' to Trash."
                        StorageModel.shared.refresh()
                    } catch {
                        scanner.statusMessage = "Failed to move '\(file.name)' to Trash: \(error.localizedDescription)"
                    }
                }
                singleFileToTrash = nil
            }
        } message: {
            if let (file, _) = singleFileToTrash {
                Text("Are you sure you want to move '\(file.name)' (\(file.formattedSize)) to macOS Trash?")
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
        } else if scanner.duplicateGroups.isEmpty {
            return "Ready"
        } else {
            return "\(scanner.formattedTotalWastedSpace) Duplicates"
        }
    }
    
    private var headerStatusColor: Color {
        if !fdaManager.hasFullDiskAccess {
            return .orange
        } else if scanner.duplicateGroups.isEmpty {
            return .secondary
        } else {
            return .indigo
        }
    }
}

// MARK: - Duplicate Group Card
private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    let onToggleFile: (DuplicateFileItem) -> Void
    let onKeepOneForGroup: (DuplicateKeepStrategy) -> Void
    let onRevealFile: (DuplicateFileItem) -> Void
    let onTrashSingleFile: (DuplicateFileItem) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Group Header Bar
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(group.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: group.icon)
                        .foregroundColor(group.color)
                        .font(.system(size: 16))
                }
                
                // Group Name and Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(group.fileName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        
                        Text("\(group.fileCount) copies")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 6) {
                        Text(group.category)
                        Text("•")
                        Text("\(group.formattedFileSize) each")
                        Text("•")
                        Text("SHA-256: \(group.fullHash.prefix(8))...")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Wasted Space Badge
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(group.formattedWastedSpace) wasted")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(group.wastedSpace > 0 ? .primary : .secondary)
                    
                    // Group Auto-Select Keep One Menu
                    Menu {
                        ForEach(DuplicateKeepStrategy.allCases) { strat in
                            Button(action: { onKeepOneForGroup(strat) }) {
                                Text(strat.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Keep One")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.indigo)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            
            // Expanded Files Table
            if isExpanded {
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(group.files) { file in
                        DuplicateFileItemRow(
                            file: file,
                            onToggle: { onToggleFile(file) },
                            onReveal: { onRevealFile(file) },
                            onTrash: { onTrashSingleFile(file) }
                        )
                        
                        if file.id != group.files.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Duplicate File Item Row
private struct DuplicateFileItemRow: View {
    let file: DuplicateFileItem
    let onToggle: () -> Void
    let onReveal: () -> Void
    let onTrash: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox for Removal
            Button(action: onToggle) {
                Image(systemName: file.isSelectedForRemoval ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundColor(file.isSelectedForRemoval ? .red : .secondary)
            }
            .buttonStyle(.plain)
            
            // Status Tag: Kept Original vs Selected for Removal
            if file.isKeptOriginal {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.caption2)
                    Text("KEEP ORIGINAL")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.green.opacity(0.18))
                .foregroundColor(.green)
                .clipShape(Capsule())
            } else if file.isSelectedForRemoval {
                HStack(spacing: 3) {
                    Image(systemName: "trash.fill")
                        .font(.caption2)
                    Text("REMOVE")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.red.opacity(0.18))
                .foregroundColor(.red)
                .clipShape(Capsule())
            } else {
                Text("COPY")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
            }
            
            // Path and Modified Date
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                
                Text("Modified: \(file.formattedDate)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                
                Button(action: onTrash) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Move to macOS Trash")
            }
            .opacity(isHovering || file.isSelectedForRemoval ? 1.0 : 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            file.isSelectedForRemoval ?
                Color.red.opacity(0.06) :
                (file.isKeptOriginal ? Color.green.opacity(0.04) : Color.clear)
        )
        .onHover { isHovering = $0 }
        // Context Menu
        .contextMenu {
            Button("Reveal in Finder") { onReveal() }
            Divider()
            Button(file.isSelectedForRemoval ? "Unmark for Removal" : "Mark for Removal") {
                onToggle()
            }
            Button("Move to Trash Immediately", role: .destructive) {
                onTrash()
            }
        }
    }
}
