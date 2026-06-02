import XCTest
@testable import RaverMVP

final class EventContractParityTests: XCTestCase {
    func testCreateInputMatchesStructuredScheduleAddressAndLineupSemantics() {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "未来电音派对", en: "Future Rave")
        draft.description = "Warehouse night with cross-midnight closing set."
        draft.abbreviation = "FR2099"
        draft.eventType = "festival"
        draft.organizerFestivalID = "fest_future_rave"
        draft.organizerName = "Raver Crew"
        draft.sourceURL = "https://example.com/events/future-rave"
        draft.officialWebsite = "https://example.com/future-rave"
        draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        draft.detailAddress = EventUploadLocalizedFields(zh: "徐汇滨江 88 号", en: "88 Xuhui Riverside")
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.latitude = 31.1891
        draft.longitude = 121.4542
        draft.pickedPlaceName = "Riverside Warehouse"
        draft.pickedMapAddress = "88 Xuhui Riverside"
        draft.dayRolloverHour = 7
        draft.ticket.currency = "cny"
        draft.ticket.ticketURL = "https://tickets.example.com/future-rave"
        draft.ticket.tiers = [
            EventUploadTicketTierDraft(name: "Early Bird", price: "199"),
            EventUploadTicketTierDraft(name: "Final Release", price: "299")
        ]
        draft.ticketNotes = "Early bird before 23:00."
        draft.imageZones[.poster] = [
            EventUploadImageDraft(
                zone: .poster,
                localFileURL: nil,
                remoteURL: "https://cdn.example.com/events/future-rave/cover.jpg",
                fileName: "cover.jpg",
                mimeType: "image/jpeg",
                sortOrder: 1,
                ownership: .persistedEvent
            )
        ]
        draft.imageZones[.lineup] = [
            EventUploadImageDraft(
                zone: .lineup,
                localFileURL: nil,
                remoteURL: "https://cdn.example.com/events/future-rave/lineup.jpg",
                fileName: "lineup.jpg",
                mimeType: "image/jpeg",
                sortOrder: 1,
                ownership: .persistedEvent
            )
        ]
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai")
            )
        ])

        var lineupArtist = EventUploadLineupOnlySlotDraft()
        lineupArtist.actType = .b2b
        lineupArtist.performerNames = ["Anyma", "MRAK"]
        lineupArtist.performerDJIDs = ["dj_anyma", "dj_mrak"]
        lineupArtist.normalizePerformers()
        draft.lineupOnlySlots = [lineupArtist]

        var slot = EventUploadLineupSlotDraft()
        slot.eventDayId = "d1"
        slot.weekIndex = 1
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 1
        slot.dayIndex = 1
        slot.localDate = Self.date("2099-09-12", timeZoneID: "Asia/Shanghai")
        slot.actType = .b2b
        slot.performerNames = ["Anyma", "MRAK"]
        slot.performerDJIDs = ["dj_anyma", "dj_mrak"]
        slot.normalizePerformers()
        slot.stageName = ""
        slot.startTime = Self.dateTime("2099-09-12 23:30", timeZoneID: "Asia/Shanghai")
        slot.endTime = Self.dateTime("2099-09-12 01:00", timeZoneID: "Asia/Shanghai")
        draft.timetableSlots = [slot]

        let input = EventUploadMappers.createInput(from: draft, lineupSyncMode: .exactAlign)

        XCTAssertEqual(input.value1.schedule?.mode, .singleDay)
        XCTAssertEqual(input.value1.schedule?.dayRolloverHour, 7)
        XCTAssertEqual(input.value1.weeks?.map(\.weekIndex), [1])
        XCTAssertEqual(input.value1.eventDays?.map(\.eventDayId), ["d1"])
        XCTAssertEqual(input.value1.manualLocation?.formattedAddressI18n.en, "China · Shanghai · 88 Xuhui Riverside")
        XCTAssertEqual(input.value1.manualLocation?.formattedAddressI18n.zh, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(input.value1.locationPoint?.formattedAddressI18n?.en, "China · Shanghai · 88 Xuhui Riverside")
        XCTAssertEqual(input.value1.ticketTiers?.map(\.sortOrder), [1, 2])
        XCTAssertEqual(input.value1.ticketTiers?.map(\.currency), ["CNY", "CNY"])
        XCTAssertEqual(input.value1.lineupArtists?.first?.memberDjIds ?? [], ["dj_anyma", "dj_mrak"])
        XCTAssertEqual(input.value1.lineupArtists?.first?.memberNames ?? [], ["Anyma", "MRAK"])
        XCTAssertNil(input.value1.lineupSlots?.first?.festivalDayIndex)
        XCTAssertEqual(input.value1.lineupSlots?.first?.stageName, "Main Stage")
        XCTAssertEqual(input.value1.lineupSlots?.first?.eventDayId, "d1")
        XCTAssertEqual(
            input.value1.lineupSlots?.first?.startTime,
            "2099-09-12T15:30:00.000Z"
        )
        XCTAssertEqual(
            input.value1.lineupSlots?.first?.endTime,
            "2099-09-12T17:00:00.000Z"
        )
        XCTAssertEqual(input.value1.lineupSyncMode, .exactAlign)
        XCTAssertEqual(input.value1.status, .upcoming)
    }

    func testCreateInputNormalizesLineupSlotLocalDateFromLogicalEventDay() {
        var draft = EventUploadDraft.create()
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.applyScheduleMode(.multiDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-09-13", timeZoneID: "Asia/Shanghai")
            )
        ])

        var slot = EventUploadLineupSlotDraft()
        slot.eventDayId = "d1"
        slot.weekIndex = 1
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 2
        slot.dayIndex = 2
        slot.localDate = Self.date("2099-09-13", timeZoneID: "Asia/Shanghai")
        slot.actType = .solo
        slot.performerNames = ["Anyma"]
        slot.performerDJIDs = ["dj_anyma"]
        slot.normalizePerformers()
        slot.stageName = "Main Stage"
        slot.startTime = Self.dateTime("2099-09-12 23:30", timeZoneID: "Asia/Shanghai")
        slot.endTime = Self.dateTime("2099-09-13 01:00", timeZoneID: "Asia/Shanghai")
        draft.timetableSlots = [slot]

        let input = EventUploadMappers.createInput(from: draft)

        XCTAssertEqual(input.value1.lineupSlots?.first?.eventDayId, "d1")
        XCTAssertEqual(input.value1.lineupSlots?.first?.weekIndex, 1)
        XCTAssertEqual(input.value1.lineupSlots?.first?.dayIndexInWeek, 1)
        XCTAssertEqual(input.value1.lineupSlots?.first?.overallDayIndex, 1)
        XCTAssertEqual(input.value1.lineupSlots?.first?.localDate, "2099-09-12")
    }

    func testUpdateInputCarriesExplicitClearSemantics() {
        var draft = EventUploadDraft.create()
        draft.name = EventUploadLocalizedFields(zh: "活动清空测试", en: "Clear Semantics Event")
        draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai")
            )
        ])

        let input = EventUploadMappers.updateInput(from: draft)

        XCTAssertEqual(input.value2.clearWikiFestivalId, true)
        XCTAssertEqual(input.value2.clearManualLocation, true)
        XCTAssertEqual(input.value2.clearLocationPoint, true)
        XCTAssertEqual(input.value2.clearLatitude, true)
        XCTAssertEqual(input.value2.clearLongitude, true)
        XCTAssertEqual(input.value2.clearStageOrder, true)
        XCTAssertEqual(input.value2.clearLineupSlots, true)
    }

    func testUpdateInputOnlyClearsCityAndCountryI18nAfterExplicitIntent() {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "鍩庡競鍥藉娓呯┖", en: "Clear City Country I18n")
        draft.city = EventUploadLocalizedFields(zh: "涓婃捣", en: "Shanghai", ja: "シャンハイ")
        draft.country = EventUploadLocalizedFields(zh: "涓浗", en: "China", ja: "中国", enFull: "People's Republic of China")
        draft.clearCityI18nIntent = true
        draft.clearCountryI18nIntent = true
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai")
            )
        ])

        let input = EventUploadMappers.updateInput(from: draft)

        XCTAssertEqual(input.value1.city, "Shanghai")
        XCTAssertEqual(input.value1.country, "China")
        XCTAssertNil(input.value1.cityI18n)
        XCTAssertNil(input.value1.countryI18n)
        XCTAssertEqual(input.value2.clearCityI18n, true)
        XCTAssertEqual(input.value2.clearCountryI18n, true)
    }

    func testCreateInputMatchesGoldenCrossMidnightFixtureSubset() throws {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "鏈潵鐢甸煶娲惧", en: "Future Rave")
        draft.description = "Warehouse night with cross-midnight closing set."
        draft.abbreviation = "FR2099"
        draft.eventType = "festival"
        draft.organizerFestivalID = "fest_future_rave"
        draft.organizerName = "Raver Crew"
        draft.venueName = "The Warehouse"
        draft.venueAddress = "88 Xuhui Riverside"
        draft.sourceURL = "https://example.com/events/future-rave"
        draft.sourceProvider = "manual"
        draft.referenceLinksText = "https://example.com/a\nhttps://example.com/b"
        draft.socialLinksText = "[{\"type\":\"instagram\",\"url\":\"https://instagram.com/future-rave\"}]"
        draft.city = EventUploadLocalizedFields(zh: "涓婃捣", en: "Shanghai")
        draft.country = EventUploadLocalizedFields(zh: "涓浗", en: "China", enFull: "China")
        draft.detailAddress = EventUploadLocalizedFields(zh: "寰愭眹婊ㄦ睙 88 鍙?", en: "88 Xuhui Riverside")
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.latitude = 31.1891
        draft.longitude = 121.4542
        draft.pickedPlaceName = "Riverside Warehouse"
        draft.pickedMapAddress = "88 Xuhui Riverside"
        draft.dayRolloverHour = 7
        draft.ticket.currency = "cny"
        draft.ticket.ticketURL = "https://tickets.example.com/future-rave"
        draft.ticket.tiers = [
            EventUploadTicketTierDraft(name: "Early Bird", price: "199"),
            EventUploadTicketTierDraft(name: "Final Release", price: "299")
        ]
        draft.ticketNotes = "Early bird before 23:00."
        draft.officialWebsite = "https://example.com/future-rave"
        draft.applyScheduleMode(.multiDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-09-13", timeZoneID: "Asia/Shanghai")
            )
        ])

        var slot = EventUploadLineupSlotDraft()
        slot.eventDayId = "d1"
        slot.weekIndex = 1
        slot.dayIndexInWeek = 1
        slot.overallDayIndex = 1
        slot.dayIndex = 1
        slot.localDate = Self.date("2099-09-12", timeZoneID: "Asia/Shanghai")
        slot.actType = .b2b
        slot.performerNames = ["Anyma", "MRAK"]
        slot.performerDJIDs = ["dj_anyma", "dj_mrak"]
        slot.normalizePerformers()
        slot.stageName = ""
        slot.startTime = Self.dateTime("2099-09-12 23:30", timeZoneID: "Asia/Shanghai")
        slot.endTime = Self.dateTime("2099-09-13 01:00", timeZoneID: "Asia/Shanghai")
        draft.timetableSlots = [slot]

        let input = EventUploadMappers.createInput(from: draft, lineupSyncMode: .exactAlign)
        let fixture = try Self.loadGoldenFixture(named: "create-cross-midnight.json")

        XCTAssertEqual(input.value1.city, fixture["city"] as? String)
        XCTAssertEqual(input.value1.country, fixture["country"] as? String)
        XCTAssertEqual(input.value1.lineupSyncMode?.rawValue, fixture["lineupSyncMode"] as? String)
        XCTAssertEqual(input.value1.status?.rawValue, fixture["status"] as? String)
        XCTAssertEqual(
            try Self.canonicalJSONString(encodable: input.value1.weeks ?? []),
            try Self.canonicalJSONString(jsonObject: fixture["weeks"] ?? [])
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(encodable: input.value1.eventDays ?? []),
            try Self.canonicalJSONString(jsonObject: fixture["eventDays"] ?? [])
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(encodable: input.value1.ticketTiers ?? []),
            try Self.canonicalJSONString(jsonObject: fixture["ticketTiers"] ?? [])
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(encodable: input.value1.lineupSlots ?? []),
            try Self.canonicalJSONString(jsonObject: fixture["lineupSlots"] ?? [])
        )
    }

    func testUpdateInputMatchesGoldenClearI18nFixtureSubset() throws {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "娓呯┖ I18n 娲诲姩", en: "Clear I18n Event")
        draft.description = "Update payload that explicitly removes city/country localized write objects while preserving plain strings."
        draft.eventType = "festival"
        draft.organizerName = "Raver Crew"
        draft.sourceURL = "https://example.com/events/clear-i18n"
        draft.sourceProvider = "manual"
        draft.city = EventUploadLocalizedFields(zh: "涓婃捣", en: "Shanghai", ja: "シャンハイ")
        draft.country = EventUploadLocalizedFields(zh: "涓浗", en: "China", ja: "中国", enFull: "People's Republic of China")
        draft.clearCityI18nIntent = true
        draft.clearCountryI18nIntent = true
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-10-03", timeZoneID: "Asia/Shanghai")
            )
        ])

        let input = EventUploadMappers.updateInput(from: draft)
        let fixture = try Self.loadGoldenFixture(named: "update-clear-i18n.json")

        XCTAssertEqual(input.value1.city, fixture["city"] as? String)
        XCTAssertEqual(input.value1.country, fixture["country"] as? String)
        XCTAssertNil(input.value1.cityI18n)
        XCTAssertNil(input.value1.countryI18n)
        XCTAssertEqual(input.value2.clearCityI18n, fixture["clearCityI18n"] as? Bool)
        XCTAssertEqual(input.value2.clearCountryI18n, fixture["clearCountryI18n"] as? Bool)
        XCTAssertEqual(input.value2.clearManualLocation, fixture["clearManualLocation"] as? Bool)
        XCTAssertEqual(input.value2.clearLocationPoint, fixture["clearLocationPoint"] as? Bool)
        XCTAssertEqual(input.value2.clearLatitude, fixture["clearLatitude"] as? Bool)
        XCTAssertEqual(input.value2.clearLongitude, fixture["clearLongitude"] as? Bool)
        XCTAssertEqual(input.value2.clearSocialLinks, fixture["clearSocialLinks"] as? Bool)
        XCTAssertEqual(input.value2.clearStageOrder, fixture["clearStageOrder"] as? Bool)
        XCTAssertEqual(input.value2.clearLineupSlots, fixture["clearLineupSlots"] as? Bool)
    }

    func testImageOnlyUpdateInputStillCarriesFullEventPayload() {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "图片补传测试", en: "Image Carry Event")
        draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity")
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-12-01", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-12-01", timeZoneID: "Asia/Shanghai")
            )
        ])
        draft.imageZones[.poster] = [
            EventUploadImageDraft(
                zone: .poster,
                localFileURL: nil,
                remoteURL: "https://cdn.example.com/events/image-carry/cover.jpg",
                fileName: "cover.jpg",
                mimeType: "image/jpeg",
                sortOrder: 1,
                ownership: .persistedEvent
            )
        ]

        let input = EventUploadMappers.imageOnlyUpdateInput(from: draft)

        XCTAssertEqual(input.value1.name, "Image Carry Event")
        XCTAssertEqual(input.value1.startDate, "2099-12-01")
        XCTAssertEqual(input.value1.endDate, "2099-12-01")
        XCTAssertEqual(input.value1.schedule?.mode, .singleDay)
        XCTAssertEqual(input.value1.coverImageUrl, "https://cdn.example.com/events/image-carry/cover.jpg")
        XCTAssertEqual(input.value1.imageAssets?.first?.url, "https://cdn.example.com/events/image-carry/cover.jpg")
        XCTAssertEqual(input.value2.clearManualLocation, true)
        XCTAssertEqual(input.value2.clearLocationPoint, true)
    }

    func testMockWebFeatureServiceCreateEventPersistsGeneratedContractFields() async throws {
        var draft = EventUploadDraft.create()
        draft.preferredLanguage = .en
        draft.name = EventUploadLocalizedFields(zh: "契约落地活动", en: "Contract Landing Event")
        draft.organizerFestivalID = "fest_contract_landing"
        draft.organizerName = "Raver Crew"
        draft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        draft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        draft.detailAddress = EventUploadLocalizedFields(zh: "西岸 1 号", en: "West Bund No.1")
        draft.timeZoneIdentifier = "Asia/Shanghai"
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "mock-contract-create")
        draft.imageZones[.poster] = [
            EventUploadImageDraft(
                zone: .poster,
                localFileURL: nil,
                remoteURL: "https://cdn.example.com/events/contract-landing/poster.jpg",
                fileName: "poster.jpg",
                mimeType: "image/jpeg",
                sortOrder: 1,
                ownership: .persistedEvent
            )
        ]
        draft.applyScheduleMode(.singleDay)
        draft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-11-15", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-11-15", timeZoneID: "Asia/Shanghai")
            )
        ])

        let service = MockWebFeatureService()
        let result = try await service.createEvent(input: EventUploadMappers.createInput(from: draft))

        guard case let .created(event) = result else {
            return XCTFail("Expected created event result")
        }

        XCTAssertEqual(event.name, "Contract Landing Event")
        XCTAssertEqual(event.wikiFestivalId, "fest_contract_landing")
        XCTAssertEqual(event.organizerName, "Raver Crew")
        XCTAssertEqual(event.schedule?.mode, "single_day")
        XCTAssertEqual(event.weeks.map(\.weekIndex), [1])
        XCTAssertEqual(event.timeZone, "Asia/Shanghai")
        XCTAssertEqual(event.imageAssets?.first?.url, "https://cdn.example.com/events/contract-landing/poster.jpg")
        XCTAssertEqual(event.manualLocation?.formattedAddressI18n?.en, "China · Shanghai · West Bund No.1")
    }

    func testMockWebFeatureServiceUpdateEventUsesFullPayloadClearSemantics() async throws {
        let service = MockWebFeatureService()

        var createDraft = EventUploadDraft.create()
        createDraft.preferredLanguage = .en
        createDraft.name = EventUploadLocalizedFields(zh: "待清空活动", en: "Clearable Event")
        createDraft.organizerFestivalID = "fest_to_clear"
        createDraft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        createDraft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        createDraft.detailAddress = EventUploadLocalizedFields(zh: "老码头 9 号", en: "Old Dock No.9")
        createDraft.timeZoneIdentifier = "Asia/Shanghai"
        createDraft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "mock-contract-update-create")
        createDraft.applyScheduleMode(.singleDay)
        createDraft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-11-20", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-11-20", timeZoneID: "Asia/Shanghai")
            )
        ])

        var createSlot = EventUploadLineupSlotDraft()
        createSlot.eventDayId = "d1"
        createSlot.weekIndex = 1
        createSlot.dayIndexInWeek = 1
        createSlot.overallDayIndex = 1
        createSlot.dayIndex = 1
        createSlot.localDate = Self.date("2099-11-20", timeZoneID: "Asia/Shanghai")
        createSlot.performerNames = ["Anyma"]
        createSlot.performerDJIDs = ["dj_anyma"]
        createSlot.normalizePerformers()
        createSlot.stageName = "Main Stage"
        createSlot.startTime = Self.dateTime("2099-11-20 22:00", timeZoneID: "Asia/Shanghai")
        createSlot.endTime = Self.dateTime("2099-11-20 23:30", timeZoneID: "Asia/Shanghai")
        createDraft.timetableSlots = [createSlot]

        let createdResult = try await service.createEvent(input: EventUploadMappers.createInput(from: createDraft))
        guard case let .created(createdEvent) = createdResult else {
            return XCTFail("Expected created event result")
        }

        var updateDraft = EventUploadDraft.create()
        updateDraft.preferredLanguage = .en
        updateDraft.name = EventUploadLocalizedFields(zh: "已清空活动", en: "Cleared Event")
        updateDraft.city = EventUploadLocalizedFields(zh: "上海", en: "Shanghai")
        updateDraft.country = EventUploadLocalizedFields(zh: "中国", en: "China", enFull: "China")
        updateDraft.timeZoneIdentifier = "Asia/Shanghai"
        updateDraft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "mock-contract-update-edit")
        updateDraft.applyScheduleMode(.singleDay)
        updateDraft.applyWeekRanges([
            EventUploadWeekRangeDraft(
                startDate: Self.date("2099-11-21", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-11-21", timeZoneID: "Asia/Shanghai")
            )
        ])

        let updatedResult = try await service.updateEvent(
            id: createdEvent.id,
            input: EventUploadMappers.updateInput(from: updateDraft)
        )

        guard case let .created(updatedEvent) = updatedResult else {
            return XCTFail("Expected updated event result")
        }

        XCTAssertEqual(updatedEvent.name, "Cleared Event")
        XCTAssertNil(updatedEvent.wikiFestivalId)
        XCTAssertNil(updatedEvent.manualLocation)
        XCTAssertNil(updatedEvent.locationPoint)
        XCTAssertNil(updatedEvent.stageOrder)
        XCTAssertNil(updatedEvent.lineupArtists)
        XCTAssertTrue(updatedEvent.lineupSlots.isEmpty)
        XCTAssertEqual(updatedEvent.weeks.map(\.weekIndex), [1])
        XCTAssertEqual(
            updatedEvent.startDate.eventArchiveDateText(in: TimeZone(identifier: "Asia/Shanghai") ?? .current),
            "2099-11-21"
        )
    }

    private static func shanghaiTimeZoneLookup(matchSource: String) -> EventTimezoneLookupItem {
        EventTimezoneLookupItem(
            city: "Shanghai",
            cityAscii: "Shanghai",
            province: "Shanghai",
            exactProvince: "Shanghai",
            stateAnsi: "SH",
            country: "China",
            iso2: "CN",
            iso3: "CHN",
            timezone: "Asia/Shanghai",
            lat: 31.2304,
            lng: 121.4737,
            population: 24_870_895,
            label: "Shanghai, China · Asia/Shanghai",
            matchSource: matchSource
        )
    }

    private static func loadGoldenFixture(named name: String) throws -> [String: Any] {
        var baseURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<5 {
            baseURL.deleteLastPathComponent()
        }
        let fixtureURL = baseURL
            .appendingPathComponent("contracts")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("event")
            .appendingPathComponent("golden")
            .appendingPathComponent(name)
        let data = try Data(contentsOf: fixtureURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "EventContractParityTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture is not a JSON object"])
        }
        return object
    }

    private static func canonicalJSONString<T: Encodable>(encodable value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try canonicalJSONString(jsonObject: object)
    }

    private static func canonicalJSONString(jsonObject value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private static func date(_ value: String, timeZoneID: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else {
            fatalError("Failed to parse date \(value)")
        }
        return date
    }

    private static func dateTime(_ value: String, timeZoneID: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = formatter.date(from: value) else {
            fatalError("Failed to parse date time \(value)")
        }
        return date
    }
}
