import SwiftUI
import AppKit

public struct SmartScanView: View {
    @StateObject private var coordinator = SmartScanCoordinator.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @Binding var selectedNavigationItem: NavigationItem?
    
    public init(selectedNavigationItem: Binding<NavigationItem?> = .constant(nil)) {
        self._selectedNavigationItem = selectedNavigationItem
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Banner
                    HeaderBannerView(
                        item: .smartScan,
                        statusText: headerStatusText,
                        statusColor: headerStatusColor
                    )
                    
                    // Dry-Run Simulation Notice
                    DryRunBanner()
                    
                    // Full Disk Access Alert Banner
                    FDAPermissionBanner(featureName: "Smart Scan")
                    
                    // Error Banner
                    if let err = coordinator.errorMessage {
                        ModuleErrorBanner(
                            message: err,
                            onRetry: {
                                Task { await coordinator.startSmartScan() }
                            },
                            onDismiss: {
                                coordinator.errorMessage = nil
                            }
                        )
                    }
                    
                    // Main Hero Section (Idle / Scanning / Completed Summary)
                    heroVisualizerCard
                    
                    // When Completed: 4 Module Summary Breakdown Cards
                    if coordinator.state == .completed {
                        summaryCardsGrid
                        
                        // Bottom Actions Bar
                        summaryActionsBar
                    } else if case .idle = coordinator.state {
                        // 4 Pillar Overview Preview
                        idleModulesOverview
                    }
                }
                .padding(24)
            }
            
            // Celebration Confetti Modal
            if coordinator.state == .celebration, let result = coordinator.lastCleanResult {
                ReclaimedCelebrationView(result: result) {
                    coordinator.reset()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $coordinator.isShowingReviewSheet) {
            SmartScanReviewView(selectedNavigationItem: $selectedNavigationItem)
        }
    }
    
    // MARK: - Header Status Helpers
    private var headerStatusText: String {
        if !fdaManager.hasFullDiskAccess {
            return "Access Required"
        }
        switch coordinator.state {
        case .idle:
            return "Ready"
        case .scanning:
            return "Scanning..."
        case .completed:
            return "\(coordinator.summary.formattedTotalCleanable) Cleanable"
        case .cleaning:
            return "Cleaning..."
        case .celebration:
            return "Cleaned & Optimized"
        }
    }
    
    private var headerStatusColor: Color {
        if !fdaManager.hasFullDiskAccess { return .orange }
        switch coordinator.state {
        case .idle: return .cyan
        case .scanning: return .blue
        case .completed: return .green
        case .cleaning: return .orange
        case .celebration: return .green
        }
    }
    
    // MARK: - Hero Visualizer Card
    private var heroVisualizerCard: some View {
        VStack(spacing: 20) {
            ZStack {
                let isScanning: Bool = {
                    if case .scanning = coordinator.state { return true }
                    if case .cleaning = coordinator.state { return true }
                    return false
                }()
                
                // Outer glowing / pulsating ring
                Circle()
                    .stroke(
                        (!fdaManager.hasFullDiskAccess ? Color.orange : Color.cyan)
                            .opacity(isScanning ? 0.35 : 0.1),
                        lineWidth: 8
                    )
                    .frame(width: 175, height: 175)
                    .scaleEffect(isScanning ? 1.08 : 1.0)
                    .animation(
                        isScanning ?
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                            .default,
                        value: isScanning
                    )
                
                // Circular Progress Arc
                CircularProgressView(
                    progress: coordinator.progress,
                    lineWidth: 10,
                    gradientColors: !fdaManager.hasFullDiskAccess ? [.orange, .red] : (coordinator.state == .completed ? [.green, .teal] : [.cyan, .blue]),
                    showPercentText: isScanning,
                    title: isScanning ? (coordinator.state == .completed ? "Done" : "Analyzing") : nil
                )
                .frame(width: 145, height: 145)
                
                // Center Icon / Visuals
                if !fdaManager.hasFullDiskAccess {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.orange)
                } else {
                    switch coordinator.state {
                    case .idle:
                        Image(systemName: "sparkles")
                            .font(.system(size: 46))
                            .foregroundColor(.cyan)
                    case .scanning:
                        EmptyView()
                    case .completed:
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.green)
                    case .cleaning:
                        EmptyView()
                    case .celebration:
                        Image(systemName: "star.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.top, 10)
            
            // Hero Title & Description
            VStack(spacing: 6) {
                if !fdaManager.hasFullDiskAccess {
                    Text("Full Disk Access Required")
                        .font(.title3.weight(.bold))
                    Text("Grant Full Disk Access in macOS System Settings to enable deep system scanning.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                } else {
                    switch coordinator.state {
                    case .idle:
                        Text("Your Mac is Ready for a Smart Scan")
                            .font(.title3.weight(.bold))
                        Text("Quick scan evaluates System Junk, Large Files, Privacy Traces, and Performance optimization.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 500)
                        
                        // Single Scan Button
                        Button(action: {
                            Task {
                                await coordinator.startSmartScan()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Smart Scan")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .cyan.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        
                    case .scanning:
                        Text("Smart Scanning in Progress...")
                            .font(.title3.weight(.bold))
                        Text(coordinator.currentStepMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                        
                    case .completed:
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(coordinator.summary.formattedTotalCleanable)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Cleanable")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.green)
                        }
                        
                        Text("Smart Scan identified \(coordinator.summary.formattedTotalCleanable) across Junk, Large Files, Privacy and System Optimization.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                        
                    case .cleaning:
                        Text("Cleaning Your Mac...")
                            .font(.title3.weight(.bold))
                        Text(coordinator.currentStepMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                    case .celebration:
                        Text("Smart Cleanup Complete!")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
    }
    
    // MARK: - 4 Summary Cards Grid
    private var summaryCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            // 1. System Junk Card
            SmartSummaryCard(
                icon: "trash.fill",
                tintColor: .blue,
                title: "System Junk",
                valueText: coordinator.summary.formattedJunkSize,
                subtitleText: "User caches, logs, trash (\(coordinator.summary.junkFilesCount) items)",
                statusBadge: "Ready to Clean",
                statusColor: .blue,
                isSelected: $coordinator.summary.isJunkSelected,
                onReview: {
                    coordinator.activeReviewTab = .systemJunk
                    coordinator.isShowingReviewSheet = true
                }
            )
            
            // 2. Large & Old Files Card
            SmartSummaryCard(
                icon: "folder.badge.clock",
                tintColor: .teal,
                title: "Large & Old Files",
                valueText: coordinator.summary.formattedLargeFilesSize,
                subtitleText: "\(coordinator.summary.largeFilesCount) massive archives & old files (>100MB)",
                statusBadge: "Found",
                statusColor: .teal,
                isSelected: $coordinator.summary.isLargeFilesSelected,
                onReview: {
                    coordinator.activeReviewTab = .largeFiles
                    coordinator.isShowingReviewSheet = true
                }
            )
            
            // 3. Privacy Traces Card
            SmartSummaryCard(
                icon: "hand.raised.fill",
                tintColor: .purple,
                title: "Privacy Traces",
                valueText: coordinator.summary.formattedPrivacySize,
                subtitleText: "\(coordinator.summary.privacyFilesCount) tracking cookies, history & caches",
                statusBadge: "Traces Detected",
                statusColor: .purple,
                isSelected: $coordinator.summary.isPrivacySelected,
                onReview: {
                    coordinator.activeReviewTab = .privacy
                    coordinator.isShowingReviewSheet = true
                }
            )
            
            // 4. Performance & Speed Card
            SmartSummaryCard(
                icon: "bolt.circle.fill",
                tintColor: .cyan,
                title: "Performance & RAM",
                valueText: "\(coordinator.summary.formattedPurgeableRAM) RAM",
                subtitleText: "Purgeable buffers & \(coordinator.summary.performanceTasksCount) maintenance tasks",
                statusBadge: "Optimization Ready",
                statusColor: .green,
                isSelected: $coordinator.summary.isPerformanceSelected,
                onReview: {
                    coordinator.activeReviewTab = .performance
                    coordinator.isShowingReviewSheet = true
                }
            )
        }
    }
    
    // MARK: - Summary Actions Bar ("Review" & "Clean All")
    private var summaryActionsBar: some View {
        HStack(spacing: 16) {
            // Rescan button
            Button(action: {
                Task {
                    await coordinator.startSmartScan()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Rescan")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
                .foregroundColor(.secondary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // "Review" Button
            Button(action: {
                coordinator.activeReviewTab = .systemJunk
                coordinator.isShowingReviewSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Review Details")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.14))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // "Clean All" Primary Button
            Button(action: {
                Task {
                    await coordinator.performCleanAll()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Clean All (\(coordinator.summary.formattedTotalCleanable))")
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: coordinator.summary.totalCleanableBytes > 0 ? [.cyan, .blue] : [.gray, .secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(coordinator.summary.totalCleanableBytes == 0)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }
    
    // MARK: - Idle State Preview Highlights
    private var idleModulesOverview: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            IdleModulePill(icon: "trash.fill", color: .blue, title: "System Junk", desc: "User caches, logs, trash")
            IdleModulePill(icon: "folder.badge.clock", color: .teal, title: "Large Files", desc: "Old archives & downloads")
            IdleModulePill(icon: "hand.raised.fill", color: .purple, title: "Privacy Traces", desc: "Cookies & web history")
            IdleModulePill(icon: "bolt.circle.fill", color: .cyan, title: "Performance", desc: "Purgeable RAM & maintenance")
        }
    }
}

// MARK: - Interactive Smart Summary Card
private struct SmartSummaryCard: View {
    let icon: String
    let tintColor: Color
    let title: String
    let valueText: String
    let subtitleText: String
    let statusBadge: String
    let statusColor: Color
    @Binding var isSelected: Bool
    let onReview: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Checkbox + Icon + Title + Status Badge
            HStack(spacing: 10) {
                Toggle("", isOn: $isSelected)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tintColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tintColor)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Text(statusBadge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }
            
            // Value & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(valueText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Divider()
            
            // Card Footer: Review Button
            HStack {
                Spacer()
                Button(action: onReview) {
                    HStack(spacing: 4) {
                        Text("Review")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(tintColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isSelected ? 0.6 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? tintColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1.2)
        )
    }
}

// MARK: - Idle Module Pill
private struct IdleModulePill: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}
