import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

public struct DiskSpaceView: View {
    @StateObject private var scanner = DiskSpaceScanner.shared
    @ObservedObject private var storage = StorageModel.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                HeaderBannerView(
                    item: .diskSpace,
                    statusText: "\(storage.formattedFree) Free of \(storage.formattedTotal)",
                    statusColor: .yellow
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Disk Space Visualizer")
                
                // Module Error Banner
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
                
                // Top Control Bar: Locations & Chart Style
                topControlBar
                
                // Breadcrumbs & Navigation Bar
                breadcrumbsBar
                
                // Main Chart Card (Treemap / Sunburst Canvas)
                VStack(spacing: 0) {
                    chartContainerView
                    
                    Divider()
                    
                    // Live Hover Info Footer
                    hoverInfoFooter
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                // Contents Breakdown Table
                directoryContentsSection
            }
            .padding(24)
        }
        .task {
            if scanner.rootNode?.children.isEmpty ?? true {
                await scanner.startScan()
            }
        }
    }
    
    // MARK: - Top Control Bar
    private var topControlBar: some View {
        HStack(spacing: 12) {
            // Location Presets
            HStack(spacing: 6) {
                Button(action: {
                    Task {
                        await scanner.startScan(at: FileManager.default.homeDirectoryForCurrentUser)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "house.fill")
                        Text("Home (~)")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task {
                        await scanner.startScan(at: URL(fileURLWithPath: "/Applications"))
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "app.badge.fill")
                        Text("Applications")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    scanner.pickCustomFolder()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Folder...")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Chart Style Segmented Picker
            Picker("", selection: $scanner.chartStyle) {
                ForEach(DiskChartStyle.allCases) { style in
                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                        Text(style.rawValue)
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
            
            // Rescan Button
            Button(action: {
                Task {
                    await scanner.startScan(at: scanner.rootNode?.url)
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(scanner.isScanning ? 360 : 0))
                        .animation(scanner.isScanning ? Animation.linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: scanner.isScanning)
                    Text("Rescan")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.18))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(scanner.isScanning)
        }
    }
    
    // MARK: - Breadcrumbs Bar
    private var breadcrumbsBar: some View {
        HStack(spacing: 8) {
            // Back / Drill Up button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    scanner.drillUp()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Up")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(scanner.breadcrumbs.count > 1 ? 0.9 : 0.4))
                .foregroundColor(scanner.breadcrumbs.count > 1 ? .primary : .secondary.opacity(0.5))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(scanner.breadcrumbs.count <= 1)
            
            Divider()
                .frame(height: 16)
            
            // Breadcrumbs trail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(scanner.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                        let isLast = index == scanner.breadcrumbs.count - 1
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                scanner.navigateTo(breadcrumb: crumb)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: crumb.iconName)
                                    .font(.system(size: 10))
                                    .foregroundColor(isLast ? .yellow : .secondary)
                                Text(crumb.name)
                                    .font(.system(size: 12, weight: isLast ? .bold : .medium))
                                    .foregroundColor(isLast ? .primary : .secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(isLast ? Color.yellow.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        if !isLast {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Current folder total size badge
            if let current = scanner.currentNode {
                HStack(spacing: 6) {
                    Text(current.formattedSize)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if current.fileCount > 0 {
                        Text("(\(current.fileCount) items)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        )
    }
    
    // MARK: - Main Chart Container
    private var chartContainerView: some View {
        ZStack {
            if scanner.isScanning || scanner.isDeepScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(scanner.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 340)
            } else {
                Group {
                    if scanner.chartStyle == .treemap {
                        DiskTreemapCanvas(scanner: scanner)
                    } else {
                        DiskSunburstCanvas(scanner: scanner)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 420)
                .padding(12)
            }
        }
    }
    
    // MARK: - Hover Info Footer
    private var hoverInfoFooter: some View {
        let activeNode = scanner.hoveredNode ?? scanner.selectedNode ?? scanner.currentNode
        let parentSize = scanner.currentNode?.size ?? 1
        
        return HStack(spacing: 12) {
            if let node = activeNode {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(node.color.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: node.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(node.color)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(node.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if node.isVirtual {
                            Text("Group")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        } else if node.isDirectory {
                            Text("Folder")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(node.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                // Size & Percent
                HStack(spacing: 14) {
                    if parentSize > 0 && node.id != scanner.currentNode?.id {
                        let pct = Double(node.size) / Double(parentSize) * 100.0
                        Text(String(format: "%.1f%% of folder", pct))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(node.formattedSize)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if node.canDrillDown {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                scanner.drillDown(to: node)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Drill Down")
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow.rays")
                        .foregroundColor(.secondary)
                    Text("Hover or click a block/arc to inspect or drill down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Directory Contents Breakdown Table
    private var directoryContentsSection: some View {
        let items = (scanner.currentNode?.children ?? []).sorted { $0.size > $1.size }
        let totalFolderSize = max(1, scanner.currentNode?.size ?? 1)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items in \(scanner.currentNode?.name ?? "Current Folder")")
                    .font(.headline)
                
                Spacer()
                
                Text("\(items.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if items.isEmpty {
                Text("This folder is empty.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(items.prefix(25)) { item in
                        DiskItemRow(
                            item: item,
                            parentSize: totalFolderSize,
                            isHovered: scanner.hoveredNode?.id == item.id,
                            onDrillDown: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    scanner.drillDown(to: item)
                                }
                            },
                            onReveal: {
                                scanner.revealInFinder(node: item)
                            },
                            onOpen: {
                                scanner.openItem(node: item)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Disk Item Row
private struct DiskItemRow: View {
    let item: DiskNode
    let parentSize: Int64
    let isHovered: Bool
    let onDrillDown: () -> Void
    let onReveal: () -> Void
    let onOpen: () -> Void
    
    var body: some View {
        let percent = Double(item.size) / Double(max(1, parentSize))
        
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.color.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(item.color)
            }
            
            // Name and Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if item.fileCount > 1 {
                        Text("\(item.fileCount) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mini size distribution bar
                GeometryReader { barProxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(item.color)
                            .frame(width: max(3, barProxy.size.width * CGFloat(min(1.0, percent))), height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            // Percentage of parent
            Text(String(format: "%.1f%%", percent * 100))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Formatted size
            Text(item.formattedSize)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(width: 85, alignment: .trailing)
            
            // Action Buttons
            HStack(spacing: 4) {
                if item.canDrillDown {
                    Button(action: onDrillDown) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(.plain)
                    .help("Drill down into folder")
                }
                
                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(item.isVirtual)
                .opacity(item.isVirtual ? 0.35 : 1.0)
                .help(item.isVirtual ? "Virtual group cannot be revealed in Finder" : "Reveal in Finder")
                
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(item.isVirtual)
                .opacity(item.isVirtual ? 0.35 : 1.0)
                .help(item.isVirtual ? "Virtual group cannot be opened directly" : "Open File/App")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.yellow.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}
