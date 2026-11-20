import SwiftUI

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let size: String
    let leftovers: String
    let iconName: String
    var isSelected: Bool = false
}

struct AppUninstallerView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var apps: [AppInfo] = [
        AppInfo(name: "Google Chrome", version: "131.0", size: "1.42 GB", leftovers: "320 MB caches", iconName: "globe"),
        AppInfo(name: "Slack", version: "4.36.0", size: "890 MB", leftovers: "210 MB cache", iconName: "bubble.left.and.bubble.right.fill"),
        AppInfo(name: "Visual Studio Code", version: "1.95.0", size: "950 MB", leftovers: "4.8 GB extensions/data", iconName: "chevron.left.forwardslash.chevron.right"),
        AppInfo(name: "Spotify", version: "1.2.50", size: "380 MB", leftovers: "1.8 GB offline cache", iconName: "music.note"),
        AppInfo(name: "Docker Desktop", version: "4.35.0", size: "2.1 GB", leftovers: "14.2 GB virtual disk", iconName: "shippingbox.fill")
    ]
    
    @State private var searchText: String = ""
    @State private var uninstallMessage: String? = nil
    
    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(
                    item: .appUninstaller,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : "\(apps.count) Applications",
                    statusColor: .orange
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "App Uninstaller & Leftover Removal")
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search installed applications...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
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
                
                if let message = uninstallMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(8)
                }
                
                // Apps List
                VStack(spacing: 10) {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: app.iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name)
                                    .font(.system(size: 14, weight: .semibold))
                                HStack(spacing: 8) {
                                    Text("v\(app.version)")
                                    Text("•")
                                    Text(app.leftovers)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(app.size)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                
                                Button(action: {
                                    if !fdaManager.hasFullDiskAccess {
                                        fdaManager.isShowingOnboardingSheet = true
                                    } else {
                                        uninstallApp(app)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if !fdaManager.hasFullDiskAccess {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9))
                                        }
                                        Text(!fdaManager.hasFullDiskAccess ? "Locked (FDA)" : "Complete Uninstall")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(!fdaManager.hasFullDiskAccess ? .orange : .red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        )
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func uninstallApp(_ app: AppInfo) {
        uninstallMessage = "\(app.name) and all associated cache & preferences removed!"
        apps.removeAll { $0.id == app.id }
    }
}
