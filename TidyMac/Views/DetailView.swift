import SwiftUI

struct DetailView: View {
    @Binding var selectedItem: NavigationItem?
    
    var body: some View {
        Group {
            if let item = selectedItem {
                switch item {
                case .smartScan:
                    SmartScanView(selectedNavigationItem: $selectedItem)
                case .systemJunk:
                    SystemJunkView()
                case .largeOldFiles:
                    LargeOldFilesView()
                case .duplicates:
                    DuplicatesView()
                case .appUninstaller:
                    AppUninstallerView()
                case .privacy:
                    PrivacyView()
                case .malwareScan:
                    MalwareScanView()
                case .maintenance:
                    MaintenanceView()
                case .performance:
                    PerformanceView()
                case .diskSpace:
                    DiskSpaceView()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a Section from the Sidebar")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 550, minHeight: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
