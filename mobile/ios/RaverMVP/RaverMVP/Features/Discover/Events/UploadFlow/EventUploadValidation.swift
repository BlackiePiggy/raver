import Foundation

struct EventUploadValidationIssue: Identifiable, Hashable {
    let id = UUID()
    var step: EventUploadStep
    var message: String
}

enum EventUploadValidation {
    private static func timetableSlotContext(
        for slot: EventUploadLineupSlotDraft,
        at index: Int,
        in slots: [EventUploadLineupSlotDraft],
        draft: EventUploadDraft
    ) -> (stageName: String, stageOrder: Int, displayName: String, dayLabel: String) {
        let normalizedStageName = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LT("未命名舞台", "Unnamed Stage", "名称未設定ステージ")
            : slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        let stageOrder = slots[..<index].filter { candidate in
            candidate.dayIndex == slot.dayIndex
                && candidate.stageName.trimmingCharacters(in: .whitespacesAndNewlines) == slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        }.count + 1
        let performerNames = slot.performerNames
            .prefix(slot.actType.performerCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = performerNames.isEmpty
            ? LT("未填写 DJ", "Unnamed DJ", "未入力のDJ")
            : EventLineupActCodec.composeName(type: slot.actType, performerNames: performerNames)
        let dayLabel = timetableSlotDayLabel(for: slot, draft: draft)
        return (normalizedStageName, stageOrder, displayName, dayLabel)
    }

    private static func timetableSlotDayLabel(for slot: EventUploadLineupSlotDraft, draft: EventUploadDraft) -> String {
        if let eventDay = draft.eventDay(forID: slot.eventDayId) {
            let trimmed = eventDay.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return trimmed
            }
            return formattedEventDayDate(eventDay.date)
        }
        if let eventDay = draft.eventDay(forOverallDayIndex: max(slot.dayIndex, slot.overallDayIndex, 1)) {
            let trimmed = eventDay.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return trimmed
            }
            return formattedEventDayDate(eventDay.date)
        }
        if let localDate = slot.localDate {
            return formattedEventDayDate(localDate)
        }
        if draft.isMultiWeekSchedule {
            return LT(
                "Week \(slot.weekIndex) · Date unavailable",
                "Week \(slot.weekIndex) · Date unavailable",
                "Week \(slot.weekIndex) · 日付未確定"
            )
        }
        return LT("Date unavailable", "Date unavailable", "日付未確定")
    }

    private static func formattedEventDayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func issues(for draft: EventUploadDraft) -> [EventUploadValidationIssue] {
        var issues: [EventUploadValidationIssue] = []
        let language = draft.preferredLanguage

        if !draft.hasRequiredEntryImage {
            issues.append(.init(step: .media, message: LT("请至少上传 1 张 Poster、阵容图或 Cover。", "Add at least one Poster, Lineup, or Cover image.", "Poster、ラインナップ、またはCover画像を1枚以上追加してください。")))
        }
        if draft.name.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(step: .basic, message: LT("请填写活动名称。", "Enter an event name.", "イベント名を入力してください。")))
        }
        if draft.city.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(step: .basic, message: LT("请填写城市。", "Enter a city.", "都市を入力してください。")))
        }
        if draft.country.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(step: .basic, message: LT("请填写国家。", "Enter a country.", "国を入力してください。")))
        }
        if draft.detailAddress.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(step: .basic, message: LT("请填写详细地址。", "Enter a detailed address.", "詳細住所を入力してください。")))
        }
        if draft.endDate < draft.startDate {
            issues.append(.init(step: .time, message: LT("结束日期不能早于开始日期。", "End date cannot be earlier than start date.", "終了日は開始日より前にできません。")))
        }
        if case .create = draft.mode, draft.selectedTimeZoneLookup == nil {
            issues.append(.init(step: .basic, message: LT("请搜索城市并确认活动时区。", "Search a city and confirm the event timezone.", "都市を検索してイベントのタイムゾーンを確認してください。")))
        }
        for (index, slot) in draft.timetableSlots.enumerated() {
            let context = timetableSlotContext(for: slot, at: index, in: draft.timetableSlots, draft: draft)
            let names = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if draft.eventDay(forID: slot.eventDayId) == nil {
                issues.append(.init(
                    step: .timetable,
                    message: LT(
                        "「\(context.stageName)」第 \(context.stageOrder) 个 DJ 条目没有绑定到有效活动日，请重新选择日期。当前条目：\(context.displayName)。",
                        "\"\(context.stageName)\" DJ item #\(context.stageOrder) is not bound to a valid event day. Re-select the date. Current item: \(context.displayName).",
                        "「\(context.stageName)」のDJ項目 \(context.stageOrder) 番が有効なイベント日付に紐付いていません。日付を選び直してください。現在の項目: \(context.displayName)。"
                    )
                ))
            }
            if names.count != slot.actType.performerCount || names.contains(where: { $0.isEmpty }) {
                issues.append(.init(
                    step: .timetable,
                    message: LT(
                        "「\(context.dayLabel)」的「\(context.stageName)」第 \(context.stageOrder) 个 DJ 条目有未填写的艺人名称，请补全或删除。当前条目：\(context.displayName)。",
                        "\"\(context.dayLabel)\" \"\(context.stageName)\" DJ item #\(context.stageOrder) has empty artist names. Complete or remove it. Current item: \(context.displayName).",
                        "「\(context.dayLabel)」の「\(context.stageName)」DJ項目 \(context.stageOrder) 番に未入力のアーティスト名があります。入力するか削除してください。現在の項目: \(context.displayName)。"
                    )
                ))
            }
            if slot.startTime == nil || slot.endTime == nil {
                issues.append(.init(
                    step: .timetable,
                    message: LT(
                        "「\(context.dayLabel)」的「\(context.stageName)」第 \(context.stageOrder) 个 DJ「\(context.displayName)」必须填写开始和结束时间。",
                        "Start and end time are required for \"\(context.dayLabel)\" \"\(context.stageName)\" DJ item #\(context.stageOrder) (\(context.displayName)).",
                        "「\(context.dayLabel)」の「\(context.stageName)」DJ項目 \(context.stageOrder) 番「\(context.displayName)」には開始時間と終了時間が必要です。"
                    )
                ))
            }
        }
        for (index, slot) in draft.lineupOnlySlots.enumerated() {
            let names = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if names.count != slot.actType.performerCount || names.contains(where: { $0.isEmpty }) {
                issues.append(.init(step: .lineup, message: LT("第 \(index + 1) 个阵容条目有未填写的 DJ，请补全或删除。", "Lineup item #\(index + 1) has empty DJ names. Complete or remove it.", "\(index + 1)番目のラインナップ項目に未入力のDJがあります。入力または削除してください。")))
            }
        }
        if !draft.ticket.ticketURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           URL(string: draft.ticket.ticketURL) == nil {
            issues.append(.init(step: .tickets, message: LT("请填写有效的购票链接。", "Enter a valid ticket URL.", "有効なチケットURLを入力してください。")))
        }
        for (index, tier) in draft.ticket.tiers.enumerated() {
            let price = tier.price.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = tier.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && price.isEmpty {
                issues.append(.init(step: .tickets, message: LT("第 \(index + 1) 个票档请填写价格，或删除这个票档。", "Ticket tier #\(index + 1) needs a price, or remove it.", "\(index + 1)番目の券種に価格を入力するか削除してください。")))
            } else if !price.isEmpty && Double(price) == nil {
                issues.append(.init(step: .tickets, message: LT("第 \(index + 1) 个票档价格格式不正确。", "Ticket tier #\(index + 1) has an invalid price.", "\(index + 1)番目の券種価格の形式が正しくありません。")))
            }
        }

        return issues
    }

    static func canAdvance(from step: EventUploadStep, draft: EventUploadDraft) -> Bool {
        !issues(for: draft).contains { $0.step == step }
    }
}
