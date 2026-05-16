import CoreGraphics
import SwiftUI

public struct SunburstFocus: Equatable, Sendable {
    public let angleStart: Double
    public let angleEnd: Double
    public let depthStart: Double
    public let depthEnd: Double

    public static let root = SunburstFocus(
        angleStart: 0,
        angleEnd: 1,
        depthStart: 0,
        depthEnd: 1
    )
}

public enum SunburstLayout {
    public static func partitionSegments(
        root: GenreNode,
        canvasSize: CGSize,
        focus: SunburstFocus
    ) -> [SunburstSegment] {
        let maxDepth = max(1, maxDepth(from: root))
        let chartRadius = max(10, min(canvasSize.width, canvasSize.height) * 0.48)
        let topLevelPalette = paletteMap(root: root)
        let baseSegments = partition(root: root, maxDepth: maxDepth, topLevelPalette: topLevelPalette)

        return baseSegments.compactMap { segment in
            project(segment, radius: chartRadius, focus: focus)
        }
    }

    public static func focus(for nodeId: String?, root: GenreNode) -> SunburstFocus {
        guard
            let nodeId,
            let segment = partition(root: root, maxDepth: max(1, maxDepth(from: root)), topLevelPalette: paletteMap(root: root))
                .first(where: { $0.id == nodeId })
        else {
            return .root
        }

        return SunburstFocus(
            angleStart: segment.x0,
            angleEnd: segment.x1,
            depthStart: segment.y0,
            depthEnd: 1
        )
    }

    private static func partition(
        root: GenreNode,
        maxDepth: Int,
        topLevelPalette: [String: Color]
    ) -> [SunburstSegment] {
        var output: [SunburstSegment] = []
        let totalWeight = Double(root.children.reduce(0) { $0 + $1.leafCount })
        var cursor = 0.0

        for child in root.children {
            let span = totalWeight == 0 ? 0 : Double(child.leafCount) / totalWeight
            appendPartition(
                node: child,
                parentId: root.id,
                root: root,
                depth: 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                output: &output
            )
            cursor += span
        }

        return output
    }

    private static func appendPartition(
        node: GenreNode,
        parentId: String?,
        root: GenreNode,
        depth: Int,
        maxDepth: Int,
        x0: Double,
        x1: Double,
        topLevelPalette: [String: Color],
        output: inout [SunburstSegment]
    ) {
        let y0 = Double(depth - 1) / Double(maxDepth)
        let y1 = Double(depth) / Double(maxDepth)
        let topLevelId = root.pathToNode(withId: node.id)?.dropFirst().first?.id ?? node.id

        output.append(
            SunburstSegment(
                id: node.id,
                node: node,
                parentId: parentId,
                depth: depth,
                x0: x0,
                x1: x1,
                y0: y0,
                y1: y1,
                startAngle: 0,
                endAngle: 0,
                innerRadius: 0,
                outerRadius: 0,
                color: topLevelPalette[topLevelId] ?? .gray
            )
        )

        guard !node.children.isEmpty else { return }

        let totalWeight = Double(node.children.reduce(0) { $0 + $1.leafCount })
        var cursor = x0

        for child in node.children {
            let span = totalWeight == 0 ? 0 : (Double(child.leafCount) / totalWeight) * (x1 - x0)
            appendPartition(
                node: child,
                parentId: node.id,
                root: root,
                depth: depth + 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                output: &output
            )
            cursor += span
        }
    }

    private static func project(
        _ segment: SunburstSegment,
        radius: CGFloat,
        focus: SunburstFocus
    ) -> SunburstSegment? {
        let angleSpan = focus.angleEnd - focus.angleStart
        let depthSpan = focus.depthEnd - focus.depthStart
        guard angleSpan > 0, depthSpan > 0 else { return nil }

        let x0 = (segment.x0 - focus.angleStart) / angleSpan
        let x1 = (segment.x1 - focus.angleStart) / angleSpan
        let y0 = (segment.y0 - focus.depthStart) / depthSpan
        let y1 = (segment.y1 - focus.depthStart) / depthSpan

        if x1 <= 0 || x0 >= 1 || y1 <= 0 || y0 >= 1 {
            return nil
        }

        let clampedX0 = max(0, min(1, x0))
        let clampedX1 = max(0, min(1, x1))
        let clampedY0 = max(0, min(1, y0))
        let clampedY1 = max(0, min(1, y1))

        guard clampedX1 > clampedX0, clampedY1 > clampedY0 else { return nil }

        let startAngle = clampedX0 * Double.pi * 2 - Double.pi / 2
        let endAngle = clampedX1 * Double.pi * 2 - Double.pi / 2
        let centerRadius = radius * 0.16
        let drawableRadius = radius - centerRadius
        let innerRadius = centerRadius + CGFloat(sqrt(clampedY0)) * drawableRadius
        let outerRadius = centerRadius + CGFloat(sqrt(clampedY1)) * drawableRadius

        return SunburstSegment(
            id: segment.id,
            node: segment.node,
            parentId: segment.parentId,
            depth: segment.depth,
            x0: segment.x0,
            x1: segment.x1,
            y0: segment.y0,
            y1: segment.y1,
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            color: segment.color
        )
    }

    private static func maxDepth(from node: GenreNode) -> Int {
        if node.children.isEmpty { return 0 }
        return 1 + (node.children.map(maxDepth).max() ?? 0)
    }

    private static func paletteMap(root: GenreNode) -> [String: Color] {
        let colors: [Color] = [
            Color(red: 0.18, green: 0.72, blue: 0.96),
            Color(red: 0.94, green: 0.30, blue: 0.74),
            Color(red: 0.46, green: 0.86, blue: 0.40),
            Color(red: 0.96, green: 0.54, blue: 0.18),
            Color(red: 0.48, green: 0.42, blue: 0.92),
            Color(red: 0.08, green: 0.82, blue: 0.70),
            Color(red: 0.90, green: 0.25, blue: 0.35),
            Color(red: 0.72, green: 0.62, blue: 0.96),
            Color(red: 0.86, green: 0.78, blue: 0.28),
            Color(red: 0.30, green: 0.48, blue: 0.92)
        ]

        return Dictionary(uniqueKeysWithValues: root.children.enumerated().map { index, node in
            (node.id, colors[index % colors.count])
        })
    }
}
