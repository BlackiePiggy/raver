import SwiftUI

enum LearnGenreSunburstBuilder {
    static let rootID = "learn-genres-root"

    static func makeRootNode(from genres: [LearnGenreTreeSummaryNode]) -> GenreSunburstNode {
        GenreSunburstNode(
            id: rootID,
            name: LT("流派树", "Genre Tree", "ジャンルツリー"),
            path: rootID,
            themeColor: nil,
            description: LT("点击外圈进入分支，点击中心返回上一级。", "Tap outer rings to dive in, tap the center to go back.", "外周リングで深掘りし、中央タップで戻ります。"),
            example: "",
            spotifyTrackURL: "",
            wikipediaURL: "",
            keyArtists: [],
            keyArtistBindings: [],
            children: genres.map { GenreSunburstNode(summaryNode: $0, parentPath: rootID) }
        )
    }

    static func makeSearchIndex(root: GenreSunburstNode) -> [GenreSunburstSearchItem] {
        root.allDescendants()
            .filter { $0.id != root.id }
            .map { node in
                GenreSunburstSearchItem(
                    node: node,
                    parentId: node.parentNode(root: root)?.id,
                    pathText: node.pathDisplayText(root: root)
                )
            }
    }

    static var loadingRootNode: GenreSunburstNode {
        GenreSunburstNode(
            id: "learn-genres-loading-root",
            name: LT("流派树", "Genre Tree", "ジャンルツリー"),
            path: "learn-genres-loading-root",
            themeColor: nil,
            description: "",
            example: "",
            spotifyTrackURL: "",
            wikipediaURL: "",
            keyArtists: [],
            keyArtistBindings: [],
            children: []
        )
    }
}

struct GenreSunburstSearchItem: Identifiable, Sendable {
    let id: String
    let node: GenreSunburstNode
    let parentId: String?
    let pathText: String
    let nameLower: String

    init(node: GenreSunburstNode, parentId: String?, pathText: String) {
        self.id = node.id
        self.node = node
        self.parentId = parentId
        self.pathText = pathText
        self.nameLower = node.name.lowercased()
    }

    func score(for query: String) -> Int {
        var score = 0
        if nameLower == query { score += 1200 }
        if nameLower.hasPrefix(query) { score += 700 }
        if nameLower.contains(query) { score += 300 }
        return score
    }
}

extension GenreSunburstSearchItem {
    static func search(items: [GenreSunburstSearchItem], query: String) -> [GenreSunburstSearchItem] {
        items
            .map { item in (item, item.score(for: query)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.node.leafCount > rhs.0.node.leafCount
            }
            .prefix(8)
            .map(\.0)
    }
}

extension GenreSunburstNode {
    func allDescendants(includeSelf: Bool = true) -> [GenreSunburstNode] {
        var output: [GenreSunburstNode] = []
        if includeSelf { output.append(self) }
        for child in children {
            output.append(contentsOf: child.allDescendants(includeSelf: true))
        }
        return output
    }

    func parentNode(root: GenreSunburstNode) -> GenreSunburstNode? {
        guard let path = root.pathToNode(withId: id), path.count > 1 else { return nil }
        return path[path.count - 2]
    }

    func pathDisplayText(root: GenreSunburstNode) -> String {
        guard let path = root.pathToNode(withId: id) else { return "" }
        let names = path.dropFirst().map(\.name)
        return names.joined(separator: " / ")
    }
}

struct GenreSunburstNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let themeColor: String?
    let description: String
    let descriptionI18n: WebBiText?
    let example: String
    let exampleI18n: WebBiText?
    let spotifyTrackURL: String
    let wikipediaURL: String
    let keyArtists: [String]
    let keyArtistBindings: [LearnGenreKeyArtistBinding]
    let children: [GenreSunburstNode]

    init(
        id: String,
        name: String,
        path: String,
        themeColor: String? = nil,
        description: String,
        descriptionI18n: WebBiText? = nil,
        example: String,
        exampleI18n: WebBiText? = nil,
        spotifyTrackURL: String,
        wikipediaURL: String,
        keyArtists: [String],
        keyArtistBindings: [LearnGenreKeyArtistBinding] = [],
        children: [GenreSunburstNode]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.themeColor = themeColor
        self.description = description
        self.descriptionI18n = descriptionI18n
        self.example = example
        self.exampleI18n = exampleI18n
        self.spotifyTrackURL = spotifyTrackURL
        self.wikipediaURL = wikipediaURL
        self.keyArtists = keyArtists
        self.keyArtistBindings = keyArtistBindings
        self.children = children
    }

    init(summaryNode: LearnGenreTreeSummaryNode, parentPath: String) {
        self.id = summaryNode.id
        self.name = summaryNode.name
        self.path = summaryNode.path ?? "\(parentPath)/\(summaryNode.id)"
        self.themeColor = summaryNode.themeColor
        self.description = ""
        self.descriptionI18n = nil
        self.example = ""
        self.exampleI18n = nil
        self.spotifyTrackURL = ""
        self.wikipediaURL = ""
        self.keyArtists = []
        self.keyArtistBindings = []
        self.children = (summaryNode.children ?? []).map { GenreSunburstNode(summaryNode: $0, parentPath: "\(parentPath)/\(summaryNode.id)") }
    }

    var isLeaf: Bool {
        children.isEmpty
    }

    var leafCount: Int {
        if children.isEmpty { return 1 }
        return children.reduce(0) { $0 + $1.leafCount }
    }

    func firstNode(withId targetId: String) -> GenreSunburstNode? {
        if id == targetId { return self }

        for child in children {
            if let match = child.firstNode(withId: targetId) {
                return match
            }
        }

        return nil
    }

    func pathToNode(withId targetId: String) -> [GenreSunburstNode]? {
        if id == targetId { return [self] }

        for child in children {
            if let childPath = child.pathToNode(withId: targetId) {
                return [self] + childPath
            }
        }

        return nil
    }
}

struct GenreSunburstSegment: Identifiable, Hashable {
    let id: String
    let node: GenreSunburstNode
    let parentId: String?
    let depth: Int
    let x0: Double
    let x1: Double
    let y0: Double
    let y1: Double
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let color: Color

    var midAngle: Double {
        (startAngle + endAngle) / 2
    }

    var angleSpan: Double {
        endAngle - startAngle
    }
}

struct GenreSunburstFocus: Equatable, Sendable, VectorArithmetic {
    var angleStart: Double
    var angleEnd: Double
    var depthStart: Double
    var depthEnd: Double

    static let root = GenreSunburstFocus(
        angleStart: 0,
        angleEnd: 1,
        depthStart: 0,
        depthEnd: 1
    )

    static var zero: GenreSunburstFocus {
        GenreSunburstFocus(angleStart: 0, angleEnd: 0, depthStart: 0, depthEnd: 0)
    }

    static func + (lhs: GenreSunburstFocus, rhs: GenreSunburstFocus) -> GenreSunburstFocus {
        GenreSunburstFocus(
            angleStart: lhs.angleStart + rhs.angleStart,
            angleEnd: lhs.angleEnd + rhs.angleEnd,
            depthStart: lhs.depthStart + rhs.depthStart,
            depthEnd: lhs.depthEnd + rhs.depthEnd
        )
    }

    static func - (lhs: GenreSunburstFocus, rhs: GenreSunburstFocus) -> GenreSunburstFocus {
        GenreSunburstFocus(
            angleStart: lhs.angleStart - rhs.angleStart,
            angleEnd: lhs.angleEnd - rhs.angleEnd,
            depthStart: lhs.depthStart - rhs.depthStart,
            depthEnd: lhs.depthEnd - rhs.depthEnd
        )
    }

    mutating func scale(by rhs: Double) {
        angleStart *= rhs
        angleEnd *= rhs
        depthStart *= rhs
        depthEnd *= rhs
    }

    var magnitudeSquared: Double {
        angleStart * angleStart +
            angleEnd * angleEnd +
            depthStart * depthStart +
            depthEnd * depthEnd
    }
}

enum LearnGenreThemePalette {
    private struct ThemeDefinition {
        let aliases: [String]
        let color: Color
    }

    private static let explicitThemes: [ThemeDefinition] = [
        ThemeDefinition(
            aliases: ["house", "garage", "ukg"],
            color: Color(red: 0.18, green: 0.72, blue: 0.96)
        ),
        ThemeDefinition(
            aliases: ["techno", "industrial"],
            color: Color(red: 0.94, green: 0.30, blue: 0.74)
        ),
        ThemeDefinition(
            aliases: ["trance", "psytrance", "goa"],
            color: Color(red: 0.46, green: 0.86, blue: 0.40)
        ),
        ThemeDefinition(
            aliases: ["drum-and-bass", "drum-bass", "dnb", "jungle"],
            color: Color(red: 0.96, green: 0.54, blue: 0.18)
        ),
        ThemeDefinition(
            aliases: ["dubstep", "bass", "uk-bass"],
            color: Color(red: 0.48, green: 0.42, blue: 0.92)
        ),
        ThemeDefinition(
            aliases: ["breakbeat", "breaks", "electro"],
            color: Color(red: 0.08, green: 0.82, blue: 0.70)
        ),
        ThemeDefinition(
            aliases: ["hardstyle", "hard-dance", "hardcore", "gabber"],
            color: Color(red: 0.90, green: 0.25, blue: 0.35)
        ),
        ThemeDefinition(
            aliases: ["ambient", "downtempo", "chillout"],
            color: Color(red: 0.72, green: 0.62, blue: 0.96)
        ),
        ThemeDefinition(
            aliases: ["disco", "funk", "nu-disco"],
            color: Color(red: 0.86, green: 0.78, blue: 0.28)
        ),
        ThemeDefinition(
            aliases: ["progressive", "melodic", "organic"],
            color: Color(red: 0.30, green: 0.48, blue: 0.92)
        )
    ]

    private static let genericRootKeys: Set<String> = [
        "electronic",
        "electronic-music",
        "edm",
        "dance",
        "dance-music",
        "genre",
        "genres",
        "music",
        "styles"
    ]

    private static let fallbackColors: [Color] = [
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

    static func color(for node: GenreSunburstNode) -> Color {
        if let configured = configuredColor(from: node.themeColor) {
            return configured
        }
        return color(forPath: node.path, fallbackID: node.id, fallbackName: node.name)
    }

    static func color(for genre: LearnGenreDetail) -> Color {
        if let configured = configuredColor(from: genre.themeColor) {
            return configured
        }
        return color(forPath: genre.path, fallbackID: genre.id, fallbackName: genre.name)
    }

    static func color(
        forPath path: String?,
        fallbackID: String? = nil,
        fallbackName: String? = nil
    ) -> Color {
        let key = topLevelKey(path: path, fallbackID: fallbackID, fallbackName: fallbackName)
        return explicitColor(for: key) ?? fallbackColor(for: key)
    }

    static func topLevelKey(
        path: String?,
        fallbackID: String? = nil,
        fallbackName: String? = nil
    ) -> String {
        let components = normalizedPathComponents(from: path)
        if components.count >= 2, let first = components.first, genericRootKeys.contains(first) {
            return components[1]
        }
        if let first = components.first {
            return first
        }
        return normalizedKey(fallbackID) ?? normalizedKey(fallbackName) ?? "genre-default"
    }

    private static func explicitColor(for key: String) -> Color? {
        for theme in explicitThemes {
            if theme.aliases.contains(where: { alias in
                key == alias ||
                key.hasPrefix("\(alias)-") ||
                key.hasSuffix("-\(alias)") ||
                key.contains("-\(alias)-") ||
                key.contains(alias)
            }) {
                return theme.color
            }
        }
        return nil
    }

    private static func fallbackColor(for key: String) -> Color {
        fallbackColors[stableHash(key) % fallbackColors.count]
    }

    private static func configuredColor(from raw: String?) -> Color? {
        guard let normalized = normalizedHexColor(raw) else { return nil }
        let red = Double(Int(normalized.prefix(2), radix: 16) ?? 0) / 255
        let green = Double(Int(normalized.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
        let blue = Double(Int(normalized.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private static func normalizedHexColor(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if trimmed.count == 3 {
            let expanded = trimmed.map { "\($0)\($0)" }.joined()
            return expanded.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil ? expanded : nil
        }
        guard trimmed.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
            return nil
        }
        return trimmed
    }

    private static func normalizedPathComponents(from path: String?) -> [String] {
        guard let path else { return [] }
        return path
            .split(separator: "/")
            .compactMap { normalizedKey(String($0)) }
    }

    private static func normalizedKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }

        let collapsed = String(normalized)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return collapsed.isEmpty ? nil : collapsed
    }

    private static func stableHash(_ value: String) -> Int {
        var hash = 5381
        for scalar in value.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }
}

struct GenreSunburstLayoutCache: Equatable {
    let rootId: String
    let baseSegments: [GenreSunburstSegment]
    let focusById: [String: GenreSunburstFocus]
    let nodeById: [String: GenreSunburstNode]
    let pathById: [String: [GenreSunburstNode]]

    init(root: GenreSunburstNode) {
        let maxDepth = max(1, GenreSunburstLayout.maxDepth(from: root))
        let palette = GenreSunburstLayout.paletteMap(root: root)
        var nodes: [String: GenreSunburstNode] = [root.id: root]
        var paths: [String: [GenreSunburstNode]] = [root.id: [root]]
        var segments: [GenreSunburstSegment] = []

        GenreSunburstLayout.partition(
            root: root,
            maxDepth: maxDepth,
            topLevelPalette: palette,
            output: &segments
        )
        Self.collectIndexes(node: root, path: [root], nodes: &nodes, paths: &paths)

        self.rootId = root.id
        self.baseSegments = segments
        self.nodeById = nodes
        self.pathById = paths
        self.focusById = Dictionary(uniqueKeysWithValues: segments.map { segment in
            (
                segment.id,
                GenreSunburstFocus(
                    angleStart: segment.x0,
                    angleEnd: segment.x1,
                    depthStart: segment.y0,
                    depthEnd: 1
                )
            )
        })
    }

    func focus(for nodeId: String?) -> GenreSunburstFocus {
        guard let nodeId else { return .root }
        return focusById[nodeId] ?? .root
    }

    func node(withId nodeId: String?) -> GenreSunburstNode? {
        guard let nodeId else { return nil }
        return nodeById[nodeId]
    }

    func path(to nodeId: String?) -> [GenreSunburstNode]? {
        guard let nodeId else { return nil }
        return pathById[nodeId]
    }

    func segments(in size: CGSize, focus: GenreSunburstFocus) -> [GenreSunburstSegment] {
        let chartRadius = max(10, min(size.width, size.height) * 0.485)
        return baseSegments.compactMap { segment in
            GenreSunburstLayout.project(segment, radius: chartRadius, focus: focus)
        }
    }

    private static func collectIndexes(
        node: GenreSunburstNode,
        path: [GenreSunburstNode],
        nodes: inout [String: GenreSunburstNode],
        paths: inout [String: [GenreSunburstNode]]
    ) {
        nodes[node.id] = node
        paths[node.id] = path

        for child in node.children {
            collectIndexes(node: child, path: path + [child], nodes: &nodes, paths: &paths)
        }
    }
}

enum GenreSunburstLayout {
    static func partition(
        root: GenreSunburstNode,
        maxDepth: Int,
        topLevelPalette: [String: Color],
        output: inout [GenreSunburstSegment]
    ) {
        let totalWeight = Double(root.children.reduce(0) { $0 + $1.leafCount })
        var cursor = 0.0

        for child in root.children {
            let span = totalWeight == 0 ? 0 : Double(child.leafCount) / totalWeight
            appendPartition(
                node: child,
                parentId: root.id,
                depth: 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                topLevelId: child.id,
                output: &output
            )
            cursor += span
        }
    }

    private static func appendPartition(
        node: GenreSunburstNode,
        parentId: String?,
        depth: Int,
        maxDepth: Int,
        x0: Double,
        x1: Double,
        topLevelPalette: [String: Color],
        topLevelId: String,
        output: inout [GenreSunburstSegment]
    ) {
        let y0 = Double(depth - 1) / Double(maxDepth)
        let y1 = Double(depth) / Double(maxDepth)

        output.append(
            GenreSunburstSegment(
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
                depth: depth + 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                topLevelId: topLevelId,
                output: &output
            )
            cursor += span
        }
    }

    static func project(
        _ segment: GenreSunburstSegment,
        radius: CGFloat,
        focus: GenreSunburstFocus
    ) -> GenreSunburstSegment? {
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

        return GenreSunburstSegment(
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

    static func maxDepth(from node: GenreSunburstNode) -> Int {
        if node.children.isEmpty { return 0 }
        return 1 + (node.children.map(maxDepth).max() ?? 0)
    }

    static func paletteMap(root: GenreSunburstNode) -> [String: Color] {
        Dictionary(uniqueKeysWithValues: root.children.map { node in
            (node.id, LearnGenreThemePalette.color(for: node))
        })
    }
}

enum GenreSunburstHitTesting {
    static func hitSegment(
        at point: CGPoint,
        in size: CGSize,
        segments: [GenreSunburstSegment]
    ) -> GenreSunburstSegment? {
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

    static func isCenterTap(
        at point: CGPoint,
        in size: CGSize,
        segments: [GenreSunburstSegment]
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
