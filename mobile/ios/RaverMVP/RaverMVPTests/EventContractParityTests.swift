import XCTest
@testable import RaverMVP

@MainActor
final class EventContractParityTests: XCTestCase {
    func testWebEventAddressSemanticsPreferLocationPointManualSetForVenueAndManualFormattedForActivity() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "manual_search",
                providerPlaceId: "poi_001",
                poiId: "poi_001",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        XCTAssertEqual(event.unifiedAddress, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(event.summaryLocation, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(event.eventActivityAddress, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testWebEventAddressSemanticsFallBackToLocationPointFormattedBeforeManualLocation() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "manual_search",
                providerPlaceId: "poi_002",
                poiId: "poi_002",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: nil,
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        XCTAssertEqual(event.unifiedAddress, "中国 · 上海 · 滨江仓库")
        XCTAssertEqual(event.eventActivityAddress, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testWebEventAddressSemanticsFallBackToManualLocationOnlyWhenLocationPointMissing() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: nil
            ),
            locationPoint: nil
        )

        XCTAssertEqual(event.unifiedAddress, "徐汇滨江 88 号")
        XCTAssertEqual(event.summaryLocation, "徐汇滨江 88 号")
        XCTAssertEqual(event.eventActivityAddress, "")
    }

    func testWebEventAddressSemanticsPreferExplicitPayloadOverridesWhenPresent() {
        let event = Self.makeWebEvent(
            activityAddress: "显式活动地址",
            venueDisplayAddress: "显式场地地址",
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "manual_search",
                providerPlaceId: "poi_003",
                poiId: "poi_003",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        XCTAssertEqual(event.unifiedAddress, "显式场地地址")
        XCTAssertEqual(event.eventActivityAddress, "显式活动地址")
    }

    func testResolvedVenueMapQueryFollowsVenueDisplayTruthBeforePOIName() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "manual_search",
                providerPlaceId: "poi_004",
                poiId: "poi_004",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        let query = resolveEventVenueMapQueryText(
            language: .zh,
            manualLocation: event.manualLocation,
            locationPoint: event.locationPoint
        )

        XCTAssertEqual(query, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testResolvedVenueMapQueryFallsBackToPOINameOnlyWhenVenueTextMissing() {
        let point = WebEventLocationPoint(
            provider: "amap",
            sourceMode: "manual_search",
            providerPlaceId: "poi_005",
            poiId: "poi_005",
            adcode: "310104",
            location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
            nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
            addressI18n: nil,
            formattedAddressI18n: nil,
            manualSetAddressI18n: nil,
            city: "Shanghai",
            district: "Xuhui",
            province: "Shanghai",
            countryCode: "CN"
        )

        let query = resolveEventVenueMapQueryText(
            language: .zh,
            manualLocation: nil,
            locationPoint: point
        )

        XCTAssertEqual(query, "滨江仓库")
    }

    func testWidgetSelectableEventUsesVenueDisplayAddressSemantics() async throws {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "manual_search",
                providerPlaceId: "poi_widget_001",
                poiId: "poi_widget_001",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let currentDirectory = fileManager.currentDirectoryPath
        defer {
            fileManager.changeCurrentDirectoryPath(currentDirectory)
            try? fileManager.removeItem(at: tempRoot)
        }
        fileManager.changeCurrentDirectoryPath(tempRoot.path)

        let store = WidgetCountdownStore(fileManager: fileManager)
        let service = WidgetSelectableEventsSyncService(store: store, session: .shared)
        _ = try await service.add(event: event)

        let snapshot = try store.loadSnapshot()
        let storedEvent = try XCTUnwrap(snapshot.events.first(where: { $0.id == event.id }))
        XCTAssertEqual(storedEvent.venueDisplayAddress, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testProfileRecentCheckinPreviewUsesServerProvidedVenueDisplayAddress() {
        let item = MyCheckinsOverviewTimelineItem(
            id: "checkin_001",
            type: "event",
            attendedAt: Self.dateTime("2099-09-12 23:30", timeZoneID: "Asia/Shanghai"),
            createdAt: Self.dateTime("2099-09-12 23:59", timeZoneID: "Asia/Shanghai"),
            event: MyCheckinsOverviewTimelineEvent(
                id: "evt_checkin_001",
                name: "Future Rave",
                nameI18n: WebBiText(en: "Future Rave", zh: "未来电音派对"),
                coverImageUrl: nil,
                address: "中国 · 上海 · 徐汇滨江 88 号",
                city: "Shanghai",
                country: "China",
                startDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
                endDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
                timeZone: "Asia/Shanghai"
            ),
            summary: MyCheckinsOverviewTimelineSummary(dayCount: 1, artistCount: 2, performanceCount: 3),
            selections: []
        )

        let preview = ProfileRecentCheckinPreview(item: item)
        XCTAssertEqual(preview.unifiedAddress, "中国 · 上海 · 徐汇滨江 88 号")
    }

    func testEventShareCardPayloadRoundTripsVenueDisplayAddressInChatMessage() async throws {
        let service = MockSocialService()
        let conversation = try await service.startDirectConversation(identifier: "warehouse_anya")
        let payload = EventShareCardPayload(
            eventID: "evt_share_001",
            eventName: "Future Rave",
            venueDisplayAddress: "中国 · 上海 · 徐汇滨江 88 号",
            city: "Shanghai",
            startAtISO8601: "2099-09-12T15:30:00Z",
            coverImageURL: "https://cdn.example.com/events/future-rave/cover.jpg",
            badgeText: "活动"
        )

        let sent = try await service.sendEventCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        XCTAssertEqual(sent.kind, ChatMessageKind.card)

        let decoded = ChatCustomCardCodec.decodePayload(
            EventShareCardPayload.self,
            cardType: ChatCustomCardWireType.event,
            from: sent.content
        )

        XCTAssertEqual(decoded?.venueDisplayAddress, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(decoded?.eventID, "evt_share_001")
        XCTAssertEqual(decoded?.eventName, "Future Rave")
    }

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
        XCTAssertEqual(input.value1.locationPoint?.provider.rawValue, "mapkit")
        XCTAssertEqual(input.value1.locationPoint?.sourceMode.rawValue, "pin_drag")
        XCTAssertEqual(input.value1.locationPoint?.nameI18n?.en, "Riverside Warehouse")
        XCTAssertEqual(input.value1.locationPoint?.nameI18n?.zh, "")
        XCTAssertEqual(input.value1.locationPoint?.addressI18n?.en, "88 Xuhui Riverside")
        XCTAssertEqual(input.value1.locationPoint?.addressI18n?.zh, "")
        XCTAssertEqual(input.value1.locationPoint?.formattedAddressI18n?.en, "88 Xuhui Riverside")
        XCTAssertEqual(input.value1.locationPoint?.formattedAddressI18n?.zh, "")
        XCTAssertEqual(input.value1.locationPoint?.manualSetAddressI18n?.en, "China · Shanghai · 88 Xuhui Riverside")
        XCTAssertEqual(input.value1.locationPoint?.manualSetAddressI18n?.zh, "中国 · 上海 · 徐汇滨江 88 号")
        XCTAssertEqual(input.value1.ticketTiers?.map(\.sortOrder), [1, 2])
        XCTAssertEqual(input.value1.ticketTiers?.map(\.currency), ["CNY", "CNY"])
        XCTAssertEqual(input.value1.lineupArtists?.first?.memberDjIds ?? [], ["dj_anyma", "dj_mrak"])
        XCTAssertEqual(input.value1.lineupArtists?.first?.memberNames ?? [], ["Anyma", "MRAK"])
        XCTAssertNil(input.value1.lineupSlots?.first?.festivalDayIndex)
        XCTAssertEqual(input.value1.lineupSlots?.first?.stageName, "Main Stage")
        XCTAssertEqual(input.value1.lineupSlots?.first?.eventDayId, "d1")
        XCTAssertEqual(
            input.value1.lineupSlots?.first?.startTime,
            "2099-09-12T23:30:00"
        )
        XCTAssertEqual(
            input.value1.lineupSlots?.first?.endTime,
            "2099-09-13T01:00:00"
        )
        XCTAssertEqual(input.value1.lineupSyncMode, .exactAlign)
        XCTAssertEqual(input.value1.isCancelled, false)
        XCTAssertEqual(input.value1.visibility, .visible)
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
        let weeks = input.value1.weeks ?? []
        let eventDays = input.value1.eventDays ?? []
        let lineupSlots = input.value1.lineupSlots ?? []

        XCTAssertEqual(input.value1.city, fixture["city"] as? String)
        XCTAssertEqual(input.value1.country, fixture["country"] as? String)
        XCTAssertEqual(input.value1.lineupSyncMode?.rawValue, fixture["lineupSyncMode"] as? String)
        XCTAssertEqual(input.value1.isCancelled, fixture["isCancelled"] as? Bool)
        XCTAssertEqual(input.value1.visibility?.rawValue, fixture["visibility"] as? String)
        XCTAssertEqual(
            try Self.canonicalJSONString(
                jsonObject: weeks.map {
                    [
                        "weekIndex": $0.weekIndex,
                        "startDate": $0.startDate,
                        "endDate": $0.endDate,
                        "sortOrder": $0.sortOrder as Any,
                    ]
                }
            ),
            try Self.canonicalJSONString(
                jsonObject: ((fixture["weeks"] as? [[String: Any]]) ?? []).map {
                    [
                        "weekIndex": $0["weekIndex"] as Any,
                        "startDate": $0["startDate"] as Any,
                        "endDate": $0["endDate"] as Any,
                        "sortOrder": $0["sortOrder"] as Any,
                    ]
                }
            )
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(
                jsonObject: eventDays.map {
                    [
                        "eventDayId": $0.eventDayId,
                        "weekIndex": $0.weekIndex,
                        "dayIndexInWeek": $0.dayIndexInWeek,
                        "overallDayIndex": $0.overallDayIndex,
                        "weekday": $0.weekday as Any,
                        "date": $0.date,
                        "sortOrder": $0.sortOrder,
                    ]
                }
            ),
            try Self.canonicalJSONString(
                jsonObject: ((fixture["eventDays"] as? [[String: Any]]) ?? []).map {
                    [
                        "eventDayId": $0["eventDayId"] as Any,
                        "weekIndex": $0["weekIndex"] as Any,
                        "dayIndexInWeek": $0["dayIndexInWeek"] as Any,
                        "overallDayIndex": $0["overallDayIndex"] as Any,
                        "weekday": $0["weekday"] as Any,
                        "date": $0["date"] as Any,
                        "sortOrder": $0["sortOrder"] as Any,
                    ]
                }
            )
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(encodable: input.value1.ticketTiers ?? []),
            try Self.canonicalJSONString(jsonObject: fixture["ticketTiers"] ?? [])
        )
        XCTAssertEqual(
            try Self.canonicalJSONString(
                jsonObject: lineupSlots.map {
                    [
                        "eventDayId": $0.eventDayId as Any,
                        "weekIndex": $0.weekIndex as Any,
                        "dayIndexInWeek": $0.dayIndexInWeek as Any,
                        "overallDayIndex": $0.overallDayIndex as Any,
                        "localDate": $0.localDate as Any,
                        "djId": $0.djId as Any,
                        "memberDjIds": $0.memberDjIds as Any,
                        "memberNames": $0.memberNames as Any,
                        "djName": $0.djName as Any,
                        "stageName": $0.stageName as Any,
                        "sortOrder": $0.sortOrder as Any,
                        "startTime": $0.startTime as Any,
                        "endTime": $0.endTime as Any,
                    ]
                }
            ),
            try Self.canonicalJSONString(
                jsonObject: ((fixture["lineupSlots"] as? [[String: Any]]) ?? []).map {
                    [
                        "eventDayId": $0["eventDayId"] as Any,
                        "weekIndex": $0["weekIndex"] as Any,
                        "dayIndexInWeek": $0["dayIndexInWeek"] as Any,
                        "overallDayIndex": $0["overallDayIndex"] as Any,
                        "localDate": $0["localDate"] as Any,
                        "djId": $0["djId"] as Any,
                        "memberDjIds": $0["memberDjIds"] as Any,
                        "memberNames": $0["memberNames"] as Any,
                        "djName": $0["djName"] as Any,
                        "stageName": $0["stageName"] as Any,
                        "sortOrder": $0["sortOrder"] as Any,
                        "startTime": $0["startTime"] as Any,
                        "endTime": $0["endTime"] as Any,
                    ]
                }
            )
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

    func testEventUploadDraftEditHydratesProviderAddressAndPlaceNameSeparately() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "amap",
                sourceMode: "map_poi_click",
                providerPlaceId: "poi_006",
                poiId: "poi_006",
                adcode: "310104",
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        let draft = EventUploadDraft.edit(event: event)

        XCTAssertEqual(draft.detailAddress.zh, "徐汇滨江 88 号")
        XCTAssertEqual(draft.detailAddress.en, "88 Xuhui Riverside")
        XCTAssertEqual(draft.pickedMapAddress, "中国 · 上海 · 滨江仓库")
        XCTAssertEqual(draft.pickedPlaceName, "滨江仓库")
        XCTAssertEqual(draft.latitude, 31.1891)
        XCTAssertEqual(draft.longitude, 121.4542)
    }

    func testUpdateInputRebuildsManualSetAddressAfterEditingHydratedDraft() {
        let event = Self.makeWebEvent(
            activityAddress: nil,
            venueDisplayAddress: nil,
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号")
            ),
            locationPoint: WebEventLocationPoint(
                provider: "mapkit",
                sourceMode: "pin_drag",
                providerPlaceId: nil,
                poiId: nil,
                adcode: nil,
                location: WebEventLocationCoordinate(lng: 121.4542, lat: 31.1891),
                nameI18n: WebBiText(en: "Riverside Warehouse", zh: "滨江仓库"),
                addressI18n: WebBiText(en: "88 Xuhui Riverside", zh: "徐汇滨江 88 号"),
                formattedAddressI18n: WebBiText(en: "China · Shanghai · Riverside Warehouse", zh: "中国 · 上海 · 滨江仓库"),
                manualSetAddressI18n: WebBiText(en: "China · Shanghai · 88 Xuhui Riverside", zh: "中国 · 上海 · 徐汇滨江 88 号"),
                city: "Shanghai",
                district: "Xuhui",
                province: "Shanghai",
                countryCode: "CN"
            )
        )

        var draft = EventUploadDraft.edit(event: event)
        draft.preferredLanguage = .en
        draft.detailAddress = EventUploadLocalizedFields(zh: "徐汇滨江 99 号", en: "99 Xuhui Riverside")
        draft.selectedTimeZoneLookup = Self.shanghaiTimeZoneLookup(matchSource: "contract-parity-edit")
        draft.timeZoneIdentifier = "Asia/Shanghai"

        let input = EventUploadMappers.updateInput(from: draft)

        XCTAssertEqual(input.value1.manualLocation?.detailAddressI18n.zh, "徐汇滨江 99 号")
        XCTAssertEqual(input.value1.manualLocation?.detailAddressI18n.en, "99 Xuhui Riverside")
        XCTAssertEqual(input.value1.manualLocation?.formattedAddressI18n.zh, "中国 · 上海 · 徐汇滨江 99 号")
        XCTAssertEqual(input.value1.manualLocation?.formattedAddressI18n.en, "China · Shanghai · 99 Xuhui Riverside")
        XCTAssertEqual(input.value1.locationPoint?.formattedAddressI18n?.zh, "中国 · 上海 · 滨江仓库")
        XCTAssertEqual(input.value1.locationPoint?.formattedAddressI18n?.en, "China · Shanghai · Riverside Warehouse")
        XCTAssertEqual(input.value1.locationPoint?.manualSetAddressI18n?.zh, "中国 · 上海 · 徐汇滨江 99 号")
        XCTAssertEqual(input.value1.locationPoint?.manualSetAddressI18n?.en, "China · Shanghai · 99 Xuhui Riverside")
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

    private static func makeWebEvent(
        activityAddress: String?,
        venueDisplayAddress: String?,
        manualLocation: WebEventManualLocation?,
        locationPoint: WebEventLocationPoint?
    ) -> WebEvent {
        WebEvent(
            id: "evt_address_semantics",
            name: "Address Semantics Event",
            nameI18n: nil,
            wikiFestivalId: nil,
            slug: "address-semantics-event",
            abbreviation: nil,
            description: nil,
            descriptionI18n: nil,
            countryI18n: WebBiText(en: "China", zh: "中国", enFull: "China"),
            cityI18n: WebBiText(en: "Shanghai", zh: "上海"),
            cardImageUrl: nil,
            coverImageUrl: nil,
            lineupImageUrl: nil,
            imageAssets: nil,
            eventType: nil,
            organizerName: nil,
            sourceEventUrl: nil,
            sourceProvider: nil,
            referenceLinks: nil,
            socialLinks: nil,
            city: "Shanghai",
            country: "China",
            activityAddress: activityAddress,
            venueDisplayAddress: venueDisplayAddress,
            manualLocation: manualLocation,
            locationPoint: locationPoint,
            latitude: 31.1891,
            longitude: 121.4542,
            startDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
            endDate: Self.date("2099-09-12", timeZoneID: "Asia/Shanghai"),
            schedule: WebEventSchedule(mode: "single_day", timeZone: "Asia/Shanghai", dayRolloverHour: 7),
            weeks: [],
            eventDays: [],
            timeZone: "Asia/Shanghai",
            startTime: nil,
            endTime: nil,
            dayRolloverHour: 7,
            stageOrder: nil,
            ticketUrl: nil,
            ticketPriceMin: nil,
            ticketPriceMax: nil,
            ticketCurrency: nil,
            ticketNotes: nil,
            officialWebsite: nil,
            isCancelled: false,
            visibility: "visible",
            isVerified: false,
            revision: 1,
            createdAt: Self.dateTime("2099-09-01 10:00", timeZoneID: "Asia/Shanghai"),
            updatedAt: Self.dateTime("2099-09-01 10:00", timeZoneID: "Asia/Shanghai"),
            organizer: nil,
            wikiFestival: nil,
            ticketTiers: [],
            lineupArtists: nil,
            lineupSlots: [],
            contributors: nil,
            contributorSummary: nil,
            contributorUsernames: nil,
            uploadedByUsername: nil,
            isContributor: nil,
            canEdit: nil,
            favoriteId: nil,
            isFavorited: nil,
            change: nil
        )
    }

    private static func loadGoldenFixture(named name: String) throws -> [String: Any] {
        var baseURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while baseURL.lastPathComponent != "raver" && baseURL.path != "/" {
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
