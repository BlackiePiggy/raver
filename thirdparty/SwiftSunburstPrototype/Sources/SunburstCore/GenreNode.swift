import Foundation

public struct GenreNode: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let description: String
    public let example: String
    public let spotifyTrackURL: String
    public let wikipediaURL: String
    public let keyArtists: [String]
    public let children: [GenreNode]

    public init(
        id: String,
        name: String,
        path: String,
        description: String,
        example: String,
        spotifyTrackURL: String,
        wikipediaURL: String,
        keyArtists: [String],
        children: [GenreNode]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.description = description
        self.example = example
        self.spotifyTrackURL = spotifyTrackURL
        self.wikipediaURL = wikipediaURL
        self.keyArtists = keyArtists
        self.children = children
    }
}

public extension GenreNode {
    var isLeaf: Bool {
        children.isEmpty
    }

    var leafCount: Int {
        if children.isEmpty { return 1 }
        return children.reduce(0) { $0 + $1.leafCount }
    }

    func firstNode(withId targetId: String) -> GenreNode? {
        if id == targetId { return self }

        for child in children {
            if let match = child.firstNode(withId: targetId) {
                return match
            }
        }

        return nil
    }

    func pathToNode(withId targetId: String) -> [GenreNode]? {
        if id == targetId { return [self] }

        for child in children {
            if let childPath = child.pathToNode(withId: targetId) {
                return [self] + childPath
            }
        }

        return nil
    }
}
