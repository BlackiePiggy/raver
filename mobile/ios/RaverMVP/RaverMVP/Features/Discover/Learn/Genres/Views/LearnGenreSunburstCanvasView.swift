import SwiftUI

struct GenreSunburstStaticRecordBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = max(10, min(size.width, size.height) * 0.485)
            let centerRadius = outerRadius * 0.16
            let discRect = CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
            let disc = Path(ellipseIn: discRect)

            context.fill(disc, with: .color(discFill))
            context.stroke(disc, with: .color(discStroke), lineWidth: 1)

            var radius = centerRadius + 7
            while radius < outerRadius - 4 {
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let groove = Path(ellipseIn: rect)
                let alternatingOpacity = Int(radius / 8).isMultiple(of: 2) ? 0.11 : 0.055
                context.stroke(
                    groove,
                    with: .color(grooveColor.opacity(alternatingOpacity)),
                    lineWidth: 0.4
                )
                radius += 8
            }
        }
    }

    private var discFill: Color {
        colorScheme == .dark
            ? Color(red: 0.018, green: 0.02, blue: 0.03)
            : Color(red: 0.77, green: 0.79, blue: 0.82)
    }

    private var discStroke: Color {
        colorScheme == .dark ? .white.opacity(0.16) : Color(red: 0.24, green: 0.26, blue: 0.30).opacity(0.22)
    }

    private var grooveColor: Color {
        colorScheme == .dark
            ? Color(red: 0.88, green: 0.96, blue: 1.0)
            : Color(red: 0.16, green: 0.18, blue: 0.22)
    }
}

struct GenreSunburstCanvasView: View {
    let root: GenreSunburstNode
    @Binding var focusedId: String?
    @Binding var selectedNode: GenreSunburstNode?

    @State private var layoutCache: GenreSunburstLayoutCache
    @State private var animatedFocus: GenreSunburstFocus = .root
    @State private var isAnimating = false
    @State private var lastCanvasSize: CGSize = .zero
    @State private var animationCompletionTask: Task<Void, Never>?

    private let animationDuration: TimeInterval = 0.4

    init(
        root: GenreSunburstNode,
        focusedId: Binding<String?>,
        selectedNode: Binding<GenreSunburstNode?>
    ) {
        self.root = root
        _focusedId = focusedId
        _selectedNode = selectedNode
        _layoutCache = State(initialValue: GenreSunburstLayoutCache(root: root))
    }

    var body: some View {
        let cache = layoutCache

        GeometryReader { geometry in
            ZStack {
                GenreSunburstStaticRecordBackground()
                    .drawingGroup()

                GenreSunburstRenderableCanvas(
                    layoutCache: cache,
                    focus: animatedFocus,
                    focusedId: focusedId,
                    selectedNodeId: selectedNode?.id,
                    isAnimating: isAnimating,
                    lastCanvasSize: lastCanvasSize
                )
            }
            .contentShape(Rectangle())
            .onAppear {
                lastCanvasSize = geometry.size
                animatedFocus = cache.focus(for: focusedId)
            }
            .onDisappear {
                animationCompletionTask?.cancel()
            }
            .onChange(of: root) { _, newRoot in
                let updatedCache = GenreSunburstLayoutCache(root: newRoot)
                layoutCache = updatedCache
                animatedFocus = updatedCache.focus(for: focusedId)
            }
            .onChange(of: geometry.size) { _, newSize in
                lastCanvasSize = newSize
            }
            .onChange(of: focusedId) { _, newFocusId in
                let nextFocus = cache.focus(for: newFocusId)
                guard nextFocus != animatedFocus else { return }
                let selected = cache.node(withId: newFocusId)
                transition(to: newFocusId, focus: nextFocus, selected: selected, updateBinding: false)
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(value.location, size: geometry.size, cache: cache)
                    }
            )
        }
    }

    private func handleTap(_ point: CGPoint, size: CGSize, cache: GenreSunburstLayoutCache) {
        let segments = cache.segments(in: size, focus: animatedFocus)

        if GenreSunburstHitTesting.isCenterTap(at: point, in: size, segments: segments) {
            goToParent(cache: cache)
            return
        }

        guard let segment = GenreSunburstHitTesting.hitSegment(at: point, in: size, segments: segments) else {
            return
        }

        let targetId = nextFocusId(forTapped: segment.node.id, cache: cache)
        transition(to: targetId, focus: cache.focus(for: targetId), selected: cache.node(withId: targetId))
    }

    private func goToParent(cache: GenreSunburstLayoutCache) {
        guard let currentFocusId = focusedId else {
            selectedNode = nil
            return
        }

        let path = cache.path(to: currentFocusId) ?? []
        if path.count > 2 {
            let parent = path[path.count - 2]
            transition(to: parent.id, focus: cache.focus(for: parent.id), selected: parent)
        } else {
            transition(to: nil, focus: .root, selected: nil)
        }
    }

    private func transition(
        to newFocusId: String?,
        focus newFocus: GenreSunburstFocus,
        selected newSelectedNode: GenreSunburstNode?,
        updateBinding: Bool = true
    ) {
        animationCompletionTask?.cancel()
        isAnimating = true

        if updateBinding {
            focusedId = newFocusId
        }
        selectedNode = newSelectedNode

        withAnimation(.easeInOut(duration: animationDuration)) {
            animatedFocus = newFocus
        }

        animationCompletionTask = Task {
            try? await Task.sleep(nanoseconds: UInt64((animationDuration + 0.04) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isAnimating = false
            }
        }
    }

    private func nextFocusId(forTapped nodeId: String, cache: GenreSunburstLayoutCache) -> String? {
        let focusPath = focusedId.flatMap { cache.path(to: $0) } ?? [root]
        guard let nodePath = cache.path(to: nodeId), nodePath.count > focusPath.count else {
            return focusedId
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return focusedId
        }

        return nodePath[focusPath.count].id
    }
}

private struct GenreSunburstRenderableCanvas: View, Animatable {
    @Environment(\.colorScheme) private var colorScheme
    let layoutCache: GenreSunburstLayoutCache
    var focus: GenreSunburstFocus
    let focusedId: String?
    let selectedNodeId: String?
    let isAnimating: Bool
    let lastCanvasSize: CGSize

    var animatableData: GenreSunburstFocus {
        get { focus }
        set { focus = newValue }
    }

    private let labelStrokeWidth: CGFloat = 5

    private struct LabelPlacement {
        let segment: GenreSunburstSegment
        let lines: [String]
        let point: CGPoint
        let fontSize: CGFloat
        let rotation: Double
        let calloutStart: CGPoint?
        let calloutBend: CGPoint?
        let calloutEnd: CGPoint?
    }

    var body: some View {
        Canvas { context, size in
            renderSunburst(in: size, context: &context)
        }
    }

    private func renderSunburst(
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let segments = layoutCache.segments(in: size, focus: focus)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for segment in segments {
            drawSegment(segment, center: center, context: &context)
        }

        drawCenterLabel(context: &context, center: center, size: size, segments: segments)
        if !isAnimating {
            drawLabels(context: &context, center: center, size: size, segments: segments)
        }
    }

    private func labelFontSize(for size: CGSize) -> CGFloat {
        min(13, max(9.5, min(size.width, size.height) * 0.024))
    }

    private func calloutFontSize(for size: CGSize) -> CGFloat {
        min(11.5, max(9, min(size.width, size.height) * 0.0205))
    }

    private func opacity(for segment: GenreSunburstSegment) -> Double {
        guard let selectedNodeId else { return 0.82 }
        return segment.node.id == selectedNodeId ? 0.96 : 0.66
    }

    private func strokeColor(for segment: GenreSunburstSegment) -> Color {
        if segment.node.id == selectedNodeId {
            return colorScheme == .dark
                ? Color(red: 0.84, green: 0.98, blue: 1.0).opacity(0.88)
                : Color.black.opacity(0.46)
        }

        return colorScheme == .dark
            ? Color(red: 0.82, green: 0.95, blue: 1.0).opacity(0.18)
            : Color.black.opacity(0.16)
    }

    private func strokeWidth(for segment: GenreSunburstSegment) -> CGFloat {
        segment.node.id == selectedNodeId ? 1.4 : 0.65
    }

    private func drawSegment(_ segment: GenreSunburstSegment, center: CGPoint, context: inout GraphicsContext) {
        let path = segmentPath(segment, center: center)
        let selected = segment.node.id == selectedNodeId

        context.fill(path, with: .color(segment.color.opacity(selected ? 0.92 : opacity(for: segment))))
        context.stroke(
            path,
            with: .color(strokeColor(for: segment)),
            lineWidth: strokeWidth(for: segment)
        )
    }

    private func segmentPath(_ segment: GenreSunburstSegment, center: CGPoint) -> Path {
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
        segments: [GenreSunburstSegment]
    ) {
        for placement in labelPlacements(center: center, size: size, segments: segments) {
            if let start = placement.calloutStart, let bend = placement.calloutBend, let end = placement.calloutEnd {
                var line = Path()
                line.move(to: start)
                line.addLine(to: bend)
                line.addLine(to: end)
                context.stroke(line, with: .color(labelGuideColor), lineWidth: 0.8)
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
        segments: [GenreSunburstSegment]
    ) {
        let lines = centerLabelLines()
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

        context.fill(labelDisc, with: .color(Color(red: 0.08, green: 0.11, blue: 0.18).opacity(0.96)))

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
            context.draw(title, at: CGPoint(x: center.x, y: y), anchor: .center)
        }
    }

    private func centerLabelRadius(for size: CGSize, segments: [GenreSunburstSegment]) -> CGFloat {
        let projectedInnerRadius = segments.map(\.innerRadius).min()
        let fallback = min(size.width, size.height) * 0.075
        return max(34, (projectedInnerRadius ?? fallback) * 0.86)
    }

    private func labelPlacements(
        center: CGPoint,
        size: CGSize,
        segments: [GenreSunburstSegment]
    ) -> [LabelPlacement] {
        let inlineLabelFontSize = labelFontSize(for: size)
        let calloutLabelFontSize = calloutFontSize(for: size)
        var calloutPlacements: [LabelPlacement] = []
        let inlinePlacements = segments.compactMap { segment -> LabelPlacement? in
            guard labeledRelativeDepth(for: segment.node.id) != nil else { return nil }

            let lines = [segment.node.name]
            let radius = inlineLabelRadius(for: segment)
            let inlinePoint = CGPoint(
                x: center.x + cos(segment.midAngle) * radius,
                y: center.y + sin(segment.midAngle) * radius
            )

            if angularLabelFitsInside(segment, fontSize: inlineLabelFontSize) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: inlineLabelFontSize,
                    rotation: angularLabelRotation(for: segment),
                    calloutStart: nil,
                    calloutBend: nil,
                    calloutEnd: nil
                )
            }

            if radialLabelFitsInside(segment, fontSize: inlineLabelFontSize) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: inlineLabelFontSize,
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
                fontSize: calloutLabelFontSize,
                rotation: 0,
                calloutStart: start,
                calloutBend: CGPoint(x: bend.x, y: lineY),
                calloutEnd: end
            ))
            return nil
        }

        return inlinePlacements + resolvedCalloutCollisions(calloutPlacements, canvasHeight: size.height)
    }

    private func angularLabelFitsInside(_ segment: GenreSunburstSegment, fontSize: CGFloat) -> Bool {
        let midRadius = (segment.innerRadius + segment.outerRadius) / 2
        let availableAngularSpace = CGFloat(segment.angleSpan) * midRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: fontSize) + labelStrokeWidth
        return textWidth < availableAngularSpace
    }

    private func radialLabelFitsInside(_ segment: GenreSunburstSegment, fontSize: CGFloat) -> Bool {
        let midRadius = inlineLabelRadius(for: segment)
        let availableAngularHeight = CGFloat(segment.angleSpan) * midRadius
        guard availableAngularHeight >= fontSize + labelStrokeWidth + 4 else { return false }

        let availableRadialSpace = segment.outerRadius - segment.innerRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: fontSize) + labelStrokeWidth
        return textWidth + 8 < availableRadialSpace
    }

    private func inlineLabelRadius(for segment: GenreSunburstSegment) -> CGFloat {
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
                    calloutBend: placement.calloutBend.map { CGPoint(x: $0.x, y: y) },
                    calloutEnd: placement.calloutEnd.map { CGPoint(x: $0.x, y: y) }
                )
            }
    }

    private func centerLabelFontSize(for size: CGSize, lineCount: Int) -> CGFloat {
        let baseSize = min(18, max(12, min(size.width, size.height) * 0.026))
        return lineCount > 1 ? baseSize * 0.92 : baseSize
    }

    private func centerLabelLines() -> [String] {
        guard let node = layoutCache.node(withId: focusedId) else {
            return ["EDM"]
        }

        let name = node.name
        let words = name.split(separator: " ").map(String.init)
        guard words.count == 2 else { return [name] }
        return words
    }

    private func labelText(_ value: String, size: CGFloat, isShadow: Bool) -> Text {
        Text(value)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(labelForeground(isShadow: isShadow))
    }

    private var labelGuideColor: Color {
        colorScheme == .dark ? .white.opacity(0.52) : .black.opacity(0.42)
    }

    private func labelForeground(isShadow: Bool) -> Color {
        if colorScheme == .dark {
            return isShadow ? .black.opacity(0.72) : Color(red: 0.95, green: 0.98, blue: 1.0)
        }

        return isShadow ? .white.opacity(0.35) : .black.opacity(0.82)
    }

    private func angularLabelRotation(for segment: GenreSunburstSegment) -> Double {
        let middleAngle = segment.midAngle
        let invertDirection = middleAngle > 0 && middleAngle < Double.pi
        let tangentAngle = invertDirection ? middleAngle - Double.pi / 2 : middleAngle + Double.pi / 2
        return normalizedReadableAngle(tangentAngle)
    }

    private func radialLabelRotation(for segment: GenreSunburstSegment) -> Double {
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
        let focusPath = focusedId.flatMap { layoutCache.path(to: $0) } ?? layoutCache.path(to: layoutCache.rootId) ?? []
        guard let nodePath = layoutCache.path(to: nodeId), nodePath.count > focusPath.count else {
            return nil
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return nil
        }

        let relativeDepth = nodePath.count - focusPath.count
        return relativeDepth == 1 ? relativeDepth : nil
    }
}
