import SwiftUI
#if canImport(TidyMacCore)
import TidyMacCore
#endif

private final class TreemapLayoutCache: ObservableObject {
    private struct CacheKey: Equatable {
        let nodeID: UUID?
        let nodeSize: Int64
        let childSignatures: [ChildSignature]
        let size: CGSize

        struct ChildSignature: Equatable {
            let id: UUID
            let size: Int64
        }
    }

    private var lastKey: CacheKey?
    private var cachedItems: [TreemapItem] = []

    func items(for currentNode: DiskNode?, children: [DiskNode], size: CGSize) -> [TreemapItem] {
        let signatures = children.map {
            CacheKey.ChildSignature(id: $0.id, size: $0.size)
        }
        let key = CacheKey(
            nodeID: currentNode?.id,
            nodeSize: currentNode?.size ?? 0,
            childSignatures: signatures,
            size: size
        )

        if key == lastKey {
            return cachedItems
        }

        let computed = TreemapLayoutEngine.layout(
            nodes: children,
            in: CGRect(origin: .zero, size: size),
            padding: 2.0
        )
        lastKey = key
        cachedItems = computed
        return computed
    }
}

public struct DiskTreemapCanvas: View {
    @ObservedObject var scanner: DiskSpaceScanner
    @StateObject private var layoutCache = TreemapLayoutCache()
    
    public init(scanner: DiskSpaceScanner) {
        self.scanner = scanner
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let children = (scanner.currentNode?.children ?? []).filter { $0.size > 0 }
            let items = layoutCache.items(for: scanner.currentNode, children: children, size: size)
            
            ZStack {
                Canvas { context, canvasSize in
                    for item in items {
                        let isHovered = scanner.hoveredNode?.id == item.node.id
                        let isSelected = scanner.selectedNode?.id == item.node.id
                        let rect = item.rect
                        guard rect.width > 1, rect.height > 1 else { continue }
                        
                        let path = Path(roundedRect: rect, cornerRadius: 6)
                        
                        // Fill with vibrant color gradient
                        let baseColor = item.color
                        let fillGradient = Gradient(colors: [
                            baseColor.opacity(isHovered ? 0.95 : 0.85),
                            baseColor.opacity(isHovered ? 0.80 : 0.65)
                        ])
                        context.fill(
                            path,
                            with: .linearGradient(
                                fillGradient,
                                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                            )
                        )
                        
                        // Border stroke
                        if isHovered || isSelected {
                            context.stroke(
                                path,
                                with: .color(.white),
                                lineWidth: 2.5
                            )
                        } else {
                            context.stroke(
                                path,
                                with: .color(Color.black.opacity(0.12)),
                                lineWidth: 1.0
                            )
                        }
                        
                        // Clip text & badge drawing to tile path so long names don't bleed into adjacent tiles
                        context.drawLayer { layerContext in
                            layerContext.clip(to: path)
                            
                            if rect.width > 55 && rect.height > 24 {
                                let title = item.node.name
                                let titleText = Text(title)
                                    .font(.system(size: rect.width > 90 ? 11 : 9, weight: .bold))
                                    .foregroundColor(.white)
                                
                                let textOrigin = CGPoint(x: rect.minX + 6, y: rect.minY + 6)
                                layerContext.draw(titleText, at: textOrigin, anchor: .topLeading)
                            }
                            
                            if rect.width > 65 && rect.height > 44 {
                                let sizeStr = item.node.formattedSize
                                let sizeText = Text(sizeStr)
                                    .font(.system(size: rect.width > 90 ? 10 : 8, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                let sizeOrigin = CGPoint(x: rect.minX + 6, y: rect.minY + 22)
                                layerContext.draw(sizeText, at: sizeOrigin, anchor: .topLeading)
                            }
                            
                            // Folder indicator icon for directories
                            if item.node.isDirectory && rect.width > 40 && rect.height > 40 {
                                let symbolName = item.node.isVirtual
                                    ? "square.stack.3d.up.fill"
                                    : (item.node.canDrillDown ? "folder.fill" : "folder")
                                let iconText = Text(Image(systemName: symbolName))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.75))
                                
                                let iconOrigin = CGPoint(x: rect.maxX - 14, y: rect.minY + 12)
                                layerContext.draw(iconText, at: iconOrigin, anchor: .center)
                            }
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        if let hit = items.first(where: { $0.rect.contains(location) }) {
                            if scanner.hoveredNode?.id != hit.node.id {
                                scanner.hoveredNode = hit.node
                            }
                        } else if scanner.hoveredNode != nil {
                            scanner.hoveredNode = nil
                        }
                    case .ended:
                        if scanner.hoveredNode != nil {
                            scanner.hoveredNode = nil
                        }
                    }
                }
                .onTapGesture { location in
                    if let hit = items.first(where: { $0.rect.contains(location) }) {
                        if hit.node.canDrillDown {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                scanner.drillDown(to: hit.node)
                            }
                        } else {
                            scanner.selectedNode = hit.node
                        }
                    }
                }
                
                // If empty or no files found
                if children.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No items found in this directory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
