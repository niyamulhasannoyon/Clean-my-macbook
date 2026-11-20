import SwiftUI

struct SmartScanView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var scanState: ScanState = .idle
    @State private var progress: Double = 0.0
    @State private var statusMessage: String = "Click below to scan your Mac"
    
    enum ScanState {
        case idle
        case scanning
        case completed
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeaderBannerView(
                    item: .smartScan,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : (scanState == .completed ? "Protected" : "Ready"),
                    statusColor: !fdaManager.hasFullDiskAccess ? .orange : (scanState == .completed ? .green : .cyan)
                )
                
                // Full Disk Access Alert Banner
                FDAPermissionBanner(featureName: "Smart Scan")
                
                // Hero Scan Visualizer
                VStack(spacing: 20) {
                    ZStack {
                        // Outer pulsating ring
                        Circle()
                            .stroke(
                                (!fdaManager.hasFullDiskAccess ? Color.orange : Color.cyan)
                                    .opacity(scanState == .scanning ? 0.3 : 0.1),
                                lineWidth: 8
                            )
                            .frame(width: 170, height: 170)
                            .scaleEffect(scanState == .scanning ? 1.08 : 1.0)
                            .animation(
                                scanState == .scanning ?
                                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                    .default,
                                value: scanState
                            )
                        
                        CircularProgressView(
                            progress: scanState == .idle ? 0.0 : (scanState == .scanning ? progress : 1.0),
                            lineWidth: 10,
                            gradientColors: !fdaManager.hasFullDiskAccess ? [.orange, .red] : [.cyan, .blue],
                            showPercentText: scanState == .scanning,
                            title: scanState == .scanning ? "Analyzing" : nil
                        )
                        .frame(width: 140, height: 140)
                        
                        if !fdaManager.hasFullDiskAccess {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)
                        } else if scanState == .idle {
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundColor(.cyan)
                        } else if scanState == .completed {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 6) {
                        Text(!fdaManager.hasFullDiskAccess ? "Full Disk Access Required" :
                             (scanState == .idle ? "Your Mac is ready for a Smart Scan" :
                             (scanState == .scanning ? "Scanning System Components..." : "Smart Scan Finished!")))
                            .font(.title3.weight(.bold))
                        
                        Text(!fdaManager.hasFullDiskAccess ?
                             "Grant Full Disk Access in macOS System Settings to enable deep system scanning." :
                             statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 480)
                    }
                    
                    // Action Button
                    if !fdaManager.hasFullDiskAccess {
                        Button(action: {
                            fdaManager.isShowingOnboardingSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                Text("Grant Full Disk Access to Scan")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: startScan) {
                            HStack(spacing: 8) {
                                Image(systemName: scanState == .scanning ? "arrow.triangle.2.circlepath" : "play.fill")
                                    .rotationEffect(.degrees(scanState == .scanning ? 360 : 0))
                                    .animation(scanState == .scanning ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: scanState)
                                
                                Text(scanState == .idle ? "Start Smart Scan" :
                                     (scanState == .scanning ? "Scanning..." : "Clean 4.8 GB Junk"))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .cyan.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(scanState == .scanning)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
                
                // 3 Pillar Highlights
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    MetricTileView(
                        title: "Cleanup",
                        value: scanState == .completed ? "4.8 GB" : "Ready",
                        subtitle: "User caches, logs, trash",
                        icon: "trash.circle.fill",
                        iconColor: .blue,
                        badgeText: scanState == .completed ? "Ready to clean" : "Optimal",
                        badgeColor: scanState == .completed ? .orange : .green
                    )
                    
                    MetricTileView(
                        title: "Protection",
                        value: "Zero Threats",
                        subtitle: "No malware or adware",
                        icon: "shield.checkerboard",
                        iconColor: .green,
                        badgeText: "Secure",
                        badgeColor: .green
                    )
                    
                    MetricTileView(
                        title: "Speed",
                        value: "3 Tasks",
                        subtitle: "RAM & disk optimization",
                        icon: "bolt.circle.fill",
                        iconColor: .purple,
                        badgeText: "Recommended",
                        badgeColor: .cyan
                    )
                }
            }
            .padding(24)
        }
    }
    
    private func startScan() {
        if scanState == .completed {
            // Clean action
            scanState = .idle
            progress = 0.0
            statusMessage = "4.8 GB cleaned successfully!"
            return
        }
        
        scanState = .scanning
        progress = 0.0
        statusMessage = "Analyzing system logs and caches..."
        
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if progress < 0.3 {
                statusMessage = "Analyzing user and system caches..."
                progress += 0.05
            } else if progress < 0.7 {
                statusMessage = "Checking applications and old log files..."
                progress += 0.06
            } else if progress < 0.95 {
                statusMessage = "Verifying startup items and threat definitions..."
                progress += 0.05
            } else {
                timer.invalidate()
                progress = 1.0
                scanState = .completed
                statusMessage = "Scan complete! 4.8 GB can be safely removed."
            }
        }
    }
}
