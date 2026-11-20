import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .smartScan
    @ObservedObject var storage = StorageModel.shared
    @ObservedObject var fdaManager = FullDiskAccessManager.shared
    @ObservedObject var dryRun = DryRunManager.shared
    
    @AppStorage("hasSeenFDAOnboarding") private var hasSeenFDAOnboarding: Bool = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailView(selectedItem: $selectedItem)
        }
        .navigationTitle(selectedItem?.rawValue ?? "TidyMac")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    fdaManager.isShowingOnboardingSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: fdaManager.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                        
                        Text(fdaManager.hasFullDiskAccess ? "FDA: Granted" : "Grant Disk Access")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((fdaManager.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(fdaManager.hasFullDiskAccess ? "Full Disk Access is active and verified." : "Full Disk Access is required for scanning. Click for setup guide.")
                .accessibilityLabel(fdaManager.hasFullDiskAccess ? "Full Disk Access Granted" : "Full Disk Access Required")
                .accessibilityHint("Opens the Full Disk Access permissions setup guide")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    dryRun.isShowingSettingsSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: dryRun.isEnabled ? "shield.checkered" : "shield")
                            .foregroundColor(dryRun.isEnabled ? .orange : .secondary)
                        Text(dryRun.isEnabled ? "Dry-Run: ON" : "Dry-Run")
                            .font(.system(size: 11, weight: dryRun.isEnabled ? .bold : .regular))
                            .foregroundColor(dryRun.isEnabled ? .orange : .secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((dryRun.isEnabled ? Color.orange : Color.gray).opacity(dryRun.isEnabled ? 0.15 : 0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(dryRun.isEnabled ? "Dry-Run is ACTIVE: deletions are simulated safely. Click to configure." : "Dry-Run mode simulates file deletions without touching files. Click to configure.")
                .accessibilityLabel(dryRun.isEnabled ? "Dry-Run Simulation Mode Active" : "Dry-Run Mode Inactive")
                .accessibilityHint("Opens settings to toggle simulation mode and review activity log")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    storage.refresh()
                    fdaManager.checkAccess()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Storage & System Stats")
                .accessibilityLabel("Refresh Storage")
                .accessibilityHint("Reloads disk usage metrics and Full Disk Access permissions")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    selectedItem = .smartScan
                }) {
                    Label("Smart Clean", systemImage: "sparkles")
                        .foregroundColor(.cyan)
                }
                .help("Run Smart Scan")
                .accessibilityLabel("Smart Scan")
                .accessibilityHint("Navigates to the all-in-one Smart Scan module")
            }
        }
        .sheet(isPresented: $fdaManager.isShowingOnboardingSheet) {
            FullDiskAccessOnboardingView()
        }
        .sheet(isPresented: $dryRun.isShowingSettingsSheet) {
            SettingsView()
        }
        .onAppear {
            // Check FDA status on app launch; if missing, show onboarding guide
            fdaManager.checkAccess()
            if !fdaManager.hasFullDiskAccess && !hasSeenFDAOnboarding {
                fdaManager.isShowingOnboardingSheet = true
                hasSeenFDAOnboarding = true
            }
        }
        .frame(minWidth: 800, minHeight: 560)
    }
}
