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
        firstRemoteURL(in: .poster, draft: draft) ?? firstRemoteURL(in: .cover, draft: draft)
    }

    static func primaryLineupURL(from draft: EventUploadDraft) -> String? {
        firstRemoteURL(in: .lineup, draft: draft)
    }

    static func createInput(
        from draft: EventUploadDraft,
        lineupSyncMode: EventLineupSyncMode = .incrementalFill
    ) -> CreateEventInput {
        let language = draft.preferredLanguage
        let name = draft.name.primaryValue(preferredLanguage: language).trimmed
        let city = draft.city.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let country = draft.country.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let cityI18n = localizedText(from: draft.city, language: language)
        let countryI18n = localizedText(from: draft.country, language: language)
        let address = draft.detailAddress.primaryValue(preferredLanguage: language).trimmed.eventUploadMapperNilIfBlank
        let addressI18n = localizedText(from: draft.detailAddress, language: language)
        let timeZone = draft.timeZoneIdentifier.trimmed.eventUploadMapperNilIfBlank ?? "Asia/Shanghai"
        let ticketTiers = ticketTierInputs(from: draft.ticket)

        return CreateEventInput(
            name: name,
            nameI18n: localizedText(from: draft.name, language: language),
            wikiFestivalId: draft.organizerFestivalID?.trimmed.eventUploadMapperNilIfBlank,
            abbreviation: draft.abbreviation.trimmed.eventUploadMapperNilIfBlank,
            description: nil,
            eventType: EventTypeOption.submissionValue(for: draft.eventType),
            organizerName: draft.organizerName.trimmed.eventUploadMapperNilIfBlank,
            sourceEventUrl: draft.sourceURL.trimmed.eventUploadMapperNilIfBlank,
            city: city,
            cityI18n: cityI18n,
            country: country,
            countryI18n: countryI18n,
            manualLocation: manualLocation(
                address: address,
                addressI18n: addressI18n,
                cityI18n: cityI18n,
                countryI18n: countryI18n,
                language: language
            ),
            locationPoint: locationPoint(
                from: draft,
                address: address,
                addressI18n: addressI18n,
                city: city,
                cityI18n: cityI18n,
                country: country,
                countryI18n: countryI18n
            ),
            latitude: draft.latitude,
            longitude: draft.longitude,
            ticketUrl: draft.ticket.ticketURL.trimmed.eventUploadMapperNilIfBlank,
            ticketCurrency: draft.ticket.currency.trimmed.uppercased().eventUploadMapperNilIfBlank,
            officialWebsite: nil,
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
            lineupSyncMode: lineupSyncMode,
            status: EventVisualStatus.resolve(startDate: draft.startDate, endDate: draft.endDate).apiValue
        )
    }

    static func updateInput(
        from draft: EventUploadDraft,
        lineupSyncMode: EventLineupSyncMode = .incrementalFill
    ) -> UpdateEventInput {
        let create = createInput(from: draft, lineupSyncMode: lineupSyncMode)
        let shouldSubmitTimeZoneSelection = draft.selectedTimeZoneLookup?.matchSource != "event-edit-hydrate"
        var input = UpdateEventInput(
            name: create.name,
            nameI18n: create.nameI18n,
            wikiFestivalId: create.wikiFestivalId,
            abbreviation: create.abbreviation ?? "",
            description: create.description ?? "",
            eventType: create.eventType,
            organizerName: create.organizerName ?? "",
            sourceEventUrl: create.sourceEventUrl ?? "",
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
            officialWebsite: nil,
            startDate: create.startDate,
            endDate: create.endDate,
            timeZone: create.timeZone,
            timeZoneCity: shouldSubmitTimeZoneSelection ? create.timeZoneCity : nil,
            timeZoneProvince: shouldSubmitTimeZoneSelection ? create.timeZoneProvince : nil,
            timeZoneCountry: shouldSubmitTimeZoneSelection ? create.timeZoneCountry : nil,
            timeZoneStateAnsi: shouldSubmitTimeZoneSelection ? create.timeZoneStateAnsi : nil,
            timeZoneLat: shouldSubmitTimeZoneSelection ? create.timeZoneLat : nil,
            timeZoneLng: shouldSubmitTimeZoneSelection ? create.timeZoneLng : nil,
            dayRolloverHour: create.dayRolloverHour,
            stageOrder: create.stageOrder,
            coverImageUrl: create.coverImageUrl ?? "",
            lineupImageUrl: create.lineupImageUrl ?? "",
            imageAssets: create.imageAssets,
            ticketTiers: create.ticketTiers,
            lineupArtists: create.lineupArtists,
            lineupSlots: create.lineupSlots,
            lineupSyncMode: create.lineupSyncMode,
            baseEventRevision: draft.incrementalBaseline?.eventRevision,
            status: create.status,
            clearManualLocation: create.manualLocation == nil,
            clearWikiFestivalId: create.wikiFestivalId == nil,
            clearLocationPoint: create.locationPoint == nil,
            clearLatitude: create.latitude == nil,
            clearLongitude: create.longitude == nil,
            clearStageOrder: create.stageOrder == nil,
            clearLineupSlots: create.lineupSlots == nil
        )
        if let patch = patchChanges(from: draft) {
            input.editMode = "patch"
            input.lineupArtists = nil
            input.lineupSlots = nil
            input.lineupChanges = patch.lineupChanges.isEmpty ? nil : patch.lineupChanges
            input.timetableChanges = patch.timetableChanges.isEmpty ? nil : patch.timetableChanges
            input.stageChanges = patch.stageChanges.isEmpty ? nil : patch.stageChanges
            input.clearLineupSlots = false
            input.clearTimetableChanges = patch.timetableChanges.isEmpty
            input.clearStageChanges = patch.stageChanges.isEmpty
        }
        return input
    }

    static func imageOnlyUpdateInput(from draft: EventUploadDraft) -> UpdateEventInput {
        let create = createInput(from: draft)
        return UpdateEventInput(
            coverImageUrl: create.coverImageUrl ?? "",
            lineupImageUrl: create.lineupImageUrl ?? "",
            imageAssets: create.imageAssets ?? []
        )
    }

    private static func firstRemoteURL(in zone: EventUploadImageZone, draft: EventUploadDraft) -> String? {
        (draft.imageZones[zone] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { $0.remoteURL?.trimmed.eventUploadMapperNilIfBlank }
            .first
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
        guard let latitude = draft.latitude, let longitude = draft.longitude else { return nil }
        let mapAddress = draft.pickedMapAddress.trimmed.eventUploadMapperNilIfBlank
        let addressText = mapAddress
            .map { localizedSingleText($0, language: draft.preferredLanguage) }
            ?? addressI18n.flatMap(normalizedLocalizedAddress)
            ?? address
                .map { $0.trimmed }
                .flatMap { $0.eventUploadMapperNilIfBlank }
                .map { localizedSingleText($0, language: draft.preferredLanguage) }
        let placeName = draft.pickedPlaceName.trimmed.eventUploadMapperNilIfBlank
            .map { localizedSingleText($0, language: draft.preferredLanguage) }
        let formatted = addressText.map {
            formattedAddress(
                detailAddressI18n: $0,
                cityI18n: cityI18n ?? city.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                },
                countryI18n: countryI18n ?? country.map {
                    localizedSingleText($0, language: draft.preferredLanguage)
                }
            )
        }
        return WebEventLocationPoint(
            provider: "apple-mapkit",
            sourceMode: "ios-event-upload-v2",
            location: WebEventLocationCoordinate(lng: longitude, lat: latitude),
            nameI18n: placeName,
            addressI18n: addressText,
            formattedAddressI18n: formatted,
            city: city
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
        let values = draft.stageEntries.enumerated().map { index, stage in
            let trimmed = stage.trimmed
            return trimmed.isEmpty ? defaultStageName(at: index) : trimmed
        }
        return values.isEmpty ? nil : values
    }

    private static func defaultStageName(at index: Int) -> String {
        index == 0 ? LT("主舞台", "Main Stage", "メインステージ") : LT("舞台 \(index + 1)", "Stage \(index + 1)", "ステージ \(index + 1)")
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
            let baseInput = EventLineupSlotInput(
                id: slot.canonicalSlotId,
                lineupArtistId: nil,
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
            var input = baseInput
            input.lineupArtistId = lineupArtistIDByKey[artistIdentityKey(baseInput)]
            return input
        }
        return timetableSlots.isEmpty ? nil : timetableSlots
    }

    private struct PatchChanges {
        var lineupChanges: [EventLineupArtistPatchChange]
        var timetableChanges: [EventLineupSlotPatchChange]
        var stageChanges: [EventStagePatchChange]
    }

    private static func patchChanges(from draft: EventUploadDraft) -> PatchChanges? {
        guard let baseline = draft.incrementalBaseline else { return nil }
        let currentArtists = lineupArtistInputs(from: draft) ?? []
        let currentSlots = lineupSlotInputs(from: draft) ?? []
        let currentStages = normalizedStages(from: draft) ?? []

        let lineupChanges = diffLineupChanges(baseline: baseline.lineupArtists, current: currentArtists)
        let timetableChanges = diffTimetableChanges(baseline: baseline.lineupSlots, current: currentSlots)
        let stageChanges = diffStageChanges(baseline: baseline.stageOrder, current: currentStages)
        if lineupChanges.isEmpty && timetableChanges.isEmpty && stageChanges.isEmpty {
            return PatchChanges(lineupChanges: [], timetableChanges: [], stageChanges: [])
        }
        return PatchChanges(lineupChanges: lineupChanges, timetableChanges: timetableChanges, stageChanges: stageChanges)
    }

    private static func diffLineupChanges(
        baseline: [EventLineupArtistInput],
        current: [EventLineupArtistInput]
    ) -> [EventLineupArtistPatchChange] {
        let baselineByID = Dictionary(uniqueKeysWithValues: baseline.compactMap { artist -> (String, EventLineupArtistInput)? in
            guard let id = artist.id?.trimmed.eventUploadMapperNilIfBlank else { return nil }
            return (id, artist)
        })
        let currentByID = Dictionary(uniqueKeysWithValues: current.compactMap { artist -> (String, EventLineupArtistInput)? in
            guard let id = artist.id?.trimmed.eventUploadMapperNilIfBlank else { return nil }
            return (id, artist)
        })
        var changes: [EventLineupArtistPatchChange] = []

        for artist in current where artist.id?.trimmed.eventUploadMapperNilIfBlank == nil {
            changes.append(EventLineupArtistPatchChange(op: "add", artist: artist))
        }
        for (id, oldArtist) in baselineByID where currentByID[id] == nil {
            changes.append(EventLineupArtistPatchChange(op: "delete", artistId: id, sortOrder: oldArtist.sortOrder))
        }
        for artist in current {
            guard let id = artist.id?.trimmed.eventUploadMapperNilIfBlank, let oldArtist = baselineByID[id] else { continue }
            if canonicalized(artist) != canonicalized(oldArtist) {
                changes.append(EventLineupArtistPatchChange(op: "update", artistId: id, patch: artist))
            } else if artist.sortOrder != oldArtist.sortOrder {
                changes.append(EventLineupArtistPatchChange(op: "reorder", artistId: id, sortOrder: artist.sortOrder))
            }
        }
        return changes
    }

    private static func diffTimetableChanges(
        baseline: [EventLineupSlotInput],
        current: [EventLineupSlotInput]
    ) -> [EventLineupSlotPatchChange] {
        let baselineByID = Dictionary(uniqueKeysWithValues: baseline.compactMap { slot -> (String, EventLineupSlotInput)? in
            guard let id = slot.id?.trimmed.eventUploadMapperNilIfBlank else { return nil }
            return (id, slot)
        })
        let currentByID = Dictionary(uniqueKeysWithValues: current.compactMap { slot -> (String, EventLineupSlotInput)? in
            guard let id = slot.id?.trimmed.eventUploadMapperNilIfBlank else { return nil }
            return (id, slot)
        })
        var changes: [EventLineupSlotPatchChange] = []

        for slot in current where slot.id?.trimmed.eventUploadMapperNilIfBlank == nil {
            changes.append(EventLineupSlotPatchChange(op: "add", slot: slot))
        }
        for (id, oldSlot) in baselineByID where currentByID[id] == nil {
            changes.append(EventLineupSlotPatchChange(op: "delete", slotId: id, sortOrder: oldSlot.sortOrder))
        }
        for slot in current {
            guard let id = slot.id?.trimmed.eventUploadMapperNilIfBlank, let oldSlot = baselineByID[id] else { continue }
            if canonicalized(slot) != canonicalized(oldSlot) {
                changes.append(EventLineupSlotPatchChange(op: "update", slotId: id, patch: slot))
            } else if slot.sortOrder != oldSlot.sortOrder {
                changes.append(EventLineupSlotPatchChange(op: "reorder", slotId: id, sortOrder: slot.sortOrder))
            }
        }
        return changes
    }

    private static func diffStageChanges(
        baseline: [String],
        current: [String]
    ) -> [EventStagePatchChange] {
        let oldNames = baseline.map { $0.trimmed }.filter { !$0.isEmpty }
        let newNames = current.map { $0.trimmed }.filter { !$0.isEmpty }
        let newLower = Set(newNames.map { $0.lowercased() })
        var changes: [EventStagePatchChange] = []
        if oldNames.count == newNames.count {
            for (oldName, newName) in zip(oldNames, newNames) where oldName.lowercased() != newName.lowercased() {
                changes.append(EventStagePatchChange(op: "rename", name: oldName, nextName: newName))
            }
            return changes
        }
        for oldName in oldNames where !newLower.contains(oldName.lowercased()) {
            changes.append(EventStagePatchChange(op: "delete", name: oldName, confirmDeleteLinkedPerformances: true))
        }
        return changes
    }

    private static func canonicalized(_ artist: EventLineupArtistInput) -> EventLineupArtistInput {
        EventLineupArtistInput(
            id: artist.id,
            djId: artist.djId?.trimmed.eventUploadMapperNilIfBlank,
            memberDjIds: artist.memberDjIds,
            memberNames: artist.memberNames?.map { $0.trimmed }.filter { !$0.isEmpty },
            djName: artist.djName.trimmed,
            sortOrder: nil
        )
    }

    private static func canonicalized(_ slot: EventLineupSlotInput) -> EventLineupSlotInput {
        EventLineupSlotInput(
            id: slot.id,
            lineupArtistId: slot.lineupArtistId,
            djId: slot.djId?.trimmed.eventUploadMapperNilIfBlank,
            memberDjIds: slot.memberDjIds,
            memberNames: slot.memberNames?.map { $0.trimmed }.filter { !$0.isEmpty },
            festivalDayIndex: slot.festivalDayIndex,
            djName: slot.djName.trimmed,
            stageName: slot.stageName?.trimmed.eventUploadMapperNilIfBlank,
            sortOrder: nil,
            startTime: slot.startTime,
            endTime: slot.endTime
        )
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
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var eventUploadMapperNilIfBlank: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
