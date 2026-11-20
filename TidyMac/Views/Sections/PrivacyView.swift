import SwiftUI

struct PrivacyView: View {
    @ObservedObject private var scanner = PrivacyScanner.shared
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner
                HeaderBannerView(
                    item: .privacy,
                    statusText: "\(scanner.items.filter { $0.isEnabled && $0.isAvailable }.count) Selected",
                    statusColor: .purple
                )
                
                // Dry-Run Notice
                DryRunBanner()
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Browser History & Privacy Traces")
                
                // Module Error Banner
                if let err = scanner.scanError {
                    ModuleErrorBanner(
                        message: err,
                        onRetry: {
                            scanner.scan()
                        },
                        onDismiss: {
                            scanner.scanError = nil
                        }
                    )
                }
                
                // Running Browser Warning Banner
                if let runningBrowser = scanner.runningBrowserWarning {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(runningBrowser.rawValue) is Currently Running")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Browsers must be closed before clearing history and cookies to prevent database corruption.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Quit \(runningBrowser.processName)") {
                            scanner.quitBrowser(runningBrowser)
                            scanner.runningBrowserWarning = nil
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            scanner.runningBrowserWarning = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Success Alert Banner
                if scanner.showSuccessAlert {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Traces Erased Successfully!")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                            if scanner.lastReclaimedBytes > 0 {
                                Text("Reclaimed \(ByteCountFormatter.string(fromByteCount: scanner.lastReclaimedBytes, countStyle: .file)) of storage.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            scanner.showSuccessAlert = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(10)
                }
                
                // Privacy Summary Tiles
                HStack(spacing: 14) {
                    MetricTileView(
                        title: "Available Cleaners",
                        value: "\(BrowserType.allCases.count) Categories",
                        subtitle: "Safari, Chrome, Firefox, System",
                        icon: "lock.shield.fill",
                        iconColor: .purple
                    )
                    
                    let totalSize = scanner.items.reduce(0) { $0 + $1.sizeBytes }
                    MetricTileView(
                        title: "Detected Traces",
                        value: ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file),
                        subtitle: "\(scanner.items.reduce(0) { $0 + $1.fileCount }) trace items",
                        icon: "eye.trianglebadge.exclamationmark",
                        iconColor: .indigo
                    )
                }
                
                // Browser Sections
                ForEach(BrowserType.allCases) { browser in
                    let browserItems = scanner.items.filter { $0.browser == browser }
                    let isRunning = scanner.isBrowserRunning(browser)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Browser Header
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(browser.tintColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: browser.icon)
                                    .font(.system(size: 15))
                                    .foregroundColor(browser.tintColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 8) {
                                    Text(browser.rawValue)
                                        .font(.system(size: 15, weight: .bold))
                                    
                                    if browser != .recentItems {
                                        if isRunning {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 6, height: 6)
                                                Text("Running (Close to clean)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.12))
                                            .clipShape(Capsule())
                                        } else {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                                Text("Closed")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.green)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if isRunning && browser != .recentItems {
                                Button("Quit App") {
                                    scanner.quitBrowser(browser)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .buttonStyle(.plain)
                            }
                            
                            Button("Select All") {
                                scanner.toggleAll(for: browser, isEnabled: true)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Button("Deselect") {
                                scanner.toggleAll(for: browser, isEnabled: false)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                        
                        // Items List with individual toggles
                        VStack(spacing: 8) {
                            ForEach(browserItems) { item in
                                if let idx = scanner.items.firstIndex(where: { $0.id == item.id }) {
                                    HStack(spacing: 12) {
                                        Toggle("", isOn: $scanner.items[idx].isEnabled)
                                            .toggleStyle(.checkbox)
                                            .labelsHidden()
                                        
                                        Image(systemName: item.category.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(browser.tintColor)
                                            .frame(width: 22)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 13, weight: .medium))
                                            Text(item.description)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(item.formattedSize)
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(scanner.items[idx].isEnabled ? browser.tintColor.opacity(0.04) : Color.clear)
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
                
                // Bottom Action Bar
                HStack {
                    Button(action: {
                        scanner.scan()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Re-scan")
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if !fdaManager.hasFullDiskAccess {
                        Button(action: {
                            fdaManager.isShowingOnboardingSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                Text("Grant Access to Clear Traces")
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
                        Button(action: {
                            scanner.clearSelected()
                        }) {
                            HStack(spacing: 8) {
                                if scanner.isClearing {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Clearing Traces...")
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Clear Selected Privacy Traces")
                                }
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(scanner.isClearing || !scanner.items.contains(where: { $0.isEnabled }))
                    }
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
    }
}
