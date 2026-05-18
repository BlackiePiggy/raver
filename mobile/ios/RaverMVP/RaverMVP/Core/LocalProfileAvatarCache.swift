import Foundation

enum LocalProfileAvatarCache {
    static func save(imageData: Data, userId: String) throws -> URL {
        let directory = try avatarDirectory()
        let url = directory.appendingPathComponent("\(userId)-avatar.jpg", isDirectory: false)
        try imageData.write(to: url, options: [.atomic])
        return url
    }

    private static func avatarDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("LocalProfileAvatars", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
