import Foundation

enum DiscoverNewsCodec {
    static let marker = Post.raverNewsMarker

    static func encode(_ draft: DiscoverNewsDraft) -> String {
        let bodyRaw = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryRaw = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines: [String?] = [
            marker,
            "标题：\(singleLine(draft.title))",
            "分类：\(draft.category.title)",
            "来源：\(singleLine(draft.source))",
            summaryRaw.isEmpty ? nil : "摘要：\(singleLine(draft.summary))",
            bodyRaw.isEmpty ? nil : "正文MD64:\(base64UTF8(draft.body))",
            draft.link?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? "链接：\(singleLine(draft.link ?? ""))"
                : nil
        ]
        return lines.compactMap { $0 }.joined(separator: "\n")
    }

    static func decode(post: Post) -> DiscoverNewsArticle? {
        let lines = post.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.contains(marker) else { return nil }

        let title = value(for: ["标题", "title"], in: lines) ?? L("未命名资讯", "Untitled News")
        let summary = value(for: ["摘要", "summary"], in: lines) ?? ""
        let source = value(for: ["来源", "source"], in: lines) ?? L("社区投稿", "Community")
        let rawCategory = value(for: ["分类", "category"], in: lines) ?? DiscoverNewsCategory.community.title
        let body = decodedBody(in: lines) ?? value(for: ["正文", "content", "body"], in: lines) ?? ""
        let link = value(for: ["链接", "url", "link"], in: lines)

        let trimmedDisplayName = post.author.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorName = trimmedDisplayName.isEmpty ? post.author.username : trimmedDisplayName

        return DiscoverNewsArticle(
            id: post.id,
            category: DiscoverNewsCategory.mapFromRaw(rawCategory),
            source: source,
            title: title,
            summary: summary,
            body: body,
            link: link,
            coverImageURL: post.images.first,
            publishedAt: post.displayPublishedAt ?? post.createdAt,
            replyCount: post.commentCount,
            authorID: post.author.id,
            authorUsername: post.author.username,
            authorName: authorName,
            authorAvatarURL: post.author.avatarURL,
            legacyEventID: post.eventID,
            boundDjIDs: dedupeBindingIDs(post.boundDjIDs),
            boundBrandIDs: dedupeBindingIDs(post.boundBrandIDs),
            boundEventIDs: dedupeBindingIDs(post.boundEventIDs)
        )
    }

    private static func dedupeBindingIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in ids {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private static func value(for keys: [String], in lines: [String]) -> String? {
        for line in lines {
            for key in keys {
                if let found = valueAfter(key: key, in: line) {
                    return found
                }
            }
        }
        return nil
    }

    private static func decodedBody(in lines: [String]) -> String? {
        guard let encoded = value(for: ["正文MD64", "content_md64", "body_md64"], in: lines),
              let data = Data(base64Encoded: encoded),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    private static func valueAfter(key: String, in line: String) -> String? {
        let pairs = ["\(key)：", "\(key):", "\(key.uppercased())：", "\(key.uppercased()):"]
        for prefix in pairs where line.hasPrefix(prefix) {
            let raw = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
        return nil
    }

    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func base64UTF8(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }
}

func fetchDiscoverNewsArticles(
    socialService: SocialService,
    maxPages: Int = 8
) async throws -> [DiscoverNewsArticle] {
    var cursor: String?
    var pageCount = 0
    var seen = Set<String>()
    var articles: [DiscoverNewsArticle] = []

    repeat {
        let page = try await socialService.fetchFeed(cursor: cursor)
        let parsed = page.posts.compactMap { DiscoverNewsCodec.decode(post: $0) }
        for article in parsed where seen.insert(article.id).inserted {
            articles.append(article)
        }
        cursor = page.nextCursor
        pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return articles.sorted { $0.publishedAt > $1.publishedAt }
}
