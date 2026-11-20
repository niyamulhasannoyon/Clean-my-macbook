import SwiftUI

struct BigFileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: String
    let lastOpened: String
    let fileType: FileType
    var isSelected: Bool = false
    
    enum FileType {
        case video, archive, document, diskImage
        
        var icon: String {
            switch self {
            case .video: return "film"
            case .archive: return "doc.zipper"
            case .document: return "doc.fill"
            case .diskImage: return "opticaldisc"
            }
        }
        
        var color: Color {
            switch self {
            case .video: return .purple
            case .archive: return .orange
            case .document: return .blue
            case .diskImage: return .teal
            }
        }
    }
}

struct LargeOldFilesView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var filterCategory: String = "All"
    @State private var files: [BigFileItem] = [
        BigFileItem(name: "macOS_Sonoma_Installer.dmg", path: "~/Downloads", size: "12.8 GB", lastOpened: "8 months ago", fileType: .diskImage),
        BigFileItem(name: "FinalCut_Project_Render_4K.mov", path: "~/Movies/Projects", size: "8.4 GB", lastOpened: "1 year ago", fileType: .video),
        BigFileItem(name: "Backup_2024_03.tar.gz", path: "~/Documents/Backups", size: "4.2 GB", lastOpened: "11 months ago", fileType: .archive),
        BigFileItem(name: "Dataset_MachineLearning_Large.csv", path: "~/Developer/ML", size: "2.1 GB", lastOpened: "6 months ago", fileType: .document),
        BigFileItem(name: "Screen_Recording_2024.mp4", path: "~/Desktop", size: "1.7 GB", lastOpened: "7 months ago", fileType: .video)
    ]
    
    let filters = ["All", "Videos", "Archives", "Documents", "Images/Disk"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(
                    item: .largeOldFiles,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : "29.2 GB Total",
                    statusColor: !fdaManager.hasFullDiskAccess ? .orange : .teal
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Large & Old Files Deep Scan")
                
                // Filter pills
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        Button(action: { filterCategory = filter }) {
                            Text(filter)
                                .font(.subheadline)
                                .fontWeight(filterCategory == filter ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    filterCategory == filter ?
                                        Color.teal :
                                        Color(nsColor: .controlBackgroundColor).opacity(0.6)
                                )
                                .foregroundColor(filterCategory == filter ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                
                // Files list
                VStack(spacing: 8) {
                    ForEach($files) { $file in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $file.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(file.fileType.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: file.fileType.icon)
                                    .foregroundColor(file.fileType.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(file.path)
                                    Text("•")
                                    Text("Opened: \(file.lastOpened)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(file.size)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                                Text("Grant Access to Remove Files")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("Remove Selected Files") {
                            files.removeAll { $0.isSelected }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                        .disabled(!files.contains { $0.isSelected })
                    }
                }
            }
            .padding(24)
        }
    }
}
