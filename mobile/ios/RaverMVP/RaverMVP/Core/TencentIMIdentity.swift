import Foundation
import CryptoKit

enum TencentIMIdentity {
    static func normalizePlatformUserIDForProfile(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return raw }
        return decodePlatformUserID(fromTencentIMUserID: normalized) ?? normalized
    }

    static func isTencentIMUserID(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("tu_") || normalized.hasPrefix("c2c_tu_")
    }

    static func decodePlatformUserID(fromTencentIMUserID value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixed: String
        if normalized.hasPrefix("c2c_tu_") {
            prefixed = String(normalized.dropFirst(4))
        } else {
            prefixed = normalized
        }

        guard prefixed.hasPrefix("tu_") else { return nil }
        let compact = String(prefixed.dropFirst(3))
        guard compact.count == 22 || compact.count == 24 else { return nil }

        var base64 = compact
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64), data.count == 16 else { return nil }
        let bytes = [UInt8](data)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        guard hex.count == 32 else { return nil }

        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }

    static func toTencentIMUserID(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("tu_") {
            return normalized
        }
        if normalized.hasPrefix("c2c_") {
            let stripped = String(normalized.dropFirst(4))
            return stripped.hasPrefix("tu_") ? stripped : "tu_\(stripped)"
        }
        return "tu_\(toStableShortID(normalized))"
    }

    private static func toStableShortID(_ value: String) -> String {
        if let uuidData = toCompactUUIDData(value) {
            return base64URLEncodedString(uuidData)
        }
        let digest = SHA256.hash(data: Data(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8))
        let hashData = Data(digest)
        return String(base64URLEncodedString(hashData).prefix(22))
    }

    private static func toCompactUUIDData(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let parsed = UUID(uuidString: trimmed) {
            return withUnsafeBytes(of: parsed.uuid) { Data($0) }
        }
        let compact = trimmed.replacingOccurrences(of: "-", with: "")
        guard compact.count == 32,
              compact.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }) else {
            return nil
        }
        var data = Data(capacity: 16)
        var index = compact.startIndex
        for _ in 0..<16 {
            let next = compact.index(index, offsetBy: 2)
            let byteString = compact[index..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    private static func base64URLEncodedString(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
