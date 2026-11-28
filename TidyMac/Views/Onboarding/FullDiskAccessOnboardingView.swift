import SwiftUI
import AppKit
#if canImport(TidyMacCore)
import TidyMacCore
#endif

/// Onboarding and permission walkthrough view for macOS Full Disk Access.
/// Presents a clear, visual 4-step guide, explains system requirements,
/// and provides direct system settings deep-linking and real-time status verification.
struct FullDiskAccessOnboardingView: View {
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDiagnostics: Bool = false
    @State private var showSuccessAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Spacer()
                Button(action: {
                    fdaManager.isShowingOnboardingSheet = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close (Cmd+W)")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 22) {
                    // Hero Icon & Title
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: fdaManager.hasFullDiskAccess ?
                                            [.green.opacity(0.2), .mint.opacity(0.1)] :
                                            [.orange.opacity(0.2), .red.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 84, height: 84)
                            
                            Circle()
                                .stroke(
                                    fdaManager.hasFullDiskAccess ? Color.green.opacity(0.4) : Color.orange.opacity(0.4),
                                    lineWidth: 2
                                )
                                .frame(width: 84, height: 84)
                            
                            Image(systemName: fdaManager.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield.fill")
                                .font(.system(size: 42))
                                .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                                .shadow(color: (fdaManager.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.3), radius: 8)
                        }
                        
                        VStack(spacing: 6) {
                            Text(fdaManager.hasFullDiskAccess ? "Full Disk Access Granted!" : "Full Disk Access Required")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("TidyMac requires Full Disk Access to scan deep system caches, user libraries, mail attachments, and leftover app files.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .frame(maxWidth: 480)
                        }
                        
                        // Status Pill
                        HStack(spacing: 6) {
                            Circle()
                                .fill(fdaManager.hasFullDiskAccess ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text(fdaManager.hasFullDiskAccess ?
                                 "Status: Granted • All Scan Features Unlocked" :
                                 "Status: Not Granted • Scan Features Locked")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(fdaManager.hasFullDiskAccess ? .green : .orange)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            (fdaManager.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.12)
                        )
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                    
                    if !fdaManager.hasFullDiskAccess {
                        // 4-Step Instructions Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("How to Grant Permission in 4 Simple Steps")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 10) {
                                StepRow(
                                    number: 1,
                                    title: "Open System Settings",
                                    description: "Click the 'Open System Settings' button below. macOS will jump straight to the Full Disk Access settings page.",
                                    icon: "gearshape.fill",
                                    iconColor: .blue
                                )
                                
                                StepRow(
                                    number: 2,
                                    title: "Locate 'Full Disk Access'",
                                    description: "In Privacy & Security, verify that 'Full Disk Access' is selected in the list.",
                                    icon: "hand.raised.square.on.square.fill",
                                    iconColor: .purple
                                )
                                
                                StepRow(
                                    number: 3,
                                    title: "Enable the Toggle for TidyMac",
                                    description: "Find TidyMac in the applications list and toggle it ON. (If TidyMac isn't listed, click the '+' button to add it from Applications).",
                                    icon: "switch.2",
                                    iconColor: .orange
                                )
                                
                                StepRow(
                                    number: 4,
                                    title: "Return to TidyMac",
                                    description: "Switch back here. TidyMac automatically verifies permission and unlocks your smart scans instantly.",
                                    icon: "sparkles",
                                    iconColor: .green
                                )
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    } else {
                        // Granted Celebration Box
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            
                            Text("Your Mac is Ready for Deep Cleaning")
                                .font(.headline)
                            
                            Text("You can now safely scan user caches, system logs, Xcode build products, browser caches, and find duplicate files.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                    }
                    
                    // Diagnostic Section (Collapsible)
                    DisclosureGroup(
                        isExpanded: $showDiagnostics,
                        content: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("macOS TCC Sandbox Probe Results:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                
                                ForEach(Array(fdaManager.probeDiagnostics.keys.sorted()), id: \.self) { key in
                                    let success = fdaManager.probeDiagnostics[key] ?? false
                                    HStack {
                                        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(success ? .green : .red)
                                        Text(key)
                                            .font(.caption)
                                        Spacer()
                                        Text(success ? "Accessible" : "Denied (Protected)")
                                            .font(.caption2)
                                            .foregroundColor(success ? .green : .secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                            .cornerRadius(10)
                            .padding(.top, 6)
                        },
                        label: {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.secondary)
                                Text("Technical Diagnostics & Permission Probes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .padding(.horizontal, 28)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if !fdaManager.hasFullDiskAccess {
                            HStack(spacing: 14) {
                                // Primary CTA: Open System Settings
                                Button(action: {
                                    fdaManager.openSystemSettings()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.forward.app.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Open System Settings")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .red.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                                
                                // Secondary CTA: Check Permission
                                Button(action: {
                                    fdaManager.checkAccess()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                            .rotationEffect(.degrees(fdaManager.isChecking ? 360 : 0))
                                            .animation(
                                                fdaManager.isChecking ?
                                                    Animation.linear(duration: 0.8).repeatForever(autoreverses: false) :
                                                    .default,
                                                value: fdaManager.isChecking
                                            )
                                        Text(fdaManager.isChecking ? "Checking..." : "Verify Access")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .foregroundColor(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(fdaManager.isChecking)
                            }
                            
                            Button(action: {
                                fdaManager.isShowingOnboardingSheet = false
                                dismiss()
                            }) {
                                Text("Continue in Limited Mode (Scans Disabled)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        } else {
                            Button(action: {
                                fdaManager.isShowingOnboardingSheet = false
                                dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Start Using TidyMac")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(width: 580, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Step Row Helper Component

private struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                    
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(1.5)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}
