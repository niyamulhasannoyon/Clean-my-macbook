import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .smartScan
    @ObservedObject var storage = StorageModel.shared
    @ObservedObject var fdaManager = FullDiskAccessManager.shared
    
    @AppStorage("hasSeenFDAOnboarding") private var hasSeenFDAOnboarding: Bool = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailView(item: selectedItem)
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
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    storage.refresh()
                    fdaManager.checkAccess()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Storage & System Stats")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    selectedItem = .smartScan
                }) {
                    Label("Smart Clean", systemImage: "sparkles")
                        .foregroundColor(.cyan)
                }
                .help("Run Smart Scan")
            }
        }
        .sheet(isPresented: $fdaManager.isShowingOnboardingSheet) {
            FullDiskAccessOnboardingView()
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
