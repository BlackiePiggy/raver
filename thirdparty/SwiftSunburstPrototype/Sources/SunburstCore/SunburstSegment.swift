import CoreGraphics
import SwiftUI

public struct SunburstSegment: Identifiable, Hashable {
    public let id: String
    public let node: GenreNode
    public let parentId: String?
    public let depth: Int
    public let x0: Double
    public let x1: Double
    public let y0: Double
    public let y1: Double
    public let startAngle: Double
    public let endAngle: Double
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let color: Color

    public var midAngle: Double {
        (startAngle + endAngle) / 2
    }

    public var angleSpan: Double {
        endAngle - startAngle
    }
}
