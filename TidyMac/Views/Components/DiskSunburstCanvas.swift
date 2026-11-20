import SwiftUI

public struct DiskSunburstCanvas: View {
    @ObservedObject var scanner: DiskSpaceScanner
    
    @State private var hoverLocation: CGPoint? = nil
    @State private var isCenterHovered: Bool = false
    
    public init(scanner: DiskSpaceScanner) {
        self.scanner = scanner
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let maxRadius = min(size.width, size.height) / 2.0 - 15.0
            let centerRadius: CGFloat = max(45, min(75, maxRadius * 0.32))
            
            let current = scanner.currentNode ?? scanner.rootNode
            let (segments, centerRect) = current != nil ?
                SunburstLayoutEngine.layout(
                    rootNode: current!,
                    center: center,
                    maxRadius: maxRadius,
                    centerRadius: centerRadius,
                    ringThickness: max(32, (maxRadius - centerRadius) * 0.44),
                    gap: 3.0
                ) : ([], CGRect.zero)
            
            ZStack {
                Canvas { context, canvasSize in
                    guard maxRadius > 20 else { return }
                    
                    // 1. Draw Ring Segments
                    for seg in segments {
                        let isHovered = scanner.hoveredNode?.id == seg.node.id
                        var path = Path()
                        path.addArc(
                            center: center,
                            radius: seg.outerRadius,
                            startAngle: Angle(radians: seg.startAngle),
                            endAngle: Angle(radians: seg.endAngle),
                            clockwise: false
                        )
                        path.addArc(
                            center: center,
                            radius: seg.innerRadius,
                            startAngle: Angle(radians: seg.endAngle),
                            endAngle: Angle(radians: seg.startAngle),
                            clockwise: true
                        )
                        path.closeSubpath()
                        
                        let baseColor = seg.color
                        context.fill(
                            path,
                            with: .color(baseColor.opacity(isHovered ? 0.95 : 0.8))
                        )
                        
                        if isHovered {
                            context.stroke(path, with: .color(.white), lineWidth: 2.5)
                        } else {
                            context.stroke(path, with: .color(Color.black.opacity(0.15)), lineWidth: 1.0)
                        }
                        
                        // Segment Labels if wide enough
                        let angularSpan = seg.endAngle - seg.startAngle
                        let midAngle = (seg.startAngle + seg.endAngle) / 2.0
                        let midRadius = (seg.innerRadius + seg.outerRadius) / 2.0
                        let arcLength = CGFloat(angularSpan) * midRadius
                        
                        if arcLength > 36 {
                            let textX = center.x + midRadius * CGFloat(cos(midAngle))
                            let textY = center.y + midRadius * CGFloat(sin(midAngle))
                            
                            let label = seg.node.name
                            let text = Text(label)
                                .font(.system(size: min(10, arcLength / 5), weight: .bold))
                                .foregroundColor(.white)
                            
                            context.draw(text, at: CGPoint(x: textX, y: textY), anchor: .center)
                        }
                    }
                    
                    // 2. Draw Center Circle (Current Root)
                    let centerPath = Path(ellipseIn: centerRect)
                    let centerBg = isCenterHovered ? Color.cyan.opacity(0.2) : Color(nsColor: .controlBackgroundColor).opacity(0.9)
                    context.fill(centerPath, with: .color(centerBg))
                    context.stroke(
                        centerPath,
                        with: .color(isCenterHovered ? Color.cyan : Color.primary.opacity(0.15)),
                        lineWidth: isCenterHovered ? 2.5 : 1.5
                    )
                    
                    // Center labels
                    if let curr = current {
                        let canGoUp = scanner.breadcrumbs.count > 1
                        let titleYOffset: CGFloat = canGoUp ? -12 : -6
                        
                        let titleText = Text(curr.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                        context.draw(titleText, at: CGPoint(x: center.x, y: center.y + titleYOffset), anchor: .center)
                        
                        let sizeText = Text(curr.formattedSize)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        context.draw(sizeText, at: CGPoint(x: center.x, y: center.y + titleYOffset + 14), anchor: .center)
                        
                        if canGoUp {
                            let upHint = Text("Click to go up")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.cyan)
                            context.draw(upHint, at: CGPoint(x: center.x, y: center.y + titleYOffset + 26), anchor: .center)
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoverLocation = location
                        let dx = location.x - center.x
                        let dy = location.y - center.y
                        let r = hypot(dx, dy)
                        
                        if r <= centerRadius {
                            isCenterHovered = true
                            scanner.hoveredNode = current
                        } else {
                            isCenterHovered = false
                            var theta = Double(atan2(dy, dx))
                            // Normalize to match segment range [-π/2 ... 3π/2]
                            if theta < -Double.pi / 2.0 {
                                theta += 2.0 * Double.pi
                            }
                            
                            if let hit = segments.first(where: {
                                r >= $0.innerRadius && r <= $0.outerRadius &&
                                theta >= $0.startAngle && theta <= $0.endAngle
                            }) {
                                scanner.hoveredNode = hit.node
                            } else {
                                scanner.hoveredNode = nil
                            }
                        }
                    case .ended:
                        hoverLocation = nil
                        isCenterHovered = false
                        scanner.hoveredNode = nil
                    }
                }
                .onTapGesture { location in
                    let dx = location.x - center.x
                    let dy = location.y - center.y
                    let r = hypot(dx, dy)
                    
                    if r <= centerRadius {
                        // Clicked center -> Drill Up
                        if scanner.breadcrumbs.count > 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                scanner.drillUp()
                            }
                        }
                    } else {
                        var theta = Double(atan2(dy, dx))
                        if theta < -Double.pi / 2.0 {
                            theta += 2.0 * Double.pi
                        }
                        
                        if let hit = segments.first(where: {
                            r >= $0.innerRadius && r <= $0.outerRadius &&
                            theta >= $0.startAngle && theta <= $0.endAngle
                        }) {
                            if hit.node.isDirectory && !hit.node.children.isEmpty {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    scanner.drillDown(to: hit.node)
                                }
                            } else {
                                scanner.selectedNode = hit.node
                            }
                        }
                    }
                }
            }
        }
    }
}
