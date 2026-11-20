import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem?
    @ObservedObject var storage = StorageModel.shared
    @ObservedObject var fdaManager = FullDiskAccessManager.shared
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Sidebar List with Categories
            List(selection: $selectedItem) {
                ForEach(NavigationCategory.allCases) { category in
                    let filteredItems = category.items.filter { item in
                        searchText.isEmpty || item.rawValue.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    if !filteredItems.isEmpty {
                        Section(header: Text(category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        ) {
                            ForEach(filteredItems) { item in
                                NavigationLink(value: item) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(item.tintColor.opacity(0.18))
                                                .frame(width: 26, height: 26)
                                            
                                            Image(systemName: item.icon)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(item.tintColor)
                                        }
                                        
                                        Text(item.rawValue)
                                            .font(.system(size: 13, weight: selectedItem == item ? .semibold : .regular))
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 3)
                                }
                                .accessibilityLabel(item.rawValue)
                                .accessibilityHint("Navigates to the \(item.rawValue) module")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search TidyMac...")
            
            // Full Disk Access Banner in Sidebar
            if !fdaManager.hasFullDiskAccess {
                Divider()
                
                Button(action: {
                    fdaManager.isShowingOnboardingSheet = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Disk Access Required")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Tap to open setup guide")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Full Disk Access Setup Required")
                .accessibilityHint("Opens the Full Disk Access permissions setup guide")
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            
            Divider()
            
            // Bottom Quick Storage Status in Sidebar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("Macintosh HD")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(storage.percentFreeString + " Free")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: storage.usedFraction)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text("\(storage.formattedFree) available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(storage.formattedTotal)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        }
        .frame(minWidth: 230, idealWidth: 250, maxWidth: 300)
    }
}
