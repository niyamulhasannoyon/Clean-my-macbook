import SwiftUI

struct CircularProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var gradientColors: [Color] = [.cyan, .blue]
    var showPercentText: Bool = true
    var title: String? = nil
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(progress, 0.0), 1.0)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            
            // Inner content
            VStack(spacing: 4) {
                if showPercentText {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                if let title = title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
