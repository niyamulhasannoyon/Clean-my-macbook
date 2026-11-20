import SwiftUI

/// A reusable, modern banner component displayed inside scan views when Full Disk Access is not granted.
/// Explains why the scan feature is disabled and provides quick actions to open System Settings or the guide.
struct FDAPermissionBanner: View {
    var featureName: String = "Scanning"
    var isCompact: Bool = false
    var onShowGuide: (() -> Void)? = nil
    
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared
    
    var body: some View {
        if !fdaManager.hasFullDiskAccess {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: isCompact ? 32 : 40, height: isCompact ? 32 : 40)
                        
                        Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                            .font(.system(size: isCompact ? 16 : 20))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Full Disk Access Required")
                                .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Feature Locked")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                        
                        Text("\(featureName) is disabled because macOS requires Full Disk Access to inspect system caches, protected user libraries, and application leftovers.")
                            .font(.system(size: isCompact ? 11 : 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                
                // Action Buttons
                HStack(spacing: 10) {
                    Button(action: {
                        fdaManager.openSystemSettings()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 11))
                            Text("Open System Settings")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if let onShowGuide = onShowGuide {
                            onShowGuide()
                        } else {
                            fdaManager.isShowingOnboardingSheet = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                            Text("Step-by-Step Guide")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        fdaManager.checkAccess()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .rotationEffect(.degrees(fdaManager.isChecking ? 360 : 0))
                                .animation(
                                    fdaManager.isChecking ?
                                        Animation.linear(duration: 0.8).repeatForever(autoreverses: false) :
                                        .default,
                                    value: fdaManager.isChecking
                                )
                            Text("Verify Access")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(fdaManager.isChecking)
                    
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            )
        }
    }
}
