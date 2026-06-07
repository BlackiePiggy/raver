import Foundation
import OpenAPIRuntime
import RaverEventAdminContract

typealias EventAdminCreateInput = EventAdminCreateEventInput
typealias EventAdminUpdateInput = EventAdminUpdateEventInput

enum EventAdminContractBridge {
    static func createInput(from legacy: CreateEventInput) -> EventAdminCreateInput {
        EventAdminCreateInput(value1: mutationBase(from: legacy))
    }

    static func updateInput(from legacy: UpdateEventInput) -> EventAdminUpdateInput {
        EventAdminUpdateInput(
            value1: mutationBase(from: legacy),
            value2: .init(
                clearCityI18n: legacy.clearCityI18n,
                clearCountryI18n: legacy.clearCountryI18n,
                clearWikiFestivalId: legacy.clearWikiFestivalId,
                clearManualLocation: legacy.clearManualLocation,
                clearLocationPoint: legacy.clearLocationPoint,
                clearLatitude: legacy.clearLatitude,
                clearLongitude: legacy.clearLongitude,
                clearSocialLinks: legacy.clearSocialLinks,
                clearStageOrder: legacy.clearStageOrder,
                clearLineupSlots: legacy.clearLineupSlots
            )
        )
    }

    private static func mutationBase(from legacy: CreateEventInput) -> EventAdminComponents.Schemas.EventMutationBase {
        let resolvedTimeZone = TimeZone(identifier: legacy.timeZone ?? "") ?? TimeZone(identifier: "UTC") ?? .current
        return .init(
            name: legacy.name,
            nameI18n: localizedText(from: legacy.nameI18n),
            wikiFestivalId: legacy.wikiFestivalId,
            abbreviation: legacy.abbreviation,
            description: legacy.description,
            eventType: legacy.eventType,
            organizerName: legacy.organizerName,
            venueName: legacy.venueName,
            venueAddress: legacy.venueAddress,
            sourceEventUrl: legacy.sourceEventUrl,
            sourceProvider: legacy.sourceProvider,
            referenceLinks: legacy.referenceLinks,
            socialLinks: legacy.socialLinks.map(adminJsonValue(from:)),
            city: legacy.city,
            cityI18n: localizedText(from: legacy.cityI18n),
            country: legacy.country,
            countryI18n: localizedText(from: legacy.countryI18n),
            manualLocation: manualLocation(from: legacy.manualLocation),
            locationPoint: locationPoint(from: legacy.locationPoint),
            latitude: legacy.latitude,
            longitude: legacy.longitude,
            ticketUrl: legacy.ticketUrl,
            ticketCurrency: legacy.ticketCurrency,
            ticketNotes: legacy.ticketNotes,
            officialWebsite: legacy.officialWebsite,
            startDate: legacy.startDate.eventArchiveDateText(in: resolvedTimeZone),
            endDate: legacy.endDate.eventArchiveDateText(in: resolvedTimeZone),
            schedule: schedule(from: legacy.schedule),
            weeks: weeks(from: legacy.weeks, timeZone: resolvedTimeZone),
            eventDays: eventDays(from: legacy.eventDays, timeZone: resolvedTimeZone),
            timeZone: legacy.timeZone,
            timeZoneCity: legacy.timeZoneCity,
            timeZoneProvince: legacy.timeZoneProvince,
            timeZoneCountry: legacy.timeZoneCountry,
            timeZoneStateAnsi: legacy.timeZoneStateAnsi,
            timeZoneLat: legacy.timeZoneLat,
            timeZoneLng: legacy.timeZoneLng,
            startTime: legacy.startTime,
            endTime: legacy.endTime,
            dayRolloverHour: legacy.dayRolloverHour,
            stageOrder: legacy.stageOrder,
            coverImageUrl: legacy.coverImageUrl,
            lineupImageUrl: legacy.lineupImageUrl,
            imageAssets: imageAssets(from: legacy.imageAssets),
            ticketTiers: ticketTiers(from: legacy.ticketTiers),
            lineupArtists: lineupArtists(from: legacy.lineupArtists),
            lineupSlots: lineupSlots(from: legacy.lineupSlots, timeZone: resolvedTimeZone),
            lineupSyncMode: lineupSyncMode(from: legacy.lineupSyncMode),
            idempotencyKey: legacy.idempotencyKey,
            isCancelled: legacy.isCancelled,
            visibility: normalizedVisibility(from: legacy.visibility)
        )
    }

    private static func mutationBase(from legacy: UpdateEventInput) -> EventAdminComponents.Schemas.EventMutationBase {
        let resolvedTimeZone = TimeZone(identifier: legacy.timeZone ?? "") ?? TimeZone(identifier: "UTC") ?? .current
        return .init(
            name: legacy.name ?? "",
            nameI18n: localizedText(from: legacy.nameI18n),
            wikiFestivalId: legacy.wikiFestivalId,
            abbreviation: legacy.abbreviation,
            description: legacy.description,
            eventType: legacy.eventType,
            organizerName: legacy.organizerName,
            venueName: legacy.venueName,
            venueAddress: legacy.venueAddress,
            sourceEventUrl: legacy.sourceEventUrl,
            sourceProvider: legacy.sourceProvider,
            referenceLinks: legacy.referenceLinks,
            socialLinks: legacy.socialLinks.map(adminJsonValue(from:)),
            city: legacy.city,
            cityI18n: localizedText(from: legacy.cityI18n),
            country: legacy.country,
            countryI18n: localizedText(from: legacy.countryI18n),
            manualLocation: manualLocation(from: legacy.manualLocation),
            locationPoint: locationPoint(from: legacy.locationPoint),
            latitude: legacy.latitude,
            longitude: legacy.longitude,
            ticketUrl: legacy.ticketUrl,
            ticketCurrency: legacy.ticketCurrency,
            ticketNotes: legacy.ticketNotes,
            officialWebsite: legacy.officialWebsite,
            startDate: (legacy.startDate ?? .distantPast).eventArchiveDateText(in: resolvedTimeZone),
            endDate: (legacy.endDate ?? legacy.startDate ?? .distantPast).eventArchiveDateText(in: resolvedTimeZone),
            schedule: schedule(from: legacy.schedule),
            weeks: weeks(from: legacy.weeks, timeZone: resolvedTimeZone),
            eventDays: eventDays(from: legacy.eventDays, timeZone: resolvedTimeZone),
            timeZone: legacy.timeZone,
            timeZoneCity: legacy.timeZoneCity,
            timeZoneProvince: legacy.timeZoneProvince,
            timeZoneCountry: legacy.timeZoneCountry,
            timeZoneStateAnsi: legacy.timeZoneStateAnsi,
            timeZoneLat: legacy.timeZoneLat,
            timeZoneLng: legacy.timeZoneLng,
            startTime: legacy.startTime,
            endTime: legacy.endTime,
            dayRolloverHour: legacy.dayRolloverHour,
            stageOrder: legacy.stageOrder,
            coverImageUrl: legacy.coverImageUrl,
            lineupImageUrl: legacy.lineupImageUrl,
            imageAssets: imageAssets(from: legacy.imageAssets),
            ticketTiers: ticketTiers(from: legacy.ticketTiers),
            lineupArtists: lineupArtists(from: legacy.lineupArtists),
            lineupSlots: lineupSlots(from: legacy.lineupSlots, timeZone: resolvedTimeZone),
            lineupSyncMode: lineupSyncMode(from: legacy.lineupSyncMode),
            idempotencyKey: legacy.idempotencyKey,
            isCancelled: legacy.isCancelled,
            visibility: normalizedVisibility(from: legacy.visibility)
        )
    }

    private static func localizedText(from legacy: WebBiText?) -> EventAdminLocalizedText? {
        guard let legacy else { return nil }
        return .init(
            en: legacy.en,
            zh: legacy.zh,
            ja: legacy.ja,
            enFull: legacy.enFull
        )
    }

    private static func manualLocation(from legacy: WebEventManualLocation?) -> EventAdminComponents.Schemas.EventManualLocation? {
        guard let legacy else { return nil }
        return .init(
            detailAddressI18n: localizedText(from: legacy.detailAddressI18n) ?? .init(en: "", zh: ""),
            formattedAddressI18n: localizedText(from: legacy.formattedAddressI18n) ?? .init(en: "", zh: ""),
            selectedAt: legacy.selectedAt ?? Date()
        )
    }

    private static func locationPoint(from legacy: WebEventLocationPoint?) -> EventAdminComponents.Schemas.EventLocationPoint? {
        guard let legacy, let location = legacy.location else { return nil }
        let provider = normalizedLocationProvider(from: legacy.provider) ?? .mapkit
        let sourceMode = normalizedLocationSourceMode(from: legacy.sourceMode) ?? .legacyCoords
        return .init(
            provider: provider,
            sourceMode: sourceMode,
            providerPlaceId: legacy.providerPlaceId,
            poiId: legacy.poiId,
            adcode: legacy.adcode,
            location: .init(lng: location.lng, lat: location.lat),
            nameI18n: localizedText(from: legacy.nameI18n),
            addressI18n: localizedText(from: legacy.addressI18n),
            formattedAddressI18n: localizedText(from: legacy.formattedAddressI18n),
            city: legacy.city,
            district: legacy.district,
            province: legacy.province,
            countryCode: legacy.countryCode,
            providerMeta: locationProviderMeta(from: legacy.providerMeta)
        )
    }

    private static func imageAssets(from legacy: [WebEventImageAsset]?) -> [EventAdminComponents.Schemas.EventImageAsset]? {
        legacy?.map {
            .init(
                url: $0.url,
                _type: $0.type,
                label: $0.label,
                sort: $0.sort,
                order: $0.order,
                source: $0.source,
                fileName: $0.fileName
            )
        }
    }

    private static func schedule(from legacy: WebEventSchedule?) -> EventAdminComponents.Schemas.EventSchedule? {
        guard let legacy else { return nil }
        guard let mode = EventAdminComponents.Schemas.EventScheduleMode(rawValue: legacy.mode) else {
            return nil
        }
        return .init(
            mode: mode,
            timeZone: legacy.timeZone,
            dayRolloverHour: legacy.dayRolloverHour
        )
    }

    private static func ticketTiers(from legacy: [EventTicketTierInput]?) -> [EventAdminComponents.Schemas.EventTicketTierInput]? {
        legacy?.map {
            .init(
                name: $0.name,
                price: $0.price,
                currency: $0.currency,
                sortOrder: $0.sortOrder
            )
        }
    }

    private static func lineupArtists(from legacy: [EventLineupArtistInput]?) -> [EventAdminComponents.Schemas.EventLineupArtistInput]? {
        legacy?.map {
            .init(
                id: $0.id,
                djId: $0.djId,
                memberDjIds: $0.memberDjIds,
                memberNames: $0.memberNames,
                djName: $0.djName,
                sortOrder: $0.sortOrder
            )
        }
    }

    private static func lineupSlots(
        from legacy: [EventLineupSlotInput]?,
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventLineupSlotInput]? {
        legacy?.map {
            .init(
                id: $0.id,
                lineupArtistId: $0.lineupArtistId,
                eventDayId: $0.eventDayId,
                weekIndex: $0.weekIndex,
                dayIndexInWeek: $0.dayIndexInWeek,
                overallDayIndex: $0.overallDayIndex,
                localDate: $0.localDate?.eventArchiveDateText(in: timeZone),
                djId: $0.djId,
                memberDjIds: $0.memberDjIds,
                memberNames: $0.memberNames,
                festivalDayIndex: $0.festivalDayIndex,
                djName: $0.djName,
                stageName: $0.stageName,
                sortOrder: $0.sortOrder,
                startTime: $0.startTime?.eventArchiveLocalDateTimeText(in: timeZone),
                endTime: $0.endTime?.eventArchiveLocalDateTimeText(in: timeZone)
            )
        }
    }

    private static func weeks(
        from legacy: [WebEventWeek]?,
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventWeek]? {
        legacy?.map {
            .init(
                id: $0.id,
                weekIndex: $0.weekIndex,
                label: $0.label,
                startDate: $0.startDate.eventArchiveDateText(in: timeZone),
                endDate: $0.endDate.eventArchiveDateText(in: timeZone),
                sortOrder: $0.sortOrder
            )
        }
    }

    private static func eventDays(
        from legacy: [WebEventDay]?,
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventDay]? {
        legacy?.map {
            .init(
                id: $0.id,
                eventDayId: $0.eventDayId,
                weekIndex: $0.weekIndex,
                dayIndexInWeek: $0.dayIndexInWeek,
                overallDayIndex: $0.overallDayIndex,
                label: $0.label,
                weekday: $0.weekday,
                date: $0.date.eventArchiveDateText(in: timeZone),
                sortOrder: $0.sortOrder
            )
        }
    }

    private static func lineupSyncMode(
        from legacy: EventLineupSyncMode?
    ) -> EventAdminComponents.Schemas.EventMutationBase.LineupSyncModePayload? {
        guard let rawValue = legacy?.rawValue else { return nil }
        return .init(rawValue: rawValue)
    }

    private static func normalizedVisibility(
        from explicitValue: String?
    ) -> EventAdminComponents.Schemas.EventMutationBase.VisibilityPayload? {
        guard let explicitValue else { return nil }
        let normalized = explicitValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "hidden" {
            return .init(rawValue: "hidden")
        }
        if normalized == "visible" {
            return .init(rawValue: "visible")
        }
        return nil
    }

    private static func normalizedLocationProvider(
        from rawValue: String?
    ) -> EventAdminComponents.Schemas.EventLocationProvider? {
        guard let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalized.isEmpty else {
            return nil
        }
        switch normalized {
        case "apple-mapkit", "apple_mapkit":
            return .mapkit
        default:
            return .init(rawValue: normalized)
        }
    }

    private static func normalizedLocationSourceMode(
        from rawValue: String?
    ) -> EventAdminComponents.Schemas.EventLocationSourceMode? {
        guard let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalized.isEmpty else {
            return nil
        }
        switch normalized {
        case "composed_search", "picker_search":
            return .manualSearch
        case "manual_pick", "manual_pin", "ios-event-upload-v2", "web-event-studio-v2":
            return .pinDrag
        case "server_normalized":
            return .legacyCoords
        default:
            return .init(rawValue: normalized)
        }
    }

    private static func locationProviderMeta(
        from legacy: WebEventLocationProviderMeta?
    ) -> EventAdminComponents.Schemas.EventLocationPoint.ProviderMetaPayload? {
        guard let legacy else { return nil }
        let hasValue = legacy.amap != nil
            || legacy.google != nil
            || legacy.mapkit != nil
            || legacy.mapbox != nil
            || legacy.geoapify != nil
        guard hasValue else { return nil }
        guard let data = try? JSONEncoder().encode(legacy) else { return nil }
        return try? JSONDecoder().decode(
            EventAdminComponents.Schemas.EventLocationPoint.ProviderMetaPayload.self,
            from: data
        )
    }

    private static func adminJsonValue(from value: ContentSubmissionJSONValue) -> OpenAPIValueContainer {
        switch value {
        case .string(let text):
            return OpenAPIValueContainer(stringLiteral: text)
        case .number(let number):
            return OpenAPIValueContainer(floatLiteral: number)
        case .bool(let flag):
            return OpenAPIValueContainer(booleanLiteral: flag)
        case .object(let object):
            return (try? OpenAPIValueContainer(unvalidatedValue: object.mapValues(jsonSendableValue(from:)))) ?? nil
        case .array(let array):
            return (try? OpenAPIValueContainer(unvalidatedValue: array.map(jsonSendableValue(from:)))) ?? nil
        case .null:
            return nil
        }
    }

    private static func jsonSendableValue(from value: ContentSubmissionJSONValue) -> (any Sendable)? {
        switch value {
        case .string(let text):
            return text
        case .number(let number):
            return number
        case .bool(let flag):
            return flag
        case .object(let object):
            return object.mapValues(jsonSendableValue(from:))
        case .array(let array):
            return array.map(jsonSendableValue(from:))
        case .null:
            return nil
        }
    }
}
