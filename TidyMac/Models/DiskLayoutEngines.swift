import SwiftUI
import Foundation

// MARK: - Squarified Treemap Layout Engine
public enum TreemapLayoutEngine {
    
    public static func layout(
        nodes: [DiskNode],
        in rect: CGRect,
        padding: CGFloat = 2.0
    ) -> [TreemapItem] {
        guard !nodes.isEmpty, rect.width > 10, rect.height > 10 else { return [] }
        
        let validNodes = nodes.filter { $0.size > 0 }
        guard !validNodes.isEmpty else { return [] }
        
        let totalSize = validNodes.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        let totalArea = Double(rect.width * rect.height)
        let scale = totalArea / Double(totalSize)
        
        // Items sorted descending by size
        let sorted = validNodes.sorted { $0.size > $1.size }
        let areas = sorted.map { Double($0.size) * scale }
        
        var result: [TreemapItem] = []
        var remainingRect = rect
        var currentIndex = 0
        
        while currentIndex < sorted.count {
            let shorterSide = Double(min(remainingRect.width, remainingRect.height))
            guard shorterSide > 1 else { break }
            
            var row: [Int] = [currentIndex]
            var rowAreaSum = areas[currentIndex]
            var currentWorst = worstAspectRatio(rowAreas: [areas[currentIndex]], sideLength: shorterSide)
            
            var nextIndex = currentIndex + 1
            while nextIndex < sorted.count {
                let candidateArea = areas[nextIndex]
                let testRowAreas = row.map { areas[$0] } + [candidateArea]
                let candidateWorst = worstAspectRatio(rowAreas: testRowAreas, sideLength: shorterSide)
                
                if candidateWorst <= currentWorst {
                    row.append(nextIndex)
                    rowAreaSum += candidateArea
                    currentWorst = candidateWorst
                    nextIndex += 1
                } else {
                    break
                }
            }
            
            // Layout current row
            let laidOut = layoutRow(
                indices: row,
                areas: areas,
                nodes: sorted,
                remainingRect: &remainingRect,
                padding: padding
            )
            result.append(contentsOf: laidOut)
            
            currentIndex = nextIndex
        }
        
        return result
    }
    
    private static func worstAspectRatio(rowAreas: [Double], sideLength: Double) -> Double {
        guard !rowAreas.isEmpty, sideLength > 0 else { return .infinity }
        let sum = rowAreas.reduce(0, +)
        guard sum > 0 else { return .infinity }
        
        var worst: Double = 0
        let sideSq = sideLength * sideLength
        let sumSq = sum * sum
        
        for a in rowAreas {
            guard a > 0 else { continue }
            let r1 = (sideSq * a) / sumSq
            let r2 = sumSq / (sideSq * a)
            let aspect = max(r1, r2)
            if aspect > worst {
                worst = aspect
            }
        }
        return worst
    }
    
    private static func layoutRow(
        indices: [Int],
        areas: [Double],
        nodes: [DiskNode],
        remainingRect: inout CGRect,
        padding: CGFloat
    ) -> [TreemapItem] {
        guard !indices.isEmpty else { return [] }
        
        let rowArea = indices.map { areas[$0] }.reduce(0, +)
        let isHorizontal = remainingRect.width >= remainingRect.height
        let shorterSide = Double(isHorizontal ? remainingRect.height : remainingRect.width)
        guard shorterSide > 0 else { return [] }
        
        let rowThickness = CGFloat(rowArea / shorterSide)
        var items: [TreemapItem] = []
        
        var currentOffset: CGFloat = 0
        for (_, index) in indices.enumerated() {
            let node = nodes[index]
            let a = areas[index]
            let itemLength = rowThickness > 0 ? CGFloat(a / Double(rowThickness)) : 0
            
            let itemRect: CGRect
            if isHorizontal {
                itemRect = CGRect(
                    x: remainingRect.origin.x,
                    y: remainingRect.origin.y + currentOffset,
                    width: rowThickness,
                    height: itemLength
                )
            } else {
                itemRect = CGRect(
                    x: remainingRect.origin.x + currentOffset,
                    y: remainingRect.origin.y,
                    width: itemLength,
                    height: rowThickness
                )
            }
            
            currentOffset += itemLength
            
            let paddedRect = CGRect(
                x: itemRect.origin.x + padding,
                y: itemRect.origin.y + padding,
                width: max(0, itemRect.width - padding * 2),
                height: max(0, itemRect.height - padding * 2)
            )
            
            let color = node.color != .blue ? node.color : DiskColorPalette.color(for: index)
            items.append(TreemapItem(id: node.id, node: node, rect: paddedRect, color: color))
        }
        
        // Update remaining rect
        if isHorizontal {
            remainingRect = CGRect(
                x: remainingRect.origin.x + rowThickness,
                y: remainingRect.origin.y,
                width: max(0, remainingRect.width - rowThickness),
                height: remainingRect.height
            )
        } else {
            remainingRect = CGRect(
                x: remainingRect.origin.x,
                y: remainingRect.origin.y + rowThickness,
                width: remainingRect.width,
                height: max(0, remainingRect.height - rowThickness)
            )
        }
        
        return items
    }
}

// MARK: - Radial Sunburst Layout Engine
public enum SunburstLayoutEngine {
    
    public static func layout(
        rootNode: DiskNode,
        center: CGPoint,
        maxRadius: CGFloat,
        centerRadius: CGFloat = 65,
        ringThickness: CGFloat = 48,
        gap: CGFloat = 3
    ) -> (segments: [SunburstSegment], centerRect: CGRect) {
        let centerRect = CGRect(
            x: center.x - centerRadius,
            y: center.y - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )
        
        let children = rootNode.children.filter { $0.size > 0 }
        guard !children.isEmpty else { return ([], centerRect) }
        
        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > 0 else { return ([], centerRect) }
        
        var segments: [SunburstSegment] = []
        var currentAngle: Double = -Double.pi / 2.0 // Start at 12 o'clock
        
        let ring1Inner = centerRadius + gap
        let ring1Outer = min(maxRadius, ring1Inner + ringThickness)
        
        let ring2Inner = ring1Outer + gap
        let ring2Outer = min(maxRadius, ring2Inner + ringThickness * 0.9)
        
        for (idx, child) in children.enumerated() {
            let fraction = Double(child.size) / Double(totalSize)
            let span = fraction * 2.0 * Double.pi
            let childStart = currentAngle
            let childEnd = currentAngle + span
            
            let childColor = child.color != .blue ? child.color : DiskColorPalette.color(for: idx)
            
            // Ring 1 Segment
            segments.append(
                SunburstSegment(
                    id: child.id,
                    node: child,
                    startAngle: childStart,
                    endAngle: childEnd,
                    innerRadius: ring1Inner,
                    outerRadius: ring1Outer,
                    ringIndex: 0,
                    color: childColor
                )
            )
            
            // Ring 2 Subsegments (grandchildren)
            let subChildren = child.children.filter { $0.size > 0 }
            if !subChildren.isEmpty && ring2Outer > ring2Inner {
                let subTotal = subChildren.reduce(Int64(0)) { $0 + $1.size }
                if subTotal > 0 {
                    var subCurrentAngle = childStart
                    for (subIdx, sub) in subChildren.enumerated() {
                        let subFraction = Double(sub.size) / Double(subTotal)
                        let subSpan = subFraction * span
                        let subStart = subCurrentAngle
                        let subEnd = subCurrentAngle + subSpan
                        
                        let subColor = childColor.opacity(0.75 + Double(subIdx % 3) * 0.1)
                        
                        segments.append(
                            SunburstSegment(
                                id: sub.id,
                                node: sub,
                                startAngle: subStart,
                                endAngle: subEnd,
                                innerRadius: ring2Inner,
                                outerRadius: ring2Outer,
                                ringIndex: 1,
                                color: subColor
                            )
                        )
                        subCurrentAngle = subEnd
                    }
                }
            }
            
            currentAngle = childEnd
        }
        
        return (segments, centerRect)
    }
}
