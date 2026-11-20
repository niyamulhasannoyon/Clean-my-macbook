import SwiftUI

public struct SystemJunkView: View {
    @StateObject private var scanner = SystemJunkScanner.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var showCleanConfirmAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HeaderBannerView(
                        item: .systemJunk,
                        statusText: headerStatusText,
                        statusColor: headerStatusColor
                    )
                    
                    // Full Disk Access Banner
                    FDAPermissionBanner(featureName: "System Junk Scan & Clean")
                    
                    // Top Overview & Action Control Bar
                    VStack(spacing: 14) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("Selected for Cleaning")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if scanner.totalFoundSize > 0 {
                                        Text("(\(scanner.totalSelectedFilesCount) of \(scanner.totalFoundFilesCount) items)")
                                            .font(.caption)
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(scanner.formattedTotalSelectedSize)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    if scanner.totalFoundSize > 0 {
                                        Text("of \(scanner.formattedTotalFoundSize) found")
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Scan / Rescan Button
                            Button(action: {
                                if !fdaManager.hasFullDiskAccess {
                                    fdaManager.isShowingOnboardingSheet = true
                                } else {
                                    Task {
                                        await scanner.startScan()
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: !fdaManager.hasFullDiskAccess ? "lock.fill" : (scanner.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise"))
                                        .rotationEffect(.degrees(scanner.isScanning ? 360 : 0))
                                        .animation(
                                            scanner.isScanning ?
                                                Animation.linear(duration: 1.0).repeatForever(autoreverses: false) :
                                                .default,
                                            value: scanner.isScanning
                                        )
                                    Text(!fdaManager.hasFullDiskAccess ? "Scan Locked" : (scanner.isScanning ? "Scanning..." : "Rescan"))
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.06))
                                .foregroundColor(!fdaManager.hasFullDiskAccess ? .orange : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.isScanning || scanner.isCleaning)
                            
                            // Clean Button
                            if !fdaManager.hasFullDiskAccess {
                                Button(action: {
                                    fdaManager.isShowingOnboardingSheet = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                        Text("Grant Access to Clean")
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: Color.orange.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    showCleanConfirmAlert = true
                                }) {
                                    HStack(spacing: 8) {
                                        if scanner.isCleaning {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text(scanner.isCleaning ? "Cleaning..." : "Clean Selected")
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: canClean ? [Color.blue, Color.cyan] : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: canClean ? Color.blue.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canClean || scanner.isScanning || scanner.isCleaning)
                            }
                        }
                        
                        // Scan Progress Bar
                        if scanner.isScanning {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView(value: scanner.scanProgress)
                                    .progressViewStyle(.linear)
                                    .tint(.blue)
                                
                                HStack {
                                    Text(scanner.currentScanningStep)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(scanner.scanProgress * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        // Selection and Options Bar
                        HStack {
                            Button(action: {
                                scanner.toggleSelectAll(!scanner.allSelected)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: scanner.allSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(scanner.allSelected ? .blue : .secondary)
                                    Text(scanner.allSelected ? "Deselect All" : "Select All")
                                        .font(.subheadline)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(scanner.categories.isEmpty || scanner.isScanning)
                            
                            Spacer()
                            
                            // Optional Language Files Toggle
                            Toggle(isOn: $scanner.includeUnusedLanguages) {
                                HStack(spacing: 4) {
                                    Image(systemName: "character.book.closed")
                                        .foregroundColor(.pink)
                                    Text("Include Language Files (.lproj)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .onChange(of: scanner.includeUnusedLanguages) { _ in
                                Task {
                                    await scanner.startScan()
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    
                    // Categories List
                    if scanner.categories.isEmpty && !scanner.isScanning {
                        VStack(spacing: 12) {
                            Image(systemName: "trash.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No System Junk Scanned Yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Button("Start Scan Now") {
                                Task {
                                    await scanner.startScan()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach($scanner.categories) { $category in
                                CategoryCardView(category: $category)
                            }
                        }
                    }
                }
                .padding(24)
            }
            
            // Celebration Reclaimed Space Overlay
            if scanner.showReclaimedAnimation, let result = scanner.lastCleanResult {
                ReclaimedCelebrationView(result: result) {
                    scanner.showReclaimedAnimation = false
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task {
            // Automatically scan if first time
            if scanner.categories.allSatisfy({ $0.items.isEmpty }) && !scanner.isScanning {
                await scanner.startScan()
            }
        }
        .confirmationDialog(
            "Clean System Junk?",
            isPresented: $showCleanConfirmAlert,
            titleVisibility: .visible
        ) {
            Button("Move \(scanner.formattedTotalSelectedSize) to Trash", role: .destructive) {
                Task {
                    await scanner.performClean()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected junk files will be moved safely to your macOS Trash bin. You can review or restore them anytime in Finder.")
        }
    }
    
    private var canClean: Bool {
        fdaManager.hasFullDiskAccess && scanner.totalSelectedSize > 0 && !scanner.categories.isEmpty
    }
    
    private var headerStatusText: String {
        if !fdaManager.hasFullDiskAccess {
            return "Access Required"
        }
        if scanner.isScanning {
            return "Scanning..."
        }
        if scanner.totalFoundSize > 0 {
            return "\(scanner.formattedTotalFoundSize) Found"
        }
        return "Clean"
    }
    
    private var headerStatusColor: Color {
        if !fdaManager.hasFullDiskAccess { return .orange }
        if scanner.isScanning { return .blue }
        if scanner.totalFoundSize > 0 { return .orange }
        return .green
    }
}

// MARK: - Category Card View with Sub-Items Accordion

struct CategoryCardView: View {
    @Binding var category: JunkCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Category Header Row
            HStack(spacing: 14) {
                // Category Checkbox
                Button(action: {
                    category.isSelected.toggle()
                }) {
                    Image(systemName: checkboxIcon)
                        .foregroundColor(category.isSelected ? .blue : (category.isPartiallySelected ? .blue : .secondary))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                // Category Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [category.iconColor.opacity(0.85), category.iconColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: category.iconColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Title and Description
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if category.id.isOptionalScan {
                            Text("Optional")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.15))
                                .foregroundColor(.pink)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Items Count Pill
                if !category.items.isEmpty {
                    Text("\(category.items.count) items")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                }
                
                // Formatted Total Size
                Text(category.formattedTotalSize)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(category.totalSize > 0 ? .primary : .secondary.opacity(0.6))
                    .frame(minWidth: 70, alignment: .trailing)
                
                // Expand / Collapse Chevron Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        category.isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            )
            
            // Sub-Items Accordion List
            if category.isExpanded {
                VStack(spacing: 0) {
                    if category.items.isEmpty {
                        HStack {
                            Text("No items found in this location.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 52)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    } else {
                        ForEach($category.items) { $item in
                            Divider()
                                .padding(.leading, 50)
                            
                            HStack(spacing: 12) {
                                Toggle("", isOn: $item.isSelected)
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                    .padding(.leading, 18)
                                
                                Image(systemName: item.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(category.iconColor)
                                    .frame(width: 18)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(item.details)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(item.formattedSize)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 9)
                            .padding(.trailing, 16)
                            .background(
                                item.isSelected ?
                                    Color.blue.opacity(0.04) :
                                    Color.clear
                            )
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                )
                .padding(.top, 4)
            }
        }
    }
    
    private var checkboxIcon: String {
        if category.isSelected {
            return "checkmark.square.fill"
        } else if category.isPartiallySelected {
            return "minus.square.fill"
        } else {
            return "square"
        }
    }
}
