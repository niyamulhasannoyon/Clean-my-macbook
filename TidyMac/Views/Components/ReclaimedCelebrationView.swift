import SwiftUI
#if canImport(TidyMacCore)
import TidyMacCore
#endif

public struct AnimatableByteCountModifier: AnimatableModifier {
    public var bytes: Double
    
    public var animatableData: Double {
        get { bytes }
        set { bytes = newValue }
    }
    
    public func body(content: Content) -> some View {
        Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            .font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.green, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

public struct ConfettiParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var scale: CGFloat
    public var opacity: Double
    public var color: Color
    public var rotation: Double
}

public struct ReclaimedCelebrationView: View {
    let result: CleanResult
    let onDismiss: () -> Void
    
    @State private var animatedBytes: Double = 0
    @State private var showContent: Bool = false
    @State private var pulseRing: Bool = false
    @State private var particles: [ConfettiParticle] = []
    
    public init(result: CleanResult, onDismiss: @escaping () -> Void) {
        self.result = result
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Dark translucent frosted backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Confetti particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: 8 * p.scale, height: 8 * p.scale)
                    .rotationEffect(.degrees(p.rotation))
                    .position(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }
            
            // Main Modal Card
            VStack(spacing: 22) {
                // Header with Pulsing Success Icon
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.25), lineWidth: pulseRing ? 16 : 4)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseRing ? 1.25 : 1.0)
                        .opacity(pulseRing ? 0.0 : 0.8)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showContent ? 1.0 : 0.4)
                }
                .padding(.top, 8)
                
                // Titles and Animated Counter
                VStack(spacing: 6) {
                    Text(result.isDryRun ? "Dry-Run Simulation Complete" : "Cleanup Complete!")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text(result.isDryRun ? "Simulated reclaim (no files were modified or deleted):" : "Space successfully reclaimed & moved to macOS Trash:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Animated rolling counter
                    EmptyView()
                        .modifier(AnimatableByteCountModifier(bytes: animatedBytes))
                        .padding(.vertical, 4)
                    
                    Text(result.isDryRun ? "\(result.reclaimedFilesCount) files simulated safely" : "\(result.reclaimedFilesCount) files transferred safely")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                // Category Pills Breakdown
                if !result.cleanedCategorySizes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reclaimed by Category")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(Array(result.cleanedCategorySizes.keys), id: \.self) { cat in
                                if let size = result.cleanedCategorySizes[cat], size > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .foregroundColor(cat.tintColor)
                                            .font(.caption)
                                        Text(cat.rawValue)
                                            .font(.caption2.weight(.medium))
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(cat.tintColor.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    )
                }
                
                // Safety notice badge
                HStack(spacing: 8) {
                    Image(systemName: result.isDryRun ? "shield.fill" : "checkmark.shield.fill")
                        .foregroundColor(result.isDryRun ? .orange : .green)
                    Text(result.isDryRun ?
                        "Dry-Run Mode: No files were touched or deleted. Safe preview completed." :
                        "Safe & Reversible: All files were placed in Trash. You can restore them anytime via Finder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background((result.isDryRun ? Color.orange : Color.green).opacity(0.08))
                .cornerRadius(10)
                
                // Dismiss Action Button
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .frame(width: 460)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
            )
            .scaleEffect(showContent ? 1.0 : 0.85)
            .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            // Trigger animations
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                showContent = true
            }
            
            withAnimation(.easeOut(duration: 1.4)) {
                animatedBytes = Double(result.reclaimedBytes)
            }
            
            withAnimation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulseRing = true
            }
            
            generateConfetti()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.green, .cyan, .blue, .orange, .pink, .yellow]
        var list: [ConfettiParticle] = []
        for _ in 0..<35 {
            let x = CGFloat.random(in: 100...450)
            let y = CGFloat.random(in: 100...400)
            let particle = ConfettiParticle(
                x: x,
                y: y,
                scale: CGFloat.random(in: 0.6...1.4),
                opacity: Double.random(in: 0.4...0.9),
                color: colors.randomElement() ?? .cyan,
                rotation: Double.random(in: 0...360)
            )
            list.append(particle)
        }
        self.particles = list
    }
}

// Simple Horizontal FlowLayout for category pills
public struct FlowLayout: Layout {
    public var spacing: CGFloat = 8
    
    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
