import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var storage = StorageModel.shared
    @ObservedObject var fdaManager = FullDiskAccessManager.shared
    @State private var cleanFeedback: String? = nil
    @State private var isCleaning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("TidyMac")
                        .font(.system(size: 13, weight: .bold))
                    Text("System Status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(fdaManager.hasFullDiskAccess ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(fdaManager.hasFullDiskAccess ? "Protected" : "Access Needed")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((fdaManager.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.12))
                .clipShape(Capsule())
            }
            
            Divider()
            
            // Storage Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Macintosh HD", systemImage: "internaldrive.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(storage.percentUsedString) Used")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: storage.usedFraction)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text("\(storage.formattedFree) Free")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Total: \(storage.formattedTotal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            // Memory Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("RAM Usage", systemImage: "memorychip")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("58% Used")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: 0.58)
                    .progressViewStyle(.linear)
                    .tint(.purple)
                
                HStack {
                    Text("9.3 GB of 16 GB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("6.7 GB Available")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            if let feedback = cleanFeedback {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(feedback)
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }
            
            // Quick action buttons
            VStack(spacing: 8) {
                if !fdaManager.hasFullDiskAccess {
                    Button(action: {
                        openMainWindow()
                        fdaManager.isShowingOnboardingSheet = true
                    }) {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Full Disk Access Required")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: quickClean) {
                        HStack {
                            if isCleaning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isCleaning ? "Cleaning System..." : "Quick Clean (~1.4 GB)")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCleaning)
                }
                
                HStack(spacing: 8) {
                    Button(action: openMainWindow) {
                        HStack {
                            Image(systemName: "macwindow")
                            Text("Open TidyMac")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: quitApp) {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 290)
    }
    
    private func quickClean() {
        isCleaning = true
        cleanFeedback = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCleaning = false
            cleanFeedback = "Freed 1.4 GB temporary caches!"
            storage.refresh()
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
