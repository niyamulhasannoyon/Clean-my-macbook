import SwiftUI

/// Reusable banner displayed when an error or warning occurs in any module.
public struct ModuleErrorBanner: View {
    public let message: String
    public let onRetry: (() -> Void)?
    public let onDismiss: () -> Void
    
    public init(
        message: String,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Attention Required")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Dismiss Error")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

/// Reusable indicator showing that Dry-Run simulation mode is active.
public struct DryRunBanner: View {
    @ObservedObject var dryRun = DryRunManager.shared
    
    public init() {}
    
    public var body: some View {
        if dryRun.isEnabled {
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Dry-Run Mode Enabled")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("• SIMULATION ONLY")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    Text("Clean actions are simulated without deleting or modifying any files on disk.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    dryRun.isShowingSettingsSheet = true
                }) {
                    Text("Settings")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }
}

/// Reusable full loading state view for when a module is scanning or processing.
public struct ModuleLoadingStateView: View {
    public let title: String
    public let subtitle: String
    public let progress: Double?
    public let tintColor: Color
    
    public init(
        title: String = "Scanning in progress...",
        subtitle: String = "Analyzing system paths and calculating sizes",
        progress: Double? = nil,
        tintColor: Color = .blue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.tintColor = tintColor
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(tintColor)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let p = progress, p > 0 {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .tint(tintColor)
                    .frame(width: 200)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        )
        .padding(.horizontal)
    }
}
