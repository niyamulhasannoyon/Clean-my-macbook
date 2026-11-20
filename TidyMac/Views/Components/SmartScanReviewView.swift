import SwiftUI
import AppKit

public struct SmartScanReviewView: View {
    @ObservedObject var coordinator = SmartScanCoordinator.shared
    @Binding var selectedNavigationItem: NavigationItem?
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var junkScanner = SystemJunkScanner.shared
    @ObservedObject private var largeFilesScanner = LargeOldFilesScanner.shared
    @ObservedObject private var privacyScanner = PrivacyScanner.shared
    @ObservedObject private var performanceMonitor = PerformanceMonitor.shared
    @ObservedObject private var maintenanceService = MaintenanceService.shared
    
    public init(selectedNavigationItem: Binding<NavigationItem?>) {
        self._selectedNavigationItem = selectedNavigationItem
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Smart Scan Items")
                        .font(.title2.weight(.bold))
                    Text("Select or deselect items to include in your Smart Cleanup")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            
            Divider()
            
            // Tab Picker
            Picker("", selection: $coordinator.activeReviewTab) {
                ForEach(SmartScanModule.allCases) { module in
                    HStack(spacing: 6) {
                        Image(systemName: module.icon)
                        Text(module.rawValue)
                    }
                    .tag(module)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(spacing: 16) {
                    switch coordinator.activeReviewTab {
                    case .systemJunk:
                        junkReviewTab
                    case .largeFiles:
                        largeFilesReviewTab
                    case .privacy:
                        privacyReviewTab
                    case .performance:
                        performanceReviewTab
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Selected Cleanable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(coordinator.summary.formattedTotalCleanable)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Jump to dedicated section button
                Button(action: {
                    switch coordinator.activeReviewTab {
                    case .systemJunk:
                        selectedNavigationItem = .systemJunk
                    case .largeFiles:
                        selectedNavigationItem = .largeOldFiles
                    case .privacy:
                        selectedNavigationItem = .privacy
                    case .performance:
                        selectedNavigationItem = .performance
                    }
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Text("Open Full \(coordinator.activeReviewTab.rawValue) Section")
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 680, minHeight: 520)
    }
    
    // MARK: - 1. Junk Review Tab
    private var junkReviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("System Junk Categories (\(junkScanner.categories.count))")
                    .font(.headline)
                Spacer()
                Button(junkScanner.allSelected ? "Deselect All" : "Select All") {
                    junkScanner.toggleSelectAll(!junkScanner.allSelected)
                    coordinator.summary.junkBytes = junkScanner.totalSelectedSize
                }
                .font(.caption.weight(.semibold))
            }
            
            ForEach(junkScanner.categories) { cat in
                JunkCategoryReviewRow(cat: cat, junkScanner: junkScanner, coordinator: coordinator)
            }
        }
    }
    
    // MARK: - 2. Large Files Review Tab
    private var largeFilesReviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Identified Large & Old Files (\(largeFilesScanner.files.count))")
                    .font(.headline)
                Spacer()
                Text("\(largeFilesScanner.selectedFiles.count) selected (\(largeFilesScanner.formattedSelectedSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if largeFilesScanner.files.isEmpty {
                Text("No large or old files detected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(largeFilesScanner.files.prefix(20)) { file in
                    LargeFileReviewRow(file: file, largeFilesScanner: largeFilesScanner, coordinator: coordinator)
                }
            }
        }
    }
    
    // MARK: - 3. Privacy Review Tab
    private var privacyReviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Browser Privacy Traces & Cache")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.summary.formattedPrivacySize)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.purple)
            }
            
            ForEach(privacyScanner.items) { item in
                PrivacyItemReviewRow(item: item, privacyScanner: privacyScanner)
            }
        }
    }
    
    // MARK: - 4. Performance Review Tab
    private var performanceReviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("System Performance & Tuning")
                    .font(.headline)
                Spacer()
                Text("3 Routines Available")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.cyan)
            }
            
            // RAM Purge Tile
            HStack(spacing: 12) {
                Image(systemName: "memorychip")
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Purge Inactive Memory & Application Buffers")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Reclaims inactive cached RAM blocks for active foreground processes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(coordinator.summary.formattedPurgeableRAM)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            .cornerRadius(10)
            
            // Maintenance tasks
            ForEach(maintenanceService.tasks.prefix(3)) { task in
                HStack(spacing: 12) {
                    Image(systemName: task.icon)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 12, weight: .semibold))
                        Text(task.subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Ready")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.green)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Subcomponents to ensure fast type checking
private struct JunkCategoryReviewRow: View {
    let cat: JunkCategory
    @ObservedObject var junkScanner: SystemJunkScanner
    @ObservedObject var coordinator: SmartScanCoordinator
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { cat.isSelected },
                set: { newValue in
                    if let idx = junkScanner.categories.firstIndex(where: { $0.id == cat.id }) {
                        for itemIdx in junkScanner.categories[idx].items.indices {
                            junkScanner.categories[idx].items[itemIdx].isSelected = newValue
                        }
                        coordinator.summary.junkBytes = junkScanner.totalSelectedSize
                    }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: cat.icon)
                        .foregroundColor(.blue)
                    Text(cat.title)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            Text(cat.formattedSelectedSize)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }
}

private struct LargeFileReviewRow: View {
    let file: LargeOldFileItem
    @ObservedObject var largeFilesScanner: LargeOldFilesScanner
    @ObservedObject var coordinator: SmartScanCoordinator
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { file.isSelected },
                set: { newValue in
                    if let idx = largeFilesScanner.files.firstIndex(where: { $0.id == file.id }) {
                        largeFilesScanner.files[idx].isSelected = newValue
                        coordinator.summary.largeFilesBytes = largeFilesScanner.selectedSize
                    }
                }
            ))
            .labelsHidden()
            
            Image(systemName: file.fileType.icon)
                .foregroundColor(.teal)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(file.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
}

private struct PrivacyItemReviewRow: View {
    let item: PrivacyItem
    @ObservedObject var privacyScanner: PrivacyScanner
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { newValue in
                    if let idx = privacyScanner.items.firstIndex(where: { $0.id == item.id }) {
                        privacyScanner.items[idx].isEnabled = newValue
                    }
                }
            ))
            .labelsHidden()
            
            Image(systemName: item.browser.icon)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(item.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if item.sizeBytes > 0 {
                Text(item.formattedSize)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
}
