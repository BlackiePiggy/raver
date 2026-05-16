import SwiftUI

public struct SunburstCanvasView: View {
    public let root: GenreNode
    @Binding public var focusedId: String?
    @Binding public var selectedNode: GenreNode?

    @State private var currentFocus: SunburstFocus = .root
    @State private var fromFocus: SunburstFocus = .root
    @State private var toFocus: SunburstFocus = .root
    @State private var animationStart: Date?
    @State private var lastCanvasSize: CGSize = .zero

    private let animationDuration: TimeInterval = 0.75
    private let labelFontSize: CGFloat = 12
    private let labelStrokeWidth: CGFloat = 5

    private struct LabelPlacement {
        let segment: SunburstSegment
        let lines: [String]
        let point: CGPoint
        let fontSize: CGFloat
        let rotation: Double
        let calloutStart: CGPoint?
        let calloutBend: CGPoint?
        let calloutEnd: CGPoint?
    }

    public init(
        root: GenreNode,
        focusedId: Binding<String?>,
        selectedNode: Binding<GenreNode?>
    ) {
        self.root = root
        self._focusedId = focusedId
        self._selectedNode = selectedNode
    }

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let focus = focusForFrame(at: timeline.date)
                    let segments = SunburstLayout.partitionSegments(
                        root: root,
                        canvasSize: size,
                        focus: focus
                    )
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)

                    drawVinylRecord(center: center, size: size, segments: segments, context: &context)

                    for segment in segments {
                        drawSegment(segment, center: center, context: &context)
                    }

                    drawVinylGrooves(center: center, segments: segments, context: &context)
                    drawCenterLabel(context: &context, center: center, size: size, segments: segments)
                    drawLabels(context: &context, center: center, size: size, segments: segments)
                }
            }
            .contentShape(Rectangle())
            .onAppear {
                lastCanvasSize = geometry.size
                currentFocus = SunburstLayout.focus(for: focusedId, root: root)
                fromFocus = currentFocus
                toFocus = currentFocus
            }
            .onChange(of: geometry.size) { _, newSize in
                lastCanvasSize = newSize
            }
            .onChange(of: focusedId) { _, newFocusId in
                guard SunburstLayout.focus(for: newFocusId, root: root) != toFocus else { return }
                let selected = newFocusId.flatMap { root.firstNode(withId: $0) }
                transition(to: newFocusId, selected: selected, updateBinding: false)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(value.location, size: geometry.size)
                    }
            )
        }
    }

    private func handleTap(_ point: CGPoint, size: CGSize) {
        let focus = animationStart == nil ? currentFocus : interpolatedFocus(now: Date())
        let segments = SunburstLayout.partitionSegments(root: root, canvasSize: size, focus: focus)

        if SunburstHitTesting.isCenterTap(at: point, in: size, segments: segments) {
            goToParent()
            return
        }

        guard let segment = SunburstHitTesting.hitSegment(at: point, in: size, segments: segments) else {
            transition(to: nil, selected: nil)
            return
        }

        let targetId = nextFocusId(forTapped: segment.node.id)
        let targetNode = targetId.flatMap { root.firstNode(withId: $0) }
        transition(to: targetId, selected: targetNode)
    }

    private func goToParent() {
        guard let currentFocusId = focusedId else {
            selectedNode = nil
            return
        }

        let path = root.pathToNode(withId: currentFocusId) ?? []
        if path.count > 2 {
            transition(to: path[path.count - 2].id, selected: path[path.count - 2])
        } else {
            transition(to: nil, selected: nil)
        }
    }

    private func transition(
        to newFocusId: String?,
        selected newSelectedNode: GenreNode?,
        updateBinding: Bool = true
    ) {
        fromFocus = animationStart == nil ? currentFocus : interpolatedFocus(now: Date())
        toFocus = SunburstLayout.focus(for: newFocusId, root: root)
        if updateBinding {
            focusedId = newFocusId
        }
        selectedNode = newSelectedNode
        animationStart = Date()
    }

    private func focusForFrame(at date: Date) -> SunburstFocus {
        guard let animationStart else {
            return currentFocus
        }

        let elapsed = date.timeIntervalSince(animationStart)
        let rawProgress = min(1, elapsed / animationDuration)
        let eased = easeInOutCubic(CGFloat(rawProgress))
        let focus = interpolate(from: fromFocus, to: toFocus, progress: eased)

        if rawProgress >= 1 {
            DispatchQueue.main.async {
                currentFocus = toFocus
                self.animationStart = nil
            }
        }

        return focus
    }

    private func interpolatedFocus(now: Date) -> SunburstFocus {
        guard let animationStart else { return currentFocus }
        let elapsed = now.timeIntervalSince(animationStart)
        let rawProgress = min(1, elapsed / animationDuration)
        let eased = easeInOutCubic(CGFloat(rawProgress))
        return interpolate(from: fromFocus, to: toFocus, progress: eased)
    }

    private func interpolate(from: SunburstFocus, to: SunburstFocus, progress: CGFloat) -> SunburstFocus {
        SunburstFocus(
            angleStart: lerp(from.angleStart, to.angleStart, progress),
            angleEnd: lerp(from.angleEnd, to.angleEnd, progress),
            depthStart: lerp(from.depthStart, to.depthStart, progress),
            depthEnd: lerp(from.depthEnd, to.depthEnd, progress)
        )
    }

    private func lerp(_ from: Double, _ to: Double, _ progress: CGFloat) -> Double {
        from + (to - from) * Double(progress)
    }

    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
        value < 0.5
            ? 4 * value * value * value
            : 1 - pow(-2 * value + 2, 3) / 2
    }

    private func opacity(for segment: SunburstSegment) -> Double {
        guard let selectedNode else { return 0.82 }
        return segment.node.id == selectedNode.id ? 0.96 : 0.66
    }

    private func strokeColor(for segment: SunburstSegment) -> Color {
        if segment.node.id == selectedNode?.id {
            return Color(red: 0.84, green: 0.98, blue: 1.0).opacity(0.88)
        }

        return Color(red: 0.82, green: 0.95, blue: 1.0).opacity(0.18)
    }

    private func strokeWidth(for segment: SunburstSegment) -> CGFloat {
        segment.node.id == selectedNode?.id ? 1.4 : 0.65
    }

    private func drawSegment(_ segment: SunburstSegment, center: CGPoint, context: inout GraphicsContext) {
        let path = segmentPath(segment, center: center)
        let innerPoint = CGPoint(
            x: center.x + cos(segment.midAngle) * segment.innerRadius,
            y: center.y + sin(segment.midAngle) * segment.innerRadius
        )
        let outerPoint = CGPoint(
            x: center.x + cos(segment.midAngle) * segment.outerRadius,
            y: center.y + sin(segment.midAngle) * segment.outerRadius
        )
        let selected = segment.node.id == selectedNode?.id

        context.drawLayer { layer in
            layer.addFilter(.shadow(
                color: segment.color.opacity(selected ? 0.42 : 0.16),
                radius: selected ? 12 : 4,
                x: 0,
                y: 0
            ))
            layer.fill(path, with: .color(segment.color.opacity(selected ? 0.38 : 0.16)))
        }

        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    .white.opacity(selected ? 0.24 : 0.14),
                    segment.color.opacity(opacity(for: segment)),
                    segment.color.opacity(selected ? 0.54 : 0.36),
                    .black.opacity(selected ? 0.32 : 0.46)
                ]),
                startPoint: innerPoint,
                endPoint: outerPoint
            )
        )

        context.stroke(
            path,
            with: .color(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(selected ? 0.28 : 0.12)),
            lineWidth: 0.38
        )
        context.stroke(
            path,
            with: .color(strokeColor(for: segment)),
            lineWidth: strokeWidth(for: segment)
        )
    }

    private func drawVinylRecord(
        center: CGPoint,
        size: CGSize,
        segments: [SunburstSegment],
        context: inout GraphicsContext
    ) {
        let outerRadius = maxSegmentOuterRadius(in: segments, fallbackSize: size)
        let discRect = CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        )
        let disc = Path(ellipseIn: discRect)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.46), radius: 22, x: 0, y: 16))
            layer.fill(
                disc,
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.22, green: 0.24, blue: 0.31).opacity(0.92),
                        Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.98),
                        Color(red: 0.015, green: 0.016, blue: 0.022)
                    ]),
                    center: center,
                    startRadius: outerRadius * 0.08,
                    endRadius: outerRadius
                )
            )
        }

        context.stroke(
            disc,
            with: .linearGradient(
                Gradient(colors: [
                    .white.opacity(0.30),
                    Color(red: 0.18, green: 0.88, blue: 1.0).opacity(0.16),
                    .black.opacity(0.28)
                ]),
                startPoint: CGPoint(x: discRect.minX, y: discRect.minY),
                endPoint: CGPoint(x: discRect.maxX, y: discRect.maxY)
            ),
            lineWidth: 1.1
        )

        var shine = Path()
        shine.addArc(
            center: CGPoint(x: center.x - outerRadius * 0.08, y: center.y - outerRadius * 0.10),
            radius: outerRadius * 0.78,
            startAngle: .degrees(208),
            endAngle: .degrees(312),
            clockwise: false
        )
        context.stroke(
            shine,
            with: .linearGradient(
                Gradient(colors: [
                    .clear,
                    .white.opacity(0.22),
                    Color(red: 0.85, green: 0.96, blue: 1.0).opacity(0.08),
                    .clear
                ]),
                startPoint: CGPoint(x: center.x - outerRadius, y: center.y - outerRadius),
                endPoint: CGPoint(x: center.x + outerRadius, y: center.y + outerRadius)
            ),
            lineWidth: max(16, outerRadius * 0.045)
        )
    }

    private func drawVinylGrooves(
        center: CGPoint,
        segments: [SunburstSegment],
        context: inout GraphicsContext
    ) {
        guard
            let innerRadius = segments.map(\.innerRadius).min(),
            let outerRadius = segments.map(\.outerRadius).max(),
            outerRadius > innerRadius
        else { return }

        let start = innerRadius + 7
        let step: CGFloat = 8
        var radius = start

        while radius < outerRadius - 4 {
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let groove = Path(ellipseIn: rect)
            let alternatingOpacity = Int(radius / step).isMultiple(of: 2) ? 0.13 : 0.07
            context.stroke(
                groove,
                with: .color(Color(red: 0.88, green: 0.96, blue: 1.0).opacity(alternatingOpacity)),
                lineWidth: 0.45
            )
            radius += step
        }
    }

    private func maxSegmentOuterRadius(in segments: [SunburstSegment], fallbackSize size: CGSize) -> CGFloat {
        segments.map(\.outerRadius).max() ?? min(size.width, size.height) * 0.44
    }

    private func segmentPath(_ segment: SunburstSegment, center: CGPoint) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: segment.outerRadius,
            startAngle: .radians(segment.startAngle),
            endAngle: .radians(segment.endAngle),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: segment.innerRadius,
            startAngle: .radians(segment.endAngle),
            endAngle: .radians(segment.startAngle),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func drawLabels(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        segments: [SunburstSegment]
    ) {
        for placement in labelPlacements(center: center, size: size, segments: segments) {
            if let start = placement.calloutStart, let bend = placement.calloutBend, let end = placement.calloutEnd {
                var line = Path()
                line.move(to: start)
                line.addLine(to: bend)
                line.addLine(to: end)
                context.stroke(line, with: .color(.white.opacity(0.52)), lineWidth: 0.8)
            }

            let lineHeight = placement.fontSize * 1.08
            let startY = -lineHeight * CGFloat(placement.lines.count - 1) / 2
            context.drawLayer { layer in
                layer.translateBy(x: placement.point.x, y: placement.point.y)
                layer.rotate(by: .radians(placement.rotation))
                for (index, line) in placement.lines.enumerated() {
                    let calloutOffset = placement.calloutEnd == nil ? CGFloat(0) : -placement.fontSize * 0.58
                    let y = startY + CGFloat(index) * lineHeight + calloutOffset
                    let shadowText = labelText(line, size: placement.fontSize, isShadow: true)
                    let text = labelText(line, size: placement.fontSize, isShadow: false)
                    layer.draw(shadowText, at: CGPoint(x: 0, y: y + 1), anchor: .center)
                    layer.draw(text, at: CGPoint(x: 0, y: y), anchor: .center)
                }
            }
        }
    }

    private func drawCenterLabel(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        segments: [SunburstSegment]
    ) {
        let node = focusedId.flatMap { root.firstNode(withId: $0) } ?? root
        let lines = centerLabelLines(for: node.name)
        let fontSize = centerLabelFontSize(for: size, lineCount: lines.count)
        let lineHeight = fontSize * 1.12
        let startY = center.y - lineHeight * CGFloat(lines.count - 1) / 2
        let centerRadius = centerLabelRadius(for: size, segments: segments)
        let labelRect = CGRect(
            x: center.x - centerRadius,
            y: center.y - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )
        let labelDisc = Path(ellipseIn: labelRect)
        let spindleRadius = max(6, centerRadius * 0.18)
        let spindleRect = CGRect(
            x: center.x - spindleRadius,
            y: center.y - spindleRadius,
            width: spindleRadius * 2,
            height: spindleRadius * 2
        )

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 5))
            layer.fill(
                labelDisc,
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.98, green: 0.20, blue: 0.43).opacity(0.92),
                        Color(red: 0.18, green: 0.74, blue: 0.92).opacity(0.70),
                        Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.94)
                    ]),
                    center: CGPoint(x: center.x - centerRadius * 0.2, y: center.y - centerRadius * 0.25),
                    startRadius: 0,
                    endRadius: centerRadius
                )
            )
        }

        context.stroke(labelDisc, with: .color(.white.opacity(0.34)), lineWidth: 0.85)
        context.stroke(
            Path(ellipseIn: labelRect.insetBy(dx: centerRadius * 0.18, dy: centerRadius * 0.18)),
            with: .color(.white.opacity(0.18)),
            lineWidth: 0.65
        )
        context.fill(Path(ellipseIn: spindleRect), with: .color(Color(red: 0.018, green: 0.02, blue: 0.028)))
        context.stroke(Path(ellipseIn: spindleRect), with: .color(.white.opacity(0.24)), lineWidth: 0.55)

        for (index, line) in lines.enumerated() {
            let y = startY + CGFloat(index) * lineHeight
            let title = Text(line)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color(red: 0.92, green: 0.98, blue: 1.0))
            let shadow = Text(line)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.88, blue: 1.0).opacity(0.52))

            context.draw(shadow, at: CGPoint(x: center.x, y: y + 1), anchor: .center)
            context.draw(title, at: CGPoint(x: center.x, y: y), anchor: .center)
        }
    }

    private func centerLabelRadius(for size: CGSize, segments: [SunburstSegment]) -> CGFloat {
        let projectedInnerRadius = segments.map(\.innerRadius).min()
        let fallback = min(size.width, size.height) * 0.075
        return max(34, (projectedInnerRadius ?? fallback) * 0.86)
    }

    private func labelPlacements(
        center: CGPoint,
        size: CGSize,
        segments: [SunburstSegment]
    ) -> [LabelPlacement] {
        var calloutPlacements: [LabelPlacement] = []
        let inlinePlacements = segments.compactMap { segment -> LabelPlacement? in
            guard labeledRelativeDepth(for: segment.node.id) != nil else { return nil }

            let lines = [segment.node.name]
            let radius = inlineLabelRadius(for: segment)
            let inlinePoint = CGPoint(
                x: center.x + cos(segment.midAngle) * radius,
                y: center.y + sin(segment.midAngle) * radius
            )

            if angularLabelFitsInside(segment) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: labelFontSize,
                    rotation: angularLabelRotation(for: segment),
                    calloutStart: nil,
                    calloutBend: nil,
                    calloutEnd: nil
                )
            }

            if radialLabelFitsInside(segment) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: labelFontSize,
                    rotation: radialLabelRotation(for: segment),
                    calloutStart: nil,
                    calloutBend: nil,
                    calloutEnd: nil
                )
            }

            let side: CGFloat = cos(segment.midAngle) >= 0 ? 1 : -1
            let radialMid = (segment.innerRadius + segment.outerRadius) / 2
            let start = CGPoint(
                x: center.x + cos(segment.midAngle) * radialMid,
                y: center.y + sin(segment.midAngle) * radialMid
            )
            let bendRadius = min(max(size.width, size.height) * 0.48, segment.outerRadius + 20)
            let bend = CGPoint(
                x: center.x + cos(segment.midAngle) * bendRadius,
                y: center.y + sin(segment.midAngle) * bendRadius
            )
            let lineLength = max(44, min(96, size.width * 0.08))
            let endX = min(max(bend.x + side * lineLength, 48), size.width - 48)
            let lineY = min(max(bend.y, 24), size.height - 24)
            let end = CGPoint(x: endX, y: lineY)

            calloutPlacements.append(LabelPlacement(
                segment: segment,
                lines: labelLines(for: segment.node.name),
                point: CGPoint(x: (bend.x + endX) / 2, y: lineY),
                fontSize: 11,
                rotation: 0,
                calloutStart: start,
                calloutBend: CGPoint(x: bend.x, y: lineY),
                calloutEnd: end
            ))
            return nil
        }

        return inlinePlacements + resolvedCalloutCollisions(calloutPlacements, canvasHeight: size.height)
    }

    private func angularLabelFitsInside(_ segment: SunburstSegment) -> Bool {
        let midRadius = (segment.innerRadius + segment.outerRadius) / 2
        let availableAngularSpace = CGFloat(segment.angleSpan) * midRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: labelFontSize) + labelStrokeWidth
        return textWidth < availableAngularSpace
    }

    private func radialLabelFitsInside(_ segment: SunburstSegment) -> Bool {
        let midRadius = inlineLabelRadius(for: segment)
        let availableAngularHeight = CGFloat(segment.angleSpan) * midRadius
        guard availableAngularHeight >= labelFontSize + labelStrokeWidth + 4 else { return false }

        let availableRadialSpace = segment.outerRadius - segment.innerRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: labelFontSize) + labelStrokeWidth
        return textWidth + 8 < availableRadialSpace
    }

    private func inlineLabelRadius(for segment: SunburstSegment) -> CGFloat {
        (segment.innerRadius + segment.outerRadius) / 2
    }

    private func labelLines(for name: String) -> [String] {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 2 else { return [name] }

        let totalCharacters = words.reduce(0) { $0 + $1.count }
        var firstLine: [String] = []
        var secondLine = words
        var firstCount = 0

        while secondLine.count > 1 && firstCount < totalCharacters / 2 {
            let word = secondLine.removeFirst()
            firstLine.append(word)
            firstCount += word.count
        }

        return [firstLine.joined(separator: " "), secondLine.joined(separator: " ")]
    }

    private func estimatedLabelWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        CGFloat(text.count) * fontSize * 0.56
    }

    private func resolvedCalloutCollisions(
        _ placements: [LabelPlacement],
        canvasHeight: CGFloat
    ) -> [LabelPlacement] {
        let left = resolveCalloutSide(
            placements.filter { $0.point.x < lastCanvasSize.width / 2 },
            canvasHeight: canvasHeight
        )
        let right = resolveCalloutSide(
            placements.filter { $0.point.x >= lastCanvasSize.width / 2 },
            canvasHeight: canvasHeight
        )
        return left + right
    }

    private func resolveCalloutSide(_ placements: [LabelPlacement], canvasHeight: CGFloat) -> [LabelPlacement] {
        var nextY: CGFloat = 22
        return placements
            .sorted { $0.point.y < $1.point.y }
            .map { placement in
                let minGap = placement.fontSize * CGFloat(placement.lines.count) * 1.12 + 6
                let y = min(max(placement.point.y, nextY), canvasHeight - 22)
                nextY = y + minGap
                return LabelPlacement(
                    segment: placement.segment,
                    lines: placement.lines,
                    point: CGPoint(x: placement.point.x, y: y),
                    fontSize: placement.fontSize,
                    rotation: placement.rotation,
                    calloutStart: placement.calloutStart,
                    calloutBend: placement.calloutBend
                        .map { CGPoint(x: $0.x, y: y) },
                    calloutEnd: placement.calloutEnd
                        .map { CGPoint(x: $0.x, y: y) }
                )
            }
    }

    private func centerLabelFontSize(for size: CGSize, lineCount: Int) -> CGFloat {
        let baseSize = min(18, max(12, min(size.width, size.height) * 0.026))
        return lineCount > 1 ? baseSize * 0.92 : baseSize
    }

    private func centerLabelLines(for name: String) -> [String] {
        let words = name.split(separator: " ").map(String.init)
        guard words.count == 2 else { return [name] }
        return words
    }

    private func labelText(_ value: String, size: CGFloat, isShadow: Bool) -> Text {
        Text(value)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(isShadow ? .black.opacity(0.72) : Color(red: 0.95, green: 0.98, blue: 1.0))
    }

    private func angularLabelRotation(for segment: SunburstSegment) -> Double {
        let middleAngle = segment.midAngle
        let invertDirection = middleAngle > 0 && middleAngle < Double.pi
        let tangentAngle = invertDirection ? middleAngle - Double.pi / 2 : middleAngle + Double.pi / 2
        return normalizedReadableAngle(tangentAngle)
    }

    private func radialLabelRotation(for segment: SunburstSegment) -> Double {
        normalizedReadableAngle(segment.midAngle)
    }

    private func normalizedReadableAngle(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: Double.pi * 2)
        if value > Double.pi { value -= Double.pi * 2 }
        if value < -Double.pi { value += Double.pi * 2 }
        if value > Double.pi / 2 { value -= Double.pi }
        if value < -Double.pi / 2 { value += Double.pi }
        return value
    }

    private func labeledRelativeDepth(for nodeId: String) -> Int? {
        let focusPath = focusPath()
        guard let nodePath = root.pathToNode(withId: nodeId), nodePath.count > focusPath.count else {
            return nil
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return nil
        }

        let relativeDepth = nodePath.count - focusPath.count
        return relativeDepth == 1 ? relativeDepth : nil
    }

    private func focusPath() -> [GenreNode] {
        guard let focusedId, let path = root.pathToNode(withId: focusedId) else {
            return [root]
        }

        return path
    }

    private func nextFocusId(forTapped nodeId: String) -> String? {
        let focusPath = focusPath()
        guard let nodePath = root.pathToNode(withId: nodeId), nodePath.count > focusPath.count else {
            return focusedId
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return focusedId
        }

        return nodePath[focusPath.count].id
    }
}
