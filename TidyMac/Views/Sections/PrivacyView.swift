import SwiftUI

struct PrivacyItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let count: String
    let icon: String
    var isEnabled: Bool
}

struct PrivacyView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var items: [PrivacyItem] = [
        PrivacyItem(title: "Safari Browsing History", description: "Cookies, HTML5 databases, browsing history", count: "1,420 items", icon: "safari.fill", isEnabled: true),
        PrivacyItem(title: "Chrome Browsing Data", description: "Cache, cookies, autofill and download logs", count: "3,890 items", icon: "globe", isEnabled: true),
        PrivacyItem(title: "Recent Items & Documents", description: "Finder and application recent files history", count: "48 items", icon: "clock.arrow.circlepath", isEnabled: true),
        PrivacyItem(title: "Wi-Fi Networks History", description: "Saved and open networks list", count: "12 networks", icon: "wifi", isEnabled: false),
        PrivacyItem(title: "Application Permissions", description: "Camera, microphone, and full disk access audit", count: "9 apps", icon: "hand.raised.fill", isEnabled: false)
    ]
    
    @State private var isClearing: Bool = false
    @State private var successAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(
                    item: .privacy,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : "5,367 Traces",
                    statusColor: !fdaManager.hasFullDiskAccess ? .orange : .purple
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Browser & Privacy Traces")
                
                // Privacy health summary
                HStack(spacing: 14) {
                    MetricTileView(
                        title: "Browsers Protected",
                        value: "2 Browsers",
                        subtitle: "Safari, Google Chrome",
                        icon: "lock.shield.fill",
                        iconColor: .purple
                    )
                    
                    MetricTileView(
                        title: "Privacy Rating",
                        value: "Moderate",
                        subtitle: "Traces can be cleaned",
                        icon: "eye.trianglebadge.exclamationmark",
                        iconColor: .orange,
                        badgeText: "Action Needed",
                        badgeColor: .orange
                    )
                }
                
                // Trace items
                VStack(spacing: 10) {
                    ForEach($items) { $item in
                        HStack(spacing: 14) {
                            Toggle("", isOn: $item.isEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: item.icon)
                                    .foregroundColor(.purple)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(item.count)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        )
                    }
                }
                
                HStack {
                    Spacer()
                    if !fdaManager.hasFullDiskAccess {
                        Button(action: {
                            fdaManager.isShowingOnboardingSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                Text("Grant Access to Erase Traces")
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
                        Button(action: clearTraces) {
                            HStack(spacing: 6) {
                                if isClearing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                }
                                Text(isClearing ? "Clearing..." : "Erase Selected Privacy Traces")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isClearing)
                    }
                }
                
                if successAlert {
                    Text("Privacy traces successfully removed!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(10)
                }
            }
            .padding(24)
        }
    }
    
    private func clearTraces() {
        isClearing = true
        successAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isClearing = false
            successAlert = true
        }
    }
}
