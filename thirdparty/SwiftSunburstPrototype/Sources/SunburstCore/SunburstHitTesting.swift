import CoreGraphics
import Foundation

public enum SunburstHitTesting {
    public static func hitSegment(
        at point: CGPoint,
        in size: CGSize,
        segments: [SunburstSegment]
    ) -> SunburstSegment? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let angle = projectedAngle(atan2(dy, dx))

        return segments
            .sorted { $0.depth > $1.depth }
            .first { segment in
                radius >= segment.innerRadius &&
                radius <= segment.outerRadius &&
                angle >= segment.startAngle &&
                angle <= segment.endAngle
            }
    }

    public static func isCenterTap(
        at point: CGPoint,
        in size: CGSize,
        segments: [SunburstSegment]
    ) -> Bool {
        guard let innerRadius = segments.map(\.innerRadius).min() else { return false }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy) < innerRadius
    }

    private static func projectedAngle(_ angle: Double) -> Double {
        var value = angle
        while value < -Double.pi / 2 { value += Double.pi * 2 }
        while value > Double.pi * 1.5 { value -= Double.pi * 2 }
        return value
    }
}
