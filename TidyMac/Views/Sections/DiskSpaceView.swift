import SwiftUI

struct DiskSpaceView: View {
    @ObservedObject var storage = StorageModel.shared
    
    var segments: [StorageSegment] {
        [
            StorageSegment(name: "System", bytes: storage.systemBytes, color: .purple),
            StorageSegment(name: "Applications", bytes: storage.appsBytes, color: .blue),
            StorageSegment(name: "Documents & Files", bytes: storage.documentsBytes, color: .green),
            StorageSegment(name: "Caches & Temporary", bytes: storage.cachesBytes, color: .orange),
            StorageSegment(name: "Other Data", bytes: storage.otherBytes, color: .teal),
            StorageSegment(name: "Free Space", bytes: storage.freeBytes, color: Color.secondary.opacity(0.2))
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(item: .diskSpace, statusText: "\(storage.formattedFree) Free", statusColor: .yellow)
                
                // Visual Storage Bar Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Macintosh HD")
                                .font(.headline)
                            Text("\(storage.formattedUsed) of \(storage.formattedTotal) Used (\(storage.percentUsedString))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { storage.refresh() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .rotationEffect(.degrees(storage.isRefreshing ? 360 : 0))
                                    .animation(storage.isRefreshing ? Animation.linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: storage.isRefreshing)
                                Text("Refresh")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    MultiSegmentBar(segments: segments, totalBytes: storage.totalBytes, height: 18)
                    
                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(segments) { seg in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(seg.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(seg.name)
                                        .font(.caption.weight(.medium))
                                    Text(ByteCountFormatter.string(fromByteCount: seg.bytes, countStyle: .file))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                
                // Major Directory Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Largest Storage Consumers")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    VStack(spacing: 8) {
                        DirectoryRow(name: "~/Library", category: "Application support, caches, containers", size: "48.2 GB", icon: "folder.fill", color: .orange)
                        DirectoryRow(name: "/Applications", category: "Installed macOS Applications", size: "38.6 GB", icon: "app.fill", color: .blue)
                        DirectoryRow(name: "~/Developer", category: "Xcode simulators, git repos, SDKs", size: "26.4 GB", icon: "hammer.fill", color: .purple)
                        DirectoryRow(name: "~/Downloads", category: "Downloaded files & DMGs", size: "18.1 GB", icon: "arrow.down.circle.fill", color: .green)
                        DirectoryRow(name: "~/Documents", category: "Personal work & documents", size: "14.5 GB", icon: "doc.fill", color: .teal)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct DirectoryRow: View {
    let name: String
    let category: String
    let size: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(size)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}
