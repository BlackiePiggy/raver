import Foundation

enum ChatCustomCardWireType {
    static let event = "event"
    static let post = "post"
    static let ratingEvent = "rating_event"
    static let ratingUnit = "rating_unit"
    static let dj = "dj"
    static let set = "set"
    static let brand = "brand"
    static let label = "label"
    static let news = "news"
    static let ranking = "ranking"
    static let circleID = "circle_id"
    static let myCheckins = "my_checkins"
    static let eventRoute = "event_route"
    static let squadOfflineActivity = "squad_offline_activity"
}

enum ChatCustomCardCodec {
    private struct Envelope<Payload: Decodable>: Decodable {
        let businessID: String?
        let version: Int?
        let cardType: String?
        let payload: Payload?
    }

    static func decodePayload<Payload: Decodable>(
        _ payloadType: Payload.Type,
        cardType: String,
        from rawContent: String,
        decoder: JSONDecoder = JSONDecoder(),
        allowBarePayload: Bool = true,
        rejectBarePayload: ((Data) -> Bool)? = nil
    ) -> Payload? {
        guard let data = rawContent.data(using: .utf8) else { return nil }

        if let envelope = try? decoder.decode(Envelope<Payload>.self, from: data),
           envelope.cardType == cardType,
           let payload = envelope.payload {
            return payload
        }

        guard allowBarePayload else { return nil }
        if rejectBarePayload?(data) == true { return nil }
        return try? decoder.decode(Payload.self, from: data)
    }

    static func jsonObjectContainsAnyKey(_ keys: Set<String>, in data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return keys.contains { object[$0] != nil }
    }
}
