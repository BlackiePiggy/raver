import Foundation
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
            sourceEventUrl: legacy.sourceEventUrl,
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
            status: mutationStatus(from: legacy.status)
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
            sourceEventUrl: legacy.sourceEventUrl,
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
            status: mutationStatus(from: legacy.status)
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
        return .init(
            provider: legacy.provider ?? "",
            sourceMode: legacy.sourceMode ?? "",
            providerPlaceId: legacy.providerPlaceId,
            poiId: legacy.poiId,
            location: .init(lng: location.lng, lat: location.lat),
            nameI18n: localizedText(from: legacy.nameI18n),
            addressI18n: localizedText(from: legacy.addressI18n),
            formattedAddressI18n: localizedText(from: legacy.formattedAddressI18n),
            city: legacy.city,
            district: legacy.district,
            province: legacy.province,
            countryCode: legacy.countryCode
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
                startTime: $0.startTime?.iso8601FractionalString,
                endTime: $0.endTime?.iso8601FractionalString
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

    private static func mutationStatus(
        from legacy: String?
    ) -> EventAdminComponents.Schemas.EventMutationBase.StatusPayload? {
        guard let rawValue = legacy?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }
        return .init(rawValue: rawValue)
    }
}

private extension Date {
    var iso8601FractionalString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}
