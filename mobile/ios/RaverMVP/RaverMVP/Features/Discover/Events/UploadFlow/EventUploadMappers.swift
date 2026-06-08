import Foundation
import OpenAPIRuntime
import RaverEventAdminContract

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
        firstRemoteURL(in: .poster, draft: draft) ?? firstRemoteURL(in: .cover, draft: draft)
    }

    static func primaryLineupURL(from draft: EventUploadDraft) -> String? {
        firstRemoteURL(in: .lineup, draft: draft)
    }

    static func createInput(
        from draft: EventUploadDraft,
        lineupSyncMode: EventLineupSyncMode = .incrementalFill
    ) -> EventAdminCreateInput {
        let parsedSocialLinks = socialLinksPayload(from: draft.socialLinksText)
        return .init(
            value1: mutationBase(
                from: draft,
                lineupSyncMode: lineupSyncMode,
                includeTimeZoneSelectionMetadata: true,
                parsedSocialLinks: parsedSocialLinks
            )
        )
    }

    static func updateInput(
        from draft: EventUploadDraft,
        lineupSyncMode: EventLineupSyncMode = .incrementalFill
    ) -> EventAdminUpdateInput {
        let parsedSocialLinks = socialLinksPayload(from: draft.socialLinksText)
        let base = mutationBase(
            from: draft,
            lineupSyncMode: lineupSyncMode,
            includeTimeZoneSelectionMetadata: draft.selectedTimeZoneLookup?.matchSource != "event-edit-hydrate",
            parsedSocialLinks: parsedSocialLinks
        )
        return .init(
            value1: base,
            value2: .init(
                clearCityI18n: draft.clearCityI18nIntent,
                clearCountryI18n: draft.clearCountryI18nIntent,
                clearWikiFestivalId: base.wikiFestivalId == nil,
                clearManualLocation: base.manualLocation == nil,
                clearLocationPoint: base.locationPoint == nil,
                clearLatitude: base.latitude == nil,
                clearLongitude: base.longitude == nil,
                clearSocialLinks: shouldClearSocialLinks(parsedSocialLinks),
                clearStageOrder: base.stageOrder == nil,
                clearLineupSlots: base.lineupSlots == nil
            )
        )
    }

    static func imageOnlyUpdateInput(from draft: EventUploadDraft) -> EventAdminUpdateInput {
        updateInput(from: draft)
    }

    private static func mutationBase(
        from draft: EventUploadDraft,
        lineupSyncMode: EventLineupSyncMode,
        includeTimeZoneSelectionMetadata: Bool,
        parsedSocialLinks: ParsedOpenAPIValue = .omitted
    ) -> EventAdminComponents.Schemas.EventMutationBase {
        let language = draft.preferredLanguage
        let name = draft.name.primaryValue(preferredLanguage: language).trimmed
        let description = draft.description.trimmed.eventUploadMapperNilIfBlank
        let city = canonicalLocationText(from: draft.city)?.trimmed.eventUploadMapperNilIfBlank
        let country = canonicalLocationText(from: draft.country, preferEnglishFull: true)?.trimmed.eventUploadMapperNilIfBlank
        let cityI18n = draft.clearCityI18nIntent ? nil : localizedText(from: draft.city, language: language)
        let countryI18n = draft.clearCountryI18nIntent ? nil : localizedText(from: draft.country, language: language)
        let address = draft.detailAddress.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let addressI18n = localizedText(from: draft.detailAddress, language: language)
        let timeZone = draft.timeZoneIdentifier.trimmed.eventUploadMapperNilIfBlank ?? "Asia/Shanghai"
        let ticketTiers = ticketTierInputs(from: draft.ticket)
        let generatedImageAssets = adminImageAssets(from: imageAssets(from: draft))
        let resolvedTimeZone = TimeZone(identifier: timeZone) ?? TimeZone(identifier: "UTC") ?? .current

        return .init(
            name: name,
            nameI18n: adminLocalizedText(from: localizedText(from: draft.name, language: language)),
            wikiFestivalId: draft.organizerFestivalID?.trimmed.eventUploadMapperNilIfBlank,
            abbreviation: draft.abbreviation.trimmed.eventUploadMapperNilIfBlank,
            description: description,
            eventType: EventTypeOption.submissionValue(for: draft.eventType),
            organizerName: draft.organizerName.trimmed.eventUploadMapperNilIfBlank,
            sourceEventUrl: draft.sourceURL.trimmed.eventUploadMapperNilIfBlank,
            sourceProvider: draft.sourceProvider.trimmed.eventUploadMapperNilIfBlank,
            referenceLinks: referenceLinks(from: draft.referenceLinksText),
            socialLinks: socialLinksValue(from: parsedSocialLinks),
            city: city,
            cityI18n: adminLocalizedText(from: cityI18n),
            country: country,
            countryI18n: adminLocalizedText(from: countryI18n),
            manualLocation: adminManualLocation(
                from: manualLocation(
                    address: address,
                    addressI18n: addressI18n,
                    cityI18n: cityI18n,
                    countryI18n: countryI18n,
                    language: language
                )
            ),
            locationPoint: adminLocationPoint(
                from: locationPoint(
                    from: draft,
                    address: address,
                    addressI18n: addressI18n,
                    city: city,
                    cityI18n: cityI18n,
                    country: country,
                    countryI18n: countryI18n
                )
            ),
            latitude: draft.latitude,
            longitude: draft.longitude,
            ticketUrl: draft.ticket.ticketURL.trimmed.eventUploadMapperNilIfBlank,
            ticketCurrency: draft.ticket.currency.trimmed.uppercased().eventUploadMapperNilIfBlank,
            ticketNotes: draft.ticketNotes.trimmed.eventUploadMapperNilIfBlank,
            officialWebsite: draft.officialWebsite.trimmed.eventUploadMapperNilIfBlank,
            startDate: draft.startDate.eventArchiveDateText(in: resolvedTimeZone),
            endDate: draft.endDate.eventArchiveDateText(in: resolvedTimeZone),
            schedule: adminSchedule(from: draft.structuredSchedule),
            weeks: adminWeeks(from: draft.structuredWeeks, timeZone: resolvedTimeZone),
            eventDays: adminEventDays(from: draft.structuredEventDays, timeZone: resolvedTimeZone),
            timeZone: timeZone,
            timeZoneCity: includeTimeZoneSelectionMetadata ? draft.selectedTimeZoneLookup?.city : nil,
            timeZoneProvince: includeTimeZoneSelectionMetadata ? (draft.selectedTimeZoneLookup?.exactProvince.eventUploadMapperNilIfBlank ?? draft.selectedTimeZoneLookup?.province.eventUploadMapperNilIfBlank) : nil,
            timeZoneCountry: includeTimeZoneSelectionMetadata ? draft.selectedTimeZoneLookup?.country : nil,
            timeZoneStateAnsi: includeTimeZoneSelectionMetadata ? draft.selectedTimeZoneLookup?.stateAnsi.eventUploadMapperNilIfBlank : nil,
            timeZoneLat: includeTimeZoneSelectionMetadata ? draft.selectedTimeZoneLookup?.lat : nil,
            timeZoneLng: includeTimeZoneSelectionMetadata ? draft.selectedTimeZoneLookup?.lng : nil,
            startTime: nil,
            endTime: nil,
            dayRolloverHour: draft.dayRolloverHour,
            stageOrder: normalizedStages(from: draft),
            coverImageUrl: primaryCoverURL(from: draft),
            lineupImageUrl: primaryLineupURL(from: draft),
            imageAssets: generatedImageAssets,
            ticketTiers: adminTicketTiers(from: ticketTiers),
            lineupArtists: adminLineupArtists(from: lineupArtistInputs(from: draft)),
            lineupSlots: adminLineupSlots(from: lineupSlotInputs(from: draft), timeZone: resolvedTimeZone),
            lineupSyncMode: .init(rawValue: lineupSyncMode.rawValue),
            idempotencyKey: nil,
            isCancelled: false,
            visibility: .init(rawValue: "visible")
        )
    }

    private static func firstRemoteURL(in zone: EventUploadImageZone, draft: EventUploadDraft) -> String? {
        (draft.imageZones[zone] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { $0.remoteURL?.trimmed.eventUploadMapperNilIfBlank }
            .first
    }

    private static func referenceLinks(from rawValue: String) -> [String] {
        let links = rawValue
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return links
    }

    private enum ParsedOpenAPIValue {
        case omitted
        case value(OpenAPIValueContainer)
        case invalid
    }

    private static func socialLinksPayload(from rawValue: String) -> ParsedOpenAPIValue {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .omitted }
        guard let data = trimmed.data(using: .utf8),
              let value = try? JSONDecoder().decode(OpenAPIValueContainer.self, from: data) else {
            return .invalid
        }
        return .value(value)
    }

    private static func socialLinksValue(from parsed: ParsedOpenAPIValue) -> OpenAPIValueContainer? {
        switch parsed {
        case .value(let value):
            return value
        case .omitted, .invalid:
            return nil
        }
    }

    private static func shouldClearSocialLinks(_ parsed: ParsedOpenAPIValue) -> Bool {
        switch parsed {
        case .omitted:
            return true
        case .value, .invalid:
            return false
        }
    }

    private static func localizedText(from fields: EventUploadLocalizedFields, language: EventUploadPreferredLanguage) -> WebBiText? {
        let en = fields.en.trimmed
        let zh = fields.zh.trimmed
        let ja = fields.ja.trimmed.eventUploadMapperNilIfBlank
        let enFull = fields.enFull.trimmed.eventUploadMapperNilIfBlank
        guard !en.isEmpty || !zh.isEmpty || ja != nil || enFull != nil else {
            let primary = fields.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
            return primary.map { localizedSingleText($0, language: language) }
        }
        let text = WebBiText(
            en: en,
            zh: zh,
            ja: ja,
            enFull: enFull
        )
        return text
    }

    private static func canonicalLocationText(
        from fields: EventUploadLocalizedFields,
        preferEnglishFull: Bool = false
    ) -> String? {
        let en = fields.en.trimmed.eventUploadMapperNilIfBlank
        let zh = fields.zh.trimmed.eventUploadMapperNilIfBlank
        let ja = fields.ja.trimmed.eventUploadMapperNilIfBlank
        let enFull = fields.enFull.trimmed.eventUploadMapperNilIfBlank
        if preferEnglishFull {
            return en ?? enFull ?? zh ?? ja
        }
        return en ?? zh ?? ja ?? enFull
    }

    private static func manualLocation(
        address: String?,
        addressI18n: WebBiText?,
        cityI18n: WebBiText?,
        countryI18n: WebBiText?,
        language: EventUploadPreferredLanguage
    ) -> WebEventManualLocation? {
        let localized = addressI18n.flatMap(normalizedLocalizedAddress)
        let fallback = address
            .map { $0.trimmed }
            .flatMap { $0.eventUploadMapperNilIfBlank }
            .map { localizedSingleText($0, language: language) }
        guard let text = localized ?? fallback else { return nil }
        let formatted = formattedAddress(
            detailAddressI18n: text,
            cityI18n: cityI18n,
            countryI18n: countryI18n
        )
        return WebEventManualLocation(
            detailAddressI18n: text,
            formattedAddressI18n: formatted,
            selectedAt: Date()
        )
    }

    private static func normalizedLocalizedAddress(_ text: WebBiText) -> WebBiText? {
        let normalized = WebBiText(
            en: text.en.trimmed,
            zh: text.zh.trimmed,
            ja: text.ja?.trimmed.eventUploadMapperNilIfBlank,
            enFull: text.enFull?.trimmed.eventUploadMapperNilIfBlank
        )
        let hasValue = !normalized.en.isEmpty
            || !normalized.zh.isEmpty
            || normalized.ja != nil
            || normalized.enFull != nil
        return hasValue ? normalized : nil
    }

    private static func locationPoint(
        from draft: EventUploadDraft,
        address: String?,
        addressI18n: WebBiText?,
        city: String?,
        cityI18n: WebBiText?,
        country: String?,
        countryI18n: WebBiText?
    ) -> WebEventLocationPoint? {
        guard let latitude = draft.latitude,
              let longitude = draft.longitude else {
            return nil
        }
        var next = normalizedLocationPointForMutation(from: draft.locationPoint)
            ?? fallbackLocationPoint(
                from: draft,
                latitude: latitude,
                longitude: longitude
            )
            ?? WebEventLocationPoint(
                provider: "mapkit",
                sourceMode: "pin_drag",
                providerPlaceId: nil,
                poiId: nil,
                adcode: nil,
                location: WebEventLocationCoordinate(lng: longitude, lat: latitude),
                nameI18n: nil,
                addressI18n: nil,
                formattedAddressI18n: nil,
                manualSetAddressI18n: nil,
                city: nil,
                district: nil,
                province: nil,
                countryCode: nil,
                providerMeta: nil
            )
        next.location = WebEventLocationCoordinate(lng: longitude, lat: latitude)

        if let mapAddress = draft.pickedMapAddress.trimmed.eventUploadMapperNilIfBlank {
            let preservedAddress = next.addressI18n.flatMap(normalizedLocalizedAddress)
            let preservedFormatted = next.formattedAddressI18n.flatMap(normalizedLocalizedAddress)
            let localizedMapAddress = localizedSingleText(mapAddress, language: draft.preferredLanguage)
            next.addressI18n = preservedAddress ?? localizedMapAddress
            next.formattedAddressI18n = preservedFormatted ?? localizedMapAddress
        } else if let localizedAddress = addressI18n.flatMap(normalizedLocalizedAddress) {
            next.addressI18n = localizedAddress
            next.formattedAddressI18n = formattedAddress(
                detailAddressI18n: localizedAddress,
                cityI18n: cityI18n ?? city.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                },
                countryI18n: countryI18n ?? country.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                }
            )
        } else if let fallbackAddress = address?
            .trimmed
            .eventUploadMapperNilIfBlank
            .map({ localizedSingleText($0, language: draft.preferredLanguage) }) {
            next.addressI18n = fallbackAddress
            next.formattedAddressI18n = formattedAddress(
                detailAddressI18n: fallbackAddress,
                cityI18n: cityI18n ?? city.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                },
                countryI18n: countryI18n ?? country.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                }
            )
        }
        let manualSetAddressI18n =
            normalizedLocalizedAddress(
                WebBiText(
                    en: draft.manualSetAddress.en,
                    zh: draft.manualSetAddress.zh,
                    ja: draft.manualSetAddress.ja,
                    enFull: draft.manualSetAddress.enFull
                )
            )
        if let manualSetAddressI18n {
            next.manualSetAddressI18n = formattedAddress(
                detailAddressI18n: manualSetAddressI18n,
                cityI18n: cityI18n ?? city.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                },
                countryI18n: countryI18n ?? country.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                }
            )
        } else {
            next.manualSetAddressI18n = nil
        }

        if let placeName = draft.pickedPlaceName.trimmed.eventUploadMapperNilIfBlank {
            next.nameI18n = localizedSingleText(placeName, language: draft.preferredLanguage)
        }

        if let city = city?.trimmed.eventUploadMapperNilIfBlank {
            next.city = city
        }

        return next
    }

    private static func fallbackLocationPoint(
        from draft: EventUploadDraft,
        latitude: Double,
        longitude: Double
    ) -> WebEventLocationPoint? {
        let mapAddress = draft.pickedMapAddress.trimmed.eventUploadMapperNilIfBlank
        let placeName = draft.pickedPlaceName.trimmed.eventUploadMapperNilIfBlank
        guard mapAddress != nil || placeName != nil else {
            return nil
        }

        return WebEventLocationPoint(
            provider: "mapkit",
            sourceMode: "pin_drag",
            providerPlaceId: nil,
            poiId: nil,
            adcode: nil,
            location: WebEventLocationCoordinate(lng: longitude, lat: latitude),
            nameI18n: placeName.map { localizedSingleText($0, language: draft.preferredLanguage) },
            addressI18n: mapAddress.map { localizedSingleText($0, language: draft.preferredLanguage) },
            formattedAddressI18n: mapAddress.map { localizedSingleText($0, language: draft.preferredLanguage) },
            manualSetAddressI18n: nil,
            city: nil,
            district: nil,
            province: nil,
            countryCode: nil,
            providerMeta: nil
        )
    }

    private static func formattedAddress(
        detailAddressI18n: WebBiText,
        cityI18n: WebBiText?,
        countryI18n: WebBiText?
    ) -> WebBiText {
        let detail = normalizedLocalizedAddress(detailAddressI18n) ?? detailAddressI18n
        let city = cityI18n.flatMap(normalizedLocalizedAddress)
        let country = countryI18n.flatMap(normalizedLocalizedAddress)

        let formattedZh = joinAddressComponents([
            country?.zh.trimmed.eventUploadMapperNilIfBlank
                ?? country?.en.trimmed.eventUploadMapperNilIfBlank,
            city?.zh.trimmed.eventUploadMapperNilIfBlank
                ?? city?.en.trimmed.eventUploadMapperNilIfBlank,
            detail.zh.trimmed.eventUploadMapperNilIfBlank
                ?? detail.en.trimmed.eventUploadMapperNilIfBlank,
        ])
        let formattedEn = joinAddressComponents([
            country?.enFull?.trimmed.eventUploadMapperNilIfBlank
                ?? country?.en.trimmed.eventUploadMapperNilIfBlank
                ?? country?.zh.trimmed.eventUploadMapperNilIfBlank,
            city?.en.trimmed.eventUploadMapperNilIfBlank
                ?? city?.zh.trimmed.eventUploadMapperNilIfBlank,
            detail.en.trimmed.eventUploadMapperNilIfBlank
                ?? detail.zh.trimmed.eventUploadMapperNilIfBlank,
        ])
        let formattedJa = joinAddressComponents([
            country?.ja?.trimmed.eventUploadMapperNilIfBlank
                ?? country?.enFull?.trimmed.eventUploadMapperNilIfBlank
                ?? country?.en.trimmed.eventUploadMapperNilIfBlank
                ?? country?.zh.trimmed.eventUploadMapperNilIfBlank,
            city?.ja?.trimmed.eventUploadMapperNilIfBlank
                ?? city?.en.trimmed.eventUploadMapperNilIfBlank
                ?? city?.zh.trimmed.eventUploadMapperNilIfBlank,
            detail.ja?.trimmed.eventUploadMapperNilIfBlank
                ?? detail.en.trimmed.eventUploadMapperNilIfBlank
                ?? detail.zh.trimmed.eventUploadMapperNilIfBlank,
        ])

        return WebBiText(
            en: formattedEn ?? detail.en,
            zh: formattedZh ?? detail.zh,
            ja: formattedJa ?? detail.ja,
            enFull: detail.enFull
        )
    }

    private static func joinAddressComponents(_ parts: [String?]) -> String? {
        let values = parts.compactMap { $0?.trimmed.eventUploadMapperNilIfBlank }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    private static func localizedSingleText(_ value: String, language: EventUploadPreferredLanguage) -> WebBiText {
        switch language {
        case .zh:
            return WebBiText(en: "", zh: value)
        case .en:
            return WebBiText(en: value, zh: "")
        case .ja:
            return WebBiText(en: "", zh: "", ja: value)
        }
    }

    private static func normalizedStages(from draft: EventUploadDraft) -> [String]? {
        let values = draft.stageEntries
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }

    private static func defaultStageName(stageOrder: [String]?) -> String {
        stageOrder?.first?.trimmed.eventUploadMapperNilIfBlank ?? "Main Stage"
    }

    private static func ticketTierInputs(from ticket: EventUploadTicketDraft) -> [EventTicketTierInput]? {
        let normalizedCurrency = ticket.currency.trimmed.uppercased().eventUploadMapperNilIfBlank
        let tiers = ticket.tiers.enumerated().compactMap { index, tier -> EventTicketTierInput? in
            guard let price = Double(tier.price.trimmed) else { return nil }
            return EventTicketTierInput(
                name: tier.name.trimmed.eventUploadMapperNilIfBlank ?? LT("票档 \(index + 1)", "Tier \(index + 1)", "券種 \(index + 1)"),
                price: price,
                currency: normalizedCurrency,
                sortOrder: index + 1
            )
        }
        return tiers.isEmpty ? nil : tiers
    }

    static func lineupArtistInputs(from draft: EventUploadDraft) -> [EventLineupArtistInput]? {
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
                id: slot.canonicalArtistId,
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
        let normalizedStageOrder = normalizedStages(from: draft)
        var lineupArtistIDByKey: [String: String] = [:]
        for artist in lineupArtistInputs(from: draft) ?? [] {
            guard let id = artist.id?.trimmed.eventUploadMapperNilIfBlank else { continue }
            let key = artistIdentityKey(artist)
            lineupArtistIDByKey[key] = lineupArtistIDByKey[key] ?? id
        }
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
            let eventDay = resolvedEventDay(for: slot, in: draft)
            let baseInput = EventLineupSlotInput(
                id: slot.canonicalSlotId,
                lineupArtistId: nil,
                eventDayId: eventDay?.eventDayId ?? slot.eventDayId,
                weekIndex: eventDay?.weekIndex ?? slot.weekIndex,
                dayIndexInWeek: eventDay?.dayIndexInWeek ?? slot.dayIndexInWeek,
                overallDayIndex: eventDay?.overallDayIndex ?? slot.overallDayIndex,
                localDate: eventDay?.date ?? slot.localDate,
                djId: primaryDJID,
                memberDjIds: memberDJIDs.contains(where: { $0 != nil }) ? memberDJIDs : nil,
                memberNames: performerNames,
                festivalDayIndex: nil,
                djName: name,
                stageName: slot.stageName.trimmed.eventUploadMapperNilIfBlank ?? defaultStageName(stageOrder: normalizedStageOrder),
                sortOrder: index + 1,
                startTime: slot.startTime,
                endTime: normalizedLineupEndTime(start: slot.startTime, end: slot.endTime)
            )
            var input = baseInput
            input.lineupArtistId = lineupArtistIDByKey[artistIdentityKey(baseInput)]
            return input
        }
        return timetableSlots.isEmpty ? nil : timetableSlots
    }

    private static func resolvedEventDay(
        for slot: EventUploadLineupSlotDraft,
        in draft: EventUploadDraft
    ) -> WebEventDay? {
        if let eventDay = draft.eventDay(forID: slot.eventDayId) {
            return eventDay
        }
        if let eventDay = draft.eventDay(forOverallDayIndex: max(slot.dayIndex, slot.overallDayIndex, 1)) {
            return eventDay
        }
        return draft.structuredEventDays.first
    }

    private static func artistIdentityKey(_ artist: EventLineupArtistInput) -> String {
        if let djId = artist.djId?.trimmed.eventUploadMapperNilIfBlank {
            return "dj:\(djId)"
        }
        let memberIDs = (artist.memberDjIds ?? []).compactMap { $0?.trimmed.eventUploadMapperNilIfBlank }.sorted()
        if !memberIDs.isEmpty {
            return "members:\(memberIDs.joined(separator: "|"))"
        }
        let memberNames = (artist.memberNames ?? []).map { $0.trimmed.lowercased() }.filter { !$0.isEmpty }.sorted()
        if !memberNames.isEmpty {
            return "names:\(memberNames.joined(separator: "|"))"
        }
        return "name:\(artist.djName.trimmed.lowercased())"
    }

    private static func artistIdentityKey(_ slot: EventLineupSlotInput) -> String {
        artistIdentityKey(EventLineupArtistInput(
            djId: slot.djId,
            memberDjIds: slot.memberDjIds,
            memberNames: slot.memberNames,
            djName: slot.djName,
            sortOrder: slot.sortOrder
        ))
    }

    private static func normalizedLineupEndTime(start: Date?, end: Date?) -> Date? {
        guard let start, let end else { return end }
        if end > start { return end }
        return Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
    }

    private static func adminLocalizedText(from text: WebBiText?) -> EventAdminLocalizedText? {
        guard let text else { return nil }
        return .init(
            en: text.en,
            zh: text.zh,
            ja: text.ja,
            enFull: text.enFull
        )
    }

    private static func adminManualLocation(
        from location: WebEventManualLocation?
    ) -> EventAdminComponents.Schemas.EventManualLocation? {
        guard let location else { return nil }
        return .init(
            detailAddressI18n: adminLocalizedText(from: location.detailAddressI18n) ?? .init(en: "", zh: ""),
            formattedAddressI18n: adminLocalizedText(from: location.formattedAddressI18n) ?? .init(en: "", zh: ""),
            selectedAt: location.selectedAt ?? Date()
        )
    }

    private static func adminLocationPoint(
        from point: WebEventLocationPoint?
    ) -> EventAdminComponents.Schemas.EventLocationPoint? {
        guard let point, let location = point.location else { return nil }
        let provider = normalizedLocationProvider(from: point.provider) ?? .mapkit
        let sourceMode = normalizedLocationSourceMode(from: point.sourceMode) ?? .pinDrag
        return .init(
            provider: provider,
            sourceMode: sourceMode,
            providerPlaceId: point.providerPlaceId,
            poiId: point.poiId,
            adcode: point.adcode,
            location: .init(lng: location.lng, lat: location.lat),
            nameI18n: adminLocalizedText(from: point.nameI18n),
            addressI18n: adminLocalizedText(from: point.addressI18n),
            formattedAddressI18n: adminLocalizedText(from: point.formattedAddressI18n),
            manualSetAddressI18n: adminLocalizedText(from: point.manualSetAddressI18n),
            city: point.city,
            district: point.district,
            province: point.province,
            countryCode: point.countryCode,
            providerMeta: adminLocationProviderMeta(from: point.providerMeta)
        )
    }

    private static func adminSchedule(
        from schedule: WebEventSchedule
    ) -> EventAdminComponents.Schemas.EventSchedule? {
        guard let mode = EventAdminComponents.Schemas.EventScheduleMode(rawValue: schedule.mode) else {
            return nil
        }
        return .init(
            mode: mode,
            timeZone: schedule.timeZone,
            dayRolloverHour: schedule.dayRolloverHour
        )
    }

    private static func adminWeeks(
        from weeks: [WebEventWeek],
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventWeek]? {
        guard !weeks.isEmpty else { return nil }
        return weeks.map {
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

    private static func adminEventDays(
        from eventDays: [WebEventDay],
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventDay]? {
        guard !eventDays.isEmpty else { return nil }
        return eventDays.map {
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

    private static func adminImageAssets(
        from assets: [WebEventImageAsset]
    ) -> [EventAdminComponents.Schemas.EventImageAsset]? {
        guard !assets.isEmpty else { return nil }
        return assets.map {
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

    private static func adminTicketTiers(
        from tiers: [EventTicketTierInput]?
    ) -> [EventAdminComponents.Schemas.EventTicketTierInput]? {
        tiers?.map {
            .init(
                name: $0.name,
                price: $0.price,
                currency: $0.currency,
                sortOrder: $0.sortOrder
            )
        }
    }

    private static func adminLineupArtists(
        from artists: [EventLineupArtistInput]?
    ) -> [EventAdminComponents.Schemas.EventLineupArtistInput]? {
        artists?.map {
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

    private static func adminLineupSlots(
        from slots: [EventLineupSlotInput]?,
        timeZone: TimeZone
    ) -> [EventAdminComponents.Schemas.EventLineupSlotInput]? {
        slots?.map {
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

    private static func adminLocationProviderMeta(
        from meta: WebEventLocationProviderMeta?
    ) -> EventAdminComponents.Schemas.EventLocationPoint.ProviderMetaPayload? {
        guard let meta else { return nil }
        let hasValue = meta.amap != nil
            || meta.google != nil
            || meta.mapkit != nil
            || meta.mapbox != nil
            || meta.geoapify != nil
        guard hasValue else { return nil }
        guard let data = try? JSONEncoder().encode(meta) else { return nil }
        return try? JSONDecoder().decode(
            EventAdminComponents.Schemas.EventLocationPoint.ProviderMetaPayload.self,
            from: data
        )
    }

    private static func normalizedLocationPointForMutation(
        from point: WebEventLocationPoint?
    ) -> WebEventLocationPoint? {
        guard var point else { return nil }
        let provider = point.provider?.trimmed.eventUploadMapperNilIfBlank
        let sourceMode = point.sourceMode?.trimmed.eventUploadMapperNilIfBlank
        let providerPlaceId = point.providerPlaceId?.trimmed.eventUploadMapperNilIfBlank
        let poiId = point.poiId?.trimmed.eventUploadMapperNilIfBlank
        let adcode = point.adcode?.trimmed.eventUploadMapperNilIfBlank
        let nameI18n = point.nameI18n.flatMap(normalizedLocalizedAddress)
        let addressI18n = point.addressI18n.flatMap(normalizedLocalizedAddress)
        let formattedAddressI18n = point.formattedAddressI18n.flatMap(normalizedLocalizedAddress)
        let manualSetAddressI18n = point.manualSetAddressI18n.flatMap(normalizedLocalizedAddress)
        let city = point.city?.trimmed.eventUploadMapperNilIfBlank
        let district = point.district?.trimmed.eventUploadMapperNilIfBlank
        let province = point.province?.trimmed.eventUploadMapperNilIfBlank
        let countryCode = point.countryCode?.trimmed.eventUploadMapperNilIfBlank
        let providerMeta = normalizedProviderMeta(point.providerMeta)
        let hasUsefulPayload = point.location != nil
            || provider != nil
            || sourceMode != nil
            || providerPlaceId != nil
            || poiId != nil
            || adcode != nil
            || nameI18n != nil
            || addressI18n != nil
            || formattedAddressI18n != nil
            || manualSetAddressI18n != nil
            || city != nil
            || district != nil
            || province != nil
            || countryCode != nil
            || providerMeta != nil
        guard hasUsefulPayload else { return nil }

        point.provider = provider
        point.sourceMode = sourceMode
        point.providerPlaceId = providerPlaceId
        point.poiId = poiId
        point.adcode = adcode
        point.nameI18n = nameI18n
        point.addressI18n = addressI18n
        point.formattedAddressI18n = formattedAddressI18n
        point.manualSetAddressI18n = manualSetAddressI18n
        point.city = city
        point.district = district
        point.province = province
        point.countryCode = countryCode
        point.providerMeta = providerMeta
        return point
    }

    private static func normalizedProviderMeta(
        _ meta: WebEventLocationProviderMeta?
    ) -> WebEventLocationProviderMeta? {
        guard let meta else { return nil }
        let normalized = WebEventLocationProviderMeta(
            amap: {
                let poiId = meta.amap?.poiId?.trimmed.eventUploadMapperNilIfBlank
                let adcode = meta.amap?.adcode?.trimmed.eventUploadMapperNilIfBlank
                guard poiId != nil || adcode != nil else { return nil }
                return .init(poiId: poiId, adcode: adcode)
            }(),
            google: {
                let placeId = meta.google?.placeId?.trimmed.eventUploadMapperNilIfBlank
                let types = meta.google?.types?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard placeId != nil || (types?.isEmpty == false) else { return nil }
                return .init(placeId: placeId, types: types)
            }(),
            mapkit: {
                let mapItemIdentifier = meta.mapkit?.mapItemIdentifier?.trimmed.eventUploadMapperNilIfBlank
                guard mapItemIdentifier != nil else { return nil }
                return .init(mapItemIdentifier: mapItemIdentifier)
            }(),
            mapbox: {
                let placeId = meta.mapbox?.placeId?.trimmed.eventUploadMapperNilIfBlank
                let featureType = meta.mapbox?.featureType?.trimmed.eventUploadMapperNilIfBlank
                guard placeId != nil || featureType != nil else { return nil }
                return .init(placeId: placeId, featureType: featureType)
            }(),
            geoapify: {
                let placeId = meta.geoapify?.placeId?.trimmed.eventUploadMapperNilIfBlank
                let featureType = meta.geoapify?.featureType?.trimmed.eventUploadMapperNilIfBlank
                guard placeId != nil || featureType != nil else { return nil }
                return .init(placeId: placeId, featureType: featureType)
            }()
        )

        let hasValue = normalized.amap != nil
            || normalized.google != nil
            || normalized.mapkit != nil
            || normalized.mapbox != nil
            || normalized.geoapify != nil
        return hasValue ? normalized : nil
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
