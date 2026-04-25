import Foundation

enum ChatMessageSearchSource: String, Hashable, Codable {
    case localIndex
    case remoteFallback
}

struct ChatMessageSearchResult: Hashable {
    let message: ChatMessage
    let conversationID: String
    let source: ChatMessageSearchSource
    let matchScore: Int
}

protocol ChatMessageSearchRemoteDataSource {
    func searchMessages(query: String, conversationID: String?, limit: Int) async throws -> [ChatMessage]
}

struct ChatMessageSearchIndex {
    struct Hit {
        let conversationID: String
        let message: ChatMessage
        let score: Int
    }

    private struct Bucket {
        var messagesByID: [String: ChatMessage] = [:]
        var tokenToMessageIDs: [String: Set<String>] = [:]
    }

    private var bucketsByConversationID: [String: Bucket] = [:]

    mutating func reset() {
        bucketsByConversationID = [:]
    }

    mutating func replaceMessages(_ messages: [ChatMessage], conversationID: String) {
        guard !conversationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var bucket = Bucket()
        for message in deduplicatedMessages(messages) {
            guard shouldIndex(message) else { continue }
            bucket.messagesByID[message.id] = message
            for token in searchableTokens(for: message) {
                bucket.tokenToMessageIDs[token, default: []].insert(message.id)
            }
        }
        bucketsByConversationID[conversationID] = bucket
    }

    mutating func mergeMessage(_ message: ChatMessage, conversationID: String) {
        guard !conversationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard shouldIndex(message) else { return }

        var bucket = bucketsByConversationID[conversationID] ?? Bucket()
        if let previous = bucket.messagesByID[message.id] {
            remove(previous, from: &bucket)
        }

        bucket.messagesByID[message.id] = message
        for token in searchableTokens(for: message) {
            bucket.tokenToMessageIDs[token, default: []].insert(message.id)
        }
        bucketsByConversationID[conversationID] = bucket
    }

    mutating func clearConversation(_ conversationID: String) {
        bucketsByConversationID.removeValue(forKey: conversationID)
    }

    func search(query: String, conversationID: String?, limit: Int) -> [Hit] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        let queryTokens = tokenize(normalizedQuery)
        guard !queryTokens.isEmpty else { return [] }

        let targetBuckets: [(String, Bucket)]
        if let conversationID {
            if let bucket = bucketsByConversationID[conversationID] {
                targetBuckets = [(conversationID, bucket)]
            } else {
                targetBuckets = []
            }
        } else {
            targetBuckets = Array(bucketsByConversationID)
        }

        var hits: [Hit] = []
        for (bucketConversationID, bucket) in targetBuckets {
            var scoreByMessageID: [String: Int] = [:]

            for token in queryTokens {
                guard let messageIDs = bucket.tokenToMessageIDs[token] else { continue }
                for messageID in messageIDs {
                    scoreByMessageID[messageID, default: 0] += 1
                }
            }

            for (messageID, score) in scoreByMessageID where score >= queryTokens.count {
                guard let message = bucket.messagesByID[messageID] else { continue }
                hits.append(Hit(conversationID: bucketConversationID, message: message, score: score))
            }
        }

        let sorted = hits.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            if lhs.message.createdAt != rhs.message.createdAt {
                return lhs.message.createdAt > rhs.message.createdAt
            }
            return lhs.message.id > rhs.message.id
        }

        if limit <= 0 {
            return []
        }
        return Array(sorted.prefix(limit))
    }

    private mutating func remove(_ message: ChatMessage, from bucket: inout Bucket) {
        bucket.messagesByID.removeValue(forKey: message.id)
        for token in searchableTokens(for: message) {
            var messageIDs = bucket.tokenToMessageIDs[token] ?? []
            messageIDs.remove(message.id)
            if messageIDs.isEmpty {
                bucket.tokenToMessageIDs.removeValue(forKey: token)
            } else {
                bucket.tokenToMessageIDs[token] = messageIDs
            }
        }
    }

    private func shouldIndex(_ message: ChatMessage) -> Bool {
        switch message.kind {
        case .typing:
            return false
        default:
            return true
        }
    }

    private func deduplicatedMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var seen = Set<String>()
        var values: [ChatMessage] = []
        for message in messages where !seen.contains(message.id) {
            seen.insert(message.id)
            values.append(message)
        }
        return values
    }

    private func searchableTokens(for message: ChatMessage) -> [String] {
        var components: [String] = [message.content]
        if let fileName = message.media?.fileName, !fileName.isEmpty {
            components.append(fileName)
        }
        return tokenize(components.joined(separator: " "))
    }

    private func tokenize(_ raw: String) -> [String] {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        guard !normalized.isEmpty else { return [] }

        var tokens: [String] = []
        var currentWord = ""

        func flushCurrentWord() {
            guard !currentWord.isEmpty else { return }
            tokens.append(currentWord)
            currentWord = ""
        }

        for scalar in normalized.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                currentWord.unicodeScalars.append(scalar)
                continue
            }

            flushCurrentWord()
            if isCJK(scalar) {
                tokens.append(String(scalar))
            }
        }
        flushCurrentWord()

        if tokens.isEmpty {
            return [normalized]
        }

        var seen = Set<String>()
        var uniqueTokens: [String] = []
        for token in tokens where !token.isEmpty && !seen.contains(token) {
            seen.insert(token)
            uniqueTokens.append(token)
        }
        return uniqueTokens
    }

    private func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, // CJK Extension A
             0x4E00...0x9FFF, // CJK Unified Ideographs
             0xF900...0xFAFF, // CJK Compatibility Ideographs
             0x3040...0x30FF, // Hiragana + Katakana
             0xAC00...0xD7AF: // Hangul Syllables
            return true
        default:
            return false
        }
    }
}
