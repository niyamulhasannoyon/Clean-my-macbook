import SwiftUI

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let fileName: String
    let fileCount: Int
    let wastedSpace: String
    let category: String
    let icon: String
}

struct DuplicatesView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @State private var duplicateGroups: [DuplicateGroup] = [
        DuplicateGroup(fileName: "IMG_3920_Edited.jpeg", fileCount: 3, wastedSpace: "24.5 MB", category: "Photos", icon: "photo.fill"),
        DuplicateGroup(fileName: "Contract_Signed_Final_v2.pdf", fileCount: 4, wastedSpace: "18.2 MB", category: "Documents", icon: "doc.fill"),
        DuplicateGroup(fileName: "Project_Assets_Export.zip", fileCount: 2, wastedSpace: "420.0 MB", category: "Archives", icon: "doc.zipper"),
        DuplicateGroup(fileName: "Podcast_Episode_12_Master.wav", fileCount: 2, wastedSpace: "1.1 GB", category: "Audio", icon: "waveform")
    ]
    
    @State private var isScanning: Bool = false
    @State private var cleanMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(
                    item: .duplicates,
                    statusText: !fdaManager.hasFullDiskAccess ? "Access Required" : "1.56 GB Duplicates",
                    statusColor: !fdaManager.hasFullDiskAccess ? .orange : .indigo
                )
                
                // Full Disk Access Banner
                FDAPermissionBanner(featureName: "Duplicate File Finder")
                
                // Stat cards
                HStack(spacing: 14) {
                    MetricTileView(
                        title: "Wasted Space",
                        value: "1.56 GB",
                        subtitle: "Across 4 categories",
                        icon: "square.2.layers.3d.top.filled",
                        iconColor: .indigo
                    )
                    
                    MetricTileView(
                        title: "Duplicate Files",
                        value: "11 Files",
                        subtitle: "Exact hash matches",
                        icon: "doc.on.doc.fill",
                        iconColor: .indigo
                    )
                }
                
                // List of duplicate clusters
                VStack(spacing: 12) {
                    ForEach(duplicateGroups) { group in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.indigo.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: group.icon)
                                    .foregroundColor(.indigo)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.fileName)
                                    .font(.system(size: 14, weight: .semibold))
                                HStack(spacing: 6) {
                                    Text("\(group.fileCount) exact copies found")
                                    Text("•")
                                    Text(group.category)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(group.wastedSpace)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Button("Auto-Select Duplicates") {
                                    // action
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.indigo)
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
                
                HStack {
                    Spacer()
                    if !fdaManager.hasFullDiskAccess {
                        Button(action: {
                            fdaManager.isShowingOnboardingSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                Text("Grant Access to Clean Duplicates")
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
                        Button("Clean All Duplicates") {
                            cleanMessage = "Freed 1.56 GB of duplicate space!"
                            duplicateGroups.removeAll()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                        .disabled(duplicateGroups.isEmpty)
                    }
                }
                
                if let message = cleanMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding()
                }
            }
            .padding(24)
        }
    }
}
