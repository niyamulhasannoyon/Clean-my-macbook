import SwiftUI

struct StorageSegment: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int64
    let color: Color
}

struct MultiSegmentBar: View {
    let segments: [StorageSegment]
    let totalBytes: Int64
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let fraction = totalBytes > 0 ? max(0.01, Double(segment.bytes) / Double(totalBytes)) : 0.1
                    let segWidth = max(4, availableWidth * CGFloat(fraction) - 2)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segment.color)
                        .frame(width: segWidth, height: height)
                        .help("\(segment.name): \(ByteCountFormatter.string(fromByteCount: segment.bytes, countStyle: .file))")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.08))
            )
        }
        .frame(height: height)
    }
}
