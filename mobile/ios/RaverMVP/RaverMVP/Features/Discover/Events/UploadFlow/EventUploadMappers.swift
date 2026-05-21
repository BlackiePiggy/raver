import Foundation

enum EventUploadMappers {
    static func imageAssets(from draft: EventUploadDraft) -> [WebEventImageAsset] {
        EventUploadImageZone.allCases.flatMap { zone in
            (draft.imageZones[zone] ?? []).enumerated().compactMap { index, image in
                guard let url = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else {
                    return nil
                }
                return WebEventImageAsset(
                    url: url,
                    type: zone.backendType,
                    label: zone.defaultLabel,
                    sort: image.sortOrder,
                    order: index + 1,
                    source: "ios-event-upload-v2",
                    fileName: image.fileName
                )
            }
        }
    }

    static func primaryCoverURL(from draft: EventUploadDraft) -> String? {
        firstRemoteURL(in: .cover, draft: draft) ?? firstRemoteURL(in: .poster, draft: draft)
    }

    static func primaryLineupURL(from draft: EventUploadDraft) -> String? {
        firstRemoteURL(in: .lineup, draft: draft)
    }

    static func createInput(from draft: EventUploadDraft) -> CreateEventInput {
        let language = draft.preferredLanguage
        let name = draft.name.primaryValue(preferredLanguage: language).trimmed
        let city = draft.city.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let country = draft.country.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let address = draft.detailAddress.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let timeZone = draft.timeZoneIdentifier.trimmed.eventUploadMapperNilIfBlank ?? "Asia/Shanghai"
        let ticketMin = Double(draft.ticket.priceMin.trimmed)
        let ticketMax = Double(draft.ticket.priceMax.trimmed)
        let ticketTiers = ticketTierInputs(min: ticketMin, max: ticketMax, currency: draft.ticket.currency)

        return CreateEventInput(
            name: name,
            wikiFestivalId: draft.organizerFestivalID?.trimmed.eventUploadMapperNilIfBlank,
            abbreviation: draft.abbreviation.trimmed.eventUploadMapperNilIfBlank,
            description: nil,
            eventType: EventTypeOption.submissionValue(for: draft.eventType),
            city: city,
            cityI18n: localizedText(from: draft.city, language: language),
            country: country,
            countryI18n: localizedText(from: draft.country, language: language),
            manualLocation: manualLocation(address: address),
            locationPoint: locationPoint(from: draft, address: address, city: city),
            latitude: draft.latitude,
            longitude: draft.longitude,
            ticketUrl: draft.ticket.ticketURL.trimmed.eventUploadMapperNilIfBlank,
            ticketCurrency: draft.ticket.currency.trimmed.uppercased().eventUploadMapperNilIfBlank,
            officialWebsite: draft.sourceURL.trimmed.eventUploadMapperNilIfBlank,
            startDate: draft.startDate,
            endDate: draft.endDate,
            timeZone: timeZone,
            timeZoneCity: draft.selectedTimeZoneLookup?.city,
            timeZoneProvince: draft.selectedTimeZoneLookup?.exactProvince.eventUploadMapperNilIfBlank ?? draft.selectedTimeZoneLookup?.province.eventUploadMapperNilIfBlank,
            timeZoneCountry: draft.selectedTimeZoneLookup?.country,
            timeZoneStateAnsi: draft.selectedTimeZoneLookup?.stateAnsi.eventUploadMapperNilIfBlank,
            timeZoneLat: draft.selectedTimeZoneLookup?.lat,
            timeZoneLng: draft.selectedTimeZoneLookup?.lng,
            dayRolloverHour: draft.dayRolloverHour,
            stageOrder: normalizedStages(from: draft),
            coverImageUrl: primaryCoverURL(from: draft),
            lineupImageUrl: primaryLineupURL(from: draft),
            imageAssets: imageAssets(from: draft).isEmpty ? nil : imageAssets(from: draft),
            ticketTiers: ticketTiers,
            lineupArtists: lineupArtistInputs(from: draft),
            lineupSlots: lineupSlotInputs(from: draft),
            status: EventVisualStatus.resolve(startDate: draft.startDate, endDate: draft.endDate).apiValue
        )
    }

    static func updateInput(from draft: EventUploadDraft) -> UpdateEventInput {
        let create = createInput(from: draft)
        return UpdateEventInput(
            name: create.name,
            abbreviation: create.abbreviation ?? "",
            description: create.description ?? "",
            eventType: create.eventType,
            city: create.city,
            cityI18n: create.cityI18n,
            country: create.country,
            countryI18n: create.countryI18n,
            manualLocation: create.manualLocation,
            locationPoint: create.locationPoint,
            latitude: create.latitude,
            longitude: create.longitude,
            ticketUrl: create.ticketUrl ?? "",
            ticketCurrency: create.ticketCurrency ?? "",
            ticketNotes: "",
            officialWebsite: create.officialWebsite ?? "",
            startDate: create.startDate,
            endDate: create.endDate,
            timeZone: create.timeZone,
            timeZoneCity: create.timeZoneCity,
            timeZoneProvince: create.timeZoneProvince,
            timeZoneCountry: create.timeZoneCountry,
            timeZoneStateAnsi: create.timeZoneStateAnsi,
            timeZoneLat: create.timeZoneLat,
            timeZoneLng: create.timeZoneLng,
            dayRolloverHour: create.dayRolloverHour,
            stageOrder: create.stageOrder,
            coverImageUrl: create.coverImageUrl ?? "",
            lineupImageUrl: create.lineupImageUrl ?? "",
            imageAssets: create.imageAssets,
            ticketTiers: create.ticketTiers,
            lineupArtists: create.lineupArtists,
            lineupSlots: create.lineupSlots,
            status: create.status,
            clearManualLocation: create.manualLocation == nil
        )
    }

    private static func firstRemoteURL(in zone: EventUploadImageZone, draft: EventUploadDraft) -> String? {
        (draft.imageZones[zone] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { $0.remoteURL?.trimmed.eventUploadMapperNilIfBlank }
            .first
    }

    private static func localizedText(from fields: EventUploadLocalizedFields, language: EventUploadPreferredLanguage) -> WebBiText? {
        let primary = fields.primaryValue(preferredLanguage: language).trimmed
        guard !primary.isEmpty else { return nil }
        return WebBiText(
            en: fields.en.trimmed.eventUploadMapperNilIfBlank ?? primary,
            zh: fields.zh.trimmed.eventUploadMapperNilIfBlank ?? primary,
            ja: fields.ja.trimmed.eventUploadMapperNilIfBlank,
            enFull: fields.enFull.trimmed.eventUploadMapperNilIfBlank
        )
    }

    private static func manualLocation(address: String?) -> WebEventManualLocation? {
        guard let address else { return nil }
        let text = WebBiText(en: address, zh: address)
        return WebEventManualLocation(
            detailAddressI18n: text,
            formattedAddressI18n: text,
            selectedAt: Date()
        )
    }

    private static func locationPoint(from draft: EventUploadDraft, address: String?, city: String?) -> WebEventLocationPoint? {
        guard let latitude = draft.latitude, let longitude = draft.longitude else { return nil }
        let addressText = (draft.pickedMapAddress.trimmed.eventUploadMapperNilIfBlank ?? address)
            .map { WebBiText(en: $0, zh: $0) }
        let placeName = draft.pickedPlaceName.trimmed.eventUploadMapperNilIfBlank
            .map { WebBiText(en: $0, zh: $0) }
        return WebEventLocationPoint(
            provider: "apple-mapkit",
            sourceMode: "ios-event-upload-v2",
            location: WebEventLocationCoordinate(lng: longitude, lat: latitude),
            nameI18n: placeName,
            addressI18n: addressText,
            formattedAddressI18n: addressText,
            city: city
        )
    }

    private static func normalizedStages(from draft: EventUploadDraft) -> [String]? {
        let values = draft.stageEntries.enumerated().map { index, stage in
            let trimmed = stage.trimmed
            return trimmed.isEmpty ? defaultStageName(at: index) : trimmed
        }
        return values.isEmpty ? nil : values
    }

    private static func defaultStageName(at index: Int) -> String {
        index == 0 ? LT("主舞台", "Main Stage", "メインステージ") : LT("舞台 \(index + 1)", "Stage \(index + 1)", "ステージ \(index + 1)")
    }

    private static func ticketTierInputs(min: Double?, max: Double?, currency: String) -> [EventTicketTierInput]? {
        let normalizedCurrency = currency.trimmed.uppercased().eventUploadMapperNilIfBlank
        var tiers: [EventTicketTierInput] = []
        if let min {
            tiers.append(EventTicketTierInput(name: "Min", price: min, currency: normalizedCurrency, sortOrder: 1))
        }
        if let max, max != min {
            tiers.append(EventTicketTierInput(name: "Max", price: max, currency: normalizedCurrency, sortOrder: 2))
        }
        return tiers.isEmpty ? nil : tiers
    }

    private static func lineupArtistInputs(from draft: EventUploadDraft) -> [EventLineupArtistInput]? {
        let lineupArtists = draft.lineupOnlySlots.enumerated().compactMap { offset, slot -> EventLineupArtistInput? in
            let performerNames = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmed }
                .filter { !$0.isEmpty }
            guard performerNames.count == slot.actType.performerCount else { return nil }
            let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: performerNames)
            guard !name.isEmpty else { return nil }
            let djIDs = slot.performerDJIDs
                .prefix(slot.actType.performerCount)
                .compactMap { $0?.trimmed.eventUploadMapperNilIfBlank }
            let memberDJIDs = Array(slot.performerDJIDs.prefix(slot.actType.performerCount)).map { $0?.trimmed.eventUploadMapperNilIfBlank }
            return EventLineupArtistInput(
                djId: djIDs.first,
                memberDjIds: memberDJIDs.contains(where: { $0 != nil }) ? memberDJIDs : nil,
                memberNames: performerNames,
                djName: name,
                sortOrder: offset + 1
            )
        }
        return lineupArtists.isEmpty ? nil : lineupArtists
    }

    private static func lineupSlotInputs(from draft: EventUploadDraft) -> [EventLineupSlotInput]? {
        let timetableSlots = draft.timetableSlots.enumerated().compactMap { index, slot -> EventLineupSlotInput? in
            let performerNames = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmed }
                .filter { !$0.isEmpty }
            guard performerNames.count == slot.actType.performerCount else { return nil }
            let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: performerNames)
            guard !name.isEmpty else { return nil }
            let memberDJIDs = Array(slot.performerDJIDs.prefix(slot.actType.performerCount)).map { $0?.trimmed.eventUploadMapperNilIfBlank }
            let primaryDJID = memberDJIDs.compactMap { $0 }.first
            return EventLineupSlotInput(
                djId: primaryDJID,
                memberDjIds: memberDJIDs.contains(where: { $0 != nil }) ? memberDJIDs : nil,
                memberNames: performerNames,
                festivalDayIndex: max(slot.dayIndex, 1),
                djName: name,
                stageName: slot.stageName.trimmed.eventUploadMapperNilIfBlank ?? defaultStageName(at: 0),
                sortOrder: index + 1,
                startTime: slot.startTime,
                endTime: normalizedLineupEndTime(start: slot.startTime, end: slot.endTime)
            )
        }
        return timetableSlots.isEmpty ? nil : timetableSlots
    }

    private static func normalizedLineupEndTime(start: Date?, end: Date?) -> Date? {
        guard let start, let end else { return end }
        if end > start { return end }
        return Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var eventUploadMapperNilIfBlank: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
