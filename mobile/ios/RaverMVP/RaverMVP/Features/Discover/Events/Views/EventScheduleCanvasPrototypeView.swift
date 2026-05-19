import SwiftUI

#if DEBUG
struct EventScheduleCanvasPrototypeView: View {
    @State private var selectedDayIndex = 1
    @State private var committedScroll = CGPoint.zero
    @State private var selectedSlotID: String?

    @GestureState private var dragTranslation = CGSize.zero

    private let days = EventScheduleCanvasPrototypeData.days

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                let viewport = proxy.size
                let layout = EventScheduleCanvasLayout(
                    day: days[selectedDayIndex],
                    viewportSize: viewport
                )
                let scroll = layout.clampedScroll(
                    CGPoint(
                        x: committedScroll.x - dragTranslation.width,
                        y: committedScroll.y - dragTranslation.height
                    )
                )

                ZStack(alignment: .topLeading) {
                    Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                        drawSchedule(context: &context, size: size, layout: layout, scroll: scroll)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragTranslation) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                let proposed = CGPoint(
                                    x: committedScroll.x - value.translation.width,
                                    y: committedScroll.y - value.translation.height
                                )
                                committedScroll = layout.clampedScroll(proposed)

                                if abs(value.translation.width) < 7,
                                   abs(value.translation.height) < 7 {
                                    selectedSlotID = layout.slotID(at: value.location, scroll: scroll)
                                }
                            }
                    )

                    if let selected = layout.slots.first(where: { $0.id == selectedSlotID }) {
                        selectedSlotOverlay(selected)
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
                .frame(width: viewport.width, height: viewport.height)
                .clipped()
                .onChange(of: selectedDayIndex) { _ in
                    committedScroll = .zero
                    selectedSlotID = nil
                }
            }
        }
        .background(Color(red: 0.04, green: 0.045, blue: 0.065))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                selectedDayIndex = (selectedDayIndex - 1 + days.count) % days.count
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(days[selectedDayIndex].title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(days[selectedDayIndex].slots.count) mock slots · SwiftUI Canvas")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer(minLength: 0)

            Button {
                selectedDayIndex = (selectedDayIndex + 1) % days.count
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.10), in: Circle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func selectedSlotOverlay(_ slot: EventScheduleCanvasSlotLayout) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(slot.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(slot.stageName) · \(slot.timeRangeText)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func drawSchedule(
        context: inout GraphicsContext,
        size: CGSize,
        layout: EventScheduleCanvasLayout,
        scroll: CGPoint
    ) {
        drawBackground(context: &context, size: size)

        var world = context
        world.translateBy(x: -scroll.x, y: -scroll.y)
        drawWorld(context: &world, layout: layout)

        drawStickyHeader(context: &context, layout: layout, scroll: scroll)
        drawStickyAxisHeader(context: &context)
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.11),
                    Color(red: 0.025, green: 0.028, blue: 0.04)
                ]),
                startPoint: rect.origin,
                endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )
    }

    private func drawWorld(context: inout GraphicsContext, layout: EventScheduleCanvasLayout) {
        drawTimeAxis(context: &context, layout: layout)
        drawStageColumns(context: &context, layout: layout)
        drawSlots(context: &context, layout: layout)
    }

    private func drawTimeAxis(context: inout GraphicsContext, layout: EventScheduleCanvasLayout) {
        for hour in layout.startHour...layout.endHour {
            let y = layout.headerHeight + CGFloat(hour - layout.startHour) * layout.hourHeight
            let label = Text(layout.hourLabel(hour))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            context.draw(label, at: CGPoint(x: layout.axisWidth - 10, y: y), anchor: .trailing)
        }
    }

    private func drawStageColumns(context: inout GraphicsContext, layout: EventScheduleCanvasLayout) {
        for stage in layout.stageLayouts {
            let columnRect = CGRect(
                x: stage.x,
                y: layout.headerHeight,
                width: layout.stageWidth,
                height: layout.bodyHeight
            )
            let columnPath = Path(roundedRect: columnRect, cornerRadius: 8)
            context.fill(columnPath, with: .color(.white.opacity(0.035)))

            for hour in layout.startHour...layout.endHour {
                let y = layout.headerHeight + CGFloat(hour - layout.startHour) * layout.hourHeight
                var path = Path()
                path.move(to: CGPoint(x: columnRect.minX, y: y))
                path.addLine(to: CGPoint(x: columnRect.maxX, y: y))
                context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
        }
    }

    private func drawSlots(context: inout GraphicsContext, layout: EventScheduleCanvasLayout) {
        for slot in layout.slots {
            let rect = slot.rect.insetBy(dx: 2, dy: 2)
            let path = Path(roundedRect: rect, cornerRadius: 9)
            let stageColor = slot.color

            context.addFilter(
                .shadow(
                    color: stageColor.opacity(selectedSlotID == slot.id ? 0.54 : 0.30),
                    radius: selectedSlotID == slot.id ? 18 : 12
                )
            )
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        stageColor.opacity(0.98),
                        stageColor.opacity(0.84)
                    ]),
                    startPoint: rect.origin,
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            context.addFilter(.shadow(color: .clear, radius: 0))
            context.stroke(path, with: .color(.white.opacity(0.88)), lineWidth: selectedSlotID == slot.id ? 2.1 : 1.2)

            let title = Text(slot.title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.78))
            context.draw(title, in: rect.insetBy(dx: 9, dy: 10))

            let time = Text(slot.timeRangeText)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.68))
            context.draw(
                time,
                at: CGPoint(x: rect.maxX - 8, y: rect.maxY - 9),
                anchor: .bottomTrailing
            )
        }
    }

    private func drawStickyHeader(
        context: inout GraphicsContext,
        layout: EventScheduleCanvasLayout,
        scroll: CGPoint
    ) {
        context.fill(
            Path(CGRect(x: layout.axisWidth, y: 0, width: layout.viewportSize.width - layout.axisWidth, height: layout.headerHeight)),
            with: .color(Color(red: 0.055, green: 0.06, blue: 0.085).opacity(0.96))
        )

        var clipped = context
        clipped.clip(to: Path(CGRect(x: layout.axisWidth, y: 0, width: layout.viewportSize.width - layout.axisWidth, height: layout.headerHeight)))

        for stage in layout.stageLayouts {
            let x = stage.x - scroll.x
            guard x < layout.viewportSize.width, x + layout.stageWidth > layout.axisWidth else { continue }

            let rect = CGRect(x: x, y: 8, width: layout.stageWidth, height: layout.headerHeight - 16)
            let path = Path(roundedRect: rect, cornerRadius: 11)
            clipped.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        stage.color.opacity(0.98),
                        stage.color.opacity(0.84)
                    ]),
                    startPoint: rect.origin,
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            clipped.stroke(path, with: .color(.white.opacity(0.90)), lineWidth: 1.2)

            let title = Text(stage.name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.78))
            clipped.draw(title, in: rect.insetBy(dx: 8, dy: 13))
        }
    }

    private func drawStickyAxisHeader(context: inout GraphicsContext) {
        let rect = CGRect(x: 0, y: 0, width: EventScheduleCanvasLayout.axisWidthValue, height: EventScheduleCanvasLayout.headerHeightValue)
        context.fill(Path(rect), with: .color(Color(red: 0.055, green: 0.06, blue: 0.085)))
        context.stroke(Path(rect), with: .color(.white.opacity(0.08)), lineWidth: 1)

        let label = Text("TIME")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
        context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }
}

private struct EventScheduleCanvasLayout {
    static let axisWidthValue: CGFloat = 56
    static let headerHeightValue: CGFloat = 76

    let day: EventScheduleCanvasDay
    let viewportSize: CGSize

    let axisWidth: CGFloat = axisWidthValue
    let headerHeight: CGFloat = headerHeightValue
    let stageWidth: CGFloat = 104
    let stageGap: CGFloat = 10
    let hourHeight: CGFloat = 92
    let startHour = 16
    let endHour = 28

    var bodyHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var contentWidth: CGFloat {
        axisWidth + stageGap + CGFloat(day.stages.count) * (stageWidth + stageGap)
    }

    var contentHeight: CGFloat {
        headerHeight + bodyHeight
    }

    var stageLayouts: [EventScheduleCanvasStageLayout] {
        day.stages.enumerated().map { index, stage in
            EventScheduleCanvasStageLayout(
                id: stage.id,
                name: stage.name,
                color: stage.color,
                x: axisWidth + stageGap + CGFloat(index) * (stageWidth + stageGap)
            )
        }
    }

    var slots: [EventScheduleCanvasSlotLayout] {
        day.slots.compactMap { slot in
            guard let stageIndex = day.stages.firstIndex(where: { $0.id == slot.stageID }) else { return nil }
            let x = axisWidth + stageGap + CGFloat(stageIndex) * (stageWidth + stageGap)
            let y = headerHeight + CGFloat(slot.startHour - Double(startHour)) * hourHeight
            let height = max(48, CGFloat(slot.endHour - slot.startHour) * hourHeight)
            let stage = day.stages[stageIndex]

            return EventScheduleCanvasSlotLayout(
                id: slot.id,
                stageName: stage.name,
                title: slot.title,
                timeRangeText: "\(timeText(slot.startHour))-\(timeText(slot.endHour))",
                color: stage.color,
                rect: CGRect(x: x, y: y, width: stageWidth, height: height)
            )
        }
    }

    func clampedScroll(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), max(0, contentWidth - viewportSize.width)),
            y: min(max(point.y, 0), max(0, contentHeight - viewportSize.height))
        )
    }

    func slotID(at location: CGPoint, scroll: CGPoint) -> String? {
        let world = CGPoint(x: location.x + scroll.x, y: location.y + scroll.y)
        return slots.last(where: { $0.rect.contains(world) })?.id
    }

    func hourLabel(_ hour: Int) -> String {
        let normalized = hour >= 24 ? hour - 24 : hour
        let suffix = normalized >= 12 ? "PM" : "AM"
        let hour12 = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(hour12) \(suffix)"
    }

    private func timeText(_ value: Double) -> String {
        let wholeHour = Int(value.rounded(.down))
        let minute = Int(((value - Double(wholeHour)) * 60).rounded())
        let normalizedHour = wholeHour >= 24 ? wholeHour - 24 : wholeHour
        return "\(String(format: "%02d", normalizedHour)):\(String(format: "%02d", minute))"
    }
}

private struct EventScheduleCanvasStageLayout {
    let id: String
    let name: String
    let color: Color
    let x: CGFloat
}

private struct EventScheduleCanvasSlotLayout {
    let id: String
    let stageName: String
    let title: String
    let timeRangeText: String
    let color: Color
    let rect: CGRect
}

private enum EventScheduleCanvasPrototypeData {
    static let days: [EventScheduleCanvasDay] = [
        makeDay(title: "Day 1", seed: 0, slotTarget: 82),
        makeDay(title: "Day 2", seed: 7, slotTarget: 116),
        makeDay(title: "Day 3", seed: 13, slotTarget: 96)
    ]

    private static let stageNames = [
        "Mainstage",
        "Atmosphere",
        "Crystal Garden",
        "Rose Garden",
        "Great Library",
        "Melodia",
        "Rise",
        "Planaxis",
        "Cage",
        "Moosebar",
        "Freedom",
        "Core",
        "Elixir",
        "House of Fortune",
        "Rave Cave"
    ]

    private static let artistNames = [
        "Amelie Lens", "Anyma", "Peggy Gou", "Mau P", "Charlotte de Witte",
        "Vintage Culture", "Argy", "FISHER", "Mochakk", "Sara Landry",
        "Mind Against", "Eli Brown", "HI-LO", "Nina Kraviz", "John Summit",
        "ARTBAT", "Cassian", "Meduza", "Dom Dolla", "Hardwell"
    ]

    private static let colors: [Color] = [
        Color(red: 0.97, green: 0.54, blue: 0.89),
        Color(red: 0.50, green: 0.87, blue: 0.98),
        Color(red: 0.54, green: 0.95, blue: 0.62),
        Color(red: 0.99, green: 0.73, blue: 0.42),
        Color(red: 0.90, green: 0.96, blue: 0.50),
        Color(red: 0.56, green: 0.67, blue: 0.99),
        Color(red: 0.98, green: 0.57, blue: 0.63),
        Color(red: 0.93, green: 0.56, blue: 0.79),
        Color(red: 0.56, green: 0.86, blue: 0.94)
    ]

    private static func makeDay(title: String, seed: Int, slotTarget: Int) -> EventScheduleCanvasDay {
        let stages = stageNames.enumerated().map { index, name in
            EventScheduleCanvasStage(
                id: "stage-\(index)",
                name: name,
                color: colors[index % colors.count]
            )
        }

        var slots: [EventScheduleCanvasSlot] = []
        let basePerStage = max(2, slotTarget / max(1, stages.count))
        var cursor = 0

        for stageIndex in stages.indices {
            let count = basePerStage + ((stageIndex + seed) % 4)
            var start = 16.0 + Double((stageIndex + seed) % 3) * 0.16

            for slotIndex in 0..<count {
                let duration = [0.75, 1.0, 1.0, 1.25, 1.5][(slotIndex + stageIndex + seed) % 5]
                let end = min(start + duration, 27.85)
                guard end > start + 0.25 else { break }

                let artist = artistNames[(cursor + stageIndex + seed) % artistNames.count]
                let suffix = slotIndex % 5 == 0 ? " b2b Guest" : ""
                slots.append(
                    EventScheduleCanvasSlot(
                        id: "\(title)-\(stageIndex)-\(slotIndex)",
                        stageID: stages[stageIndex].id,
                        title: artist + suffix,
                        startHour: start,
                        endHour: end
                    )
                )

                start = end + [0.05, 0.10, 0.16][(slotIndex + seed) % 3]
                cursor += 1
            }
        }

        return EventScheduleCanvasDay(title: title, stages: stages, slots: slots)
    }
}

private struct EventScheduleCanvasDay {
    let title: String
    let stages: [EventScheduleCanvasStage]
    let slots: [EventScheduleCanvasSlot]
}

private struct EventScheduleCanvasStage {
    let id: String
    let name: String
    let color: Color
}

private struct EventScheduleCanvasSlot {
    let id: String
    let stageID: String
    let title: String
    let startHour: Double
    let endHour: Double
}

struct EventScheduleCanvasPrototypeView_Previews: PreviewProvider {
    static var previews: some View {
        EventScheduleCanvasPrototypeView()
            .previewLayout(.fixed(width: 393, height: 852))
            .preferredColorScheme(.dark)
    }
}
#endif
