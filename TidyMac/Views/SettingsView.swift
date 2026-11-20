import SwiftUI

public struct SettingsView: View {
    @ObservedObject var dryRun = DryRunManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TidyMac Settings & Safety")
                        .font(.headline)
                    Text("Safety protections, simulation mode, and deletion safeguards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Dry-Run Mode Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Dry-Run Simulation Mode")
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    if dryRun.isEnabled {
                                        Text("ACTIVE")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text("When enabled, all scan actions proceed normally, but cleanup, file deletion, and uninstallation actions are simulated safely without deleting or modifying any files on disk.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $dryRun.isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                    }
                    
                    // Path Protection Safeguards Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BUILT-IN PATH PROTECTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            ProtectionBullet(
                                icon: "lock.shield.fill",
                                color: .green,
                                title: "System Integrity Protection (SIP) & Core OS",
                                description: "Crucial macOS system paths (/System, /bin, /sbin, /usr, /etc, /Library) are permanently blocked from any deletion or modification."
                            )
                            
                            ProtectionBullet(
                                icon: "person.crop.circle.badge.checkmark",
                                color: .blue,
                                title: "User Home & Essential Folder Safeguards",
                                description: "The user home folder itself (~), Desktop, Documents, Downloads, and Pictures root directories cannot be removed."
                            )
                            
                            ProtectionBullet(
                                icon: "key.fill",
                                color: .purple,
                                title: "Credentials, SSH Keys & Keychains",
                                description: "SSH keys (~/.ssh), GPG keys (~/.gnupg), shell configs (.zshrc, .bash_profile), and Keychain files are protected."
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                    }
                    
                    // Simulated Action History (if Dry-Run is active or has logs)
                    if !dryRun.simulatedActionsLog.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("SIMULATION LOG (\(dryRun.simulatedActionsLog.count) ACTIONS)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Clear Log") {
                                    dryRun.clearLog()
                                }
                                .font(.caption2)
                            }
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(dryRun.simulatedActionsLog.enumerated()), id: \.offset) { _, entry in
                                        Text(entry)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 2)
                                    }
                                }
                                .padding(10)
                            }
                            .frame(maxHeight: 140)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 540, height: 480)
    }
}

private struct ProtectionBullet: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
