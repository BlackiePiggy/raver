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
                "Week \(slot.weekIndex) · Day \(max(slot.dayIndexInWeek, 1))",
                "Week \(slot.weekIndex) · Day \(max(slot.dayIndexInWeek, 1))",
                "Week \(slot.weekIndex) · Day \(max(slot.dayIndexInWeek, 1))"
            )
        }
        return LT("Day \(max(slot.overallDayIndex, 1))", "Day \(max(slot.overallDayIndex, 1))", "Day \(max(slot.overallDayIndex, 1))")
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
        let socialLinksText = draft.socialLinksText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !socialLinksText.isEmpty,
           socialLinksText.data(using: .utf8).flatMap({ try? JSONSerialization.jsonObject(with: $0) }) == nil {
            issues.append(.init(
                step: .basic,
                message: LT(
                    "绀句氦閾炬帴 JSON 鏍煎紡涓嶆纭紝璇锋鏌ュ悗鍐嶆彁浜ゃ€?",
                    "Social Links JSON is invalid. Please fix it before submitting.",
                    "SNS銉兂銈紙JSON锛変笉姝ｇ‘銇с仚銆傞€佷俊鍓嶃伀淇銇椼仸銇忋仩銇曘亜銆?"
                )
            ))
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

enum EventSubmissionErrorMapper {
    private static let submissionValidationCode = "EVENT_SUBMISSION_INVALID_PAYLOAD"

    static func userFacingMessage(code: String?, rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LT("提交内容有误，请检查活动信息后重试。", "Some event details are invalid. Please review and try again.", "イベント情報に不足または誤りがあります。確認してもう一度お試しください。")
        }

        guard code == submissionValidationCode else {
            return trimmed
        }

        let normalized = normalize(trimmed)

        if normalized.contains("schedulemode") {
            return LT("请选择活动日期类型：单日、多日或多周。", "Choose an event date type: single-day, multi-day, or multi-week.", "開催日タイプを選択してください。単日、複数日、または複数週です。")
        }

        if normalized.contains("singleday活动必须且只能有1个eventday") {
            return LT("单日活动只能设置 1 个活动日。", "A single-day event can only have 1 event day.", "単日イベントは1つの開催日のみ設定できます。")
        }

        if normalized.contains("multiday活动至少需要2个eventdays") {
            return LT("多日活动至少需要 2 个活动日。", "A multi-day event needs at least 2 event days.", "複数日イベントには少なくとも2つの開催日が必要です。")
        }

        if normalized.contains("multiweek活动至少需要2个weeks") {
            return LT("多周活动至少需要 2 个周次。", "A multi-week event needs at least 2 weeks.", "複数週イベントには少なくとも2つの週が必要です。")
        }

        if normalized.contains("weeks不能为空") || normalized.contains("weeks必须是数组") {
            return LT("请先完整填写每个周次的开始和结束日期。", "Fill in the start and end date for each week.", "各週の開始日と終了日を入力してください。")
        }

        if normalized.contains("eventdays不能为空") || normalized.contains("eventdays必须是数组") {
            return LT("请先完整填写活动日信息。", "Fill in the event day details before submitting.", "送信前に開催日の情報を入力してください。")
        }

        if normalized.contains("缺少有效日期") || normalized.contains("日期无效") {
            return LT("请检查活动日期，确保开始、结束和活动日日期都有效。", "Check the event dates and make sure the start, end, and event day dates are valid.", "開始日、終了日、各開催日の日付が正しいか確認してください。")
        }

        if normalized.contains("enddate不能早于startdate") {
            return LT("结束日期不能早于开始日期。", "End date cannot be earlier than start date.", "終了日は開始日より前にできません。")
        }

        if normalized.contains("eventdaysoveralldayindex必须从1开始连续递增") {
            return LT("活动日顺序有误，请按从第 1 天开始连续排列。", "Event days must be in continuous order starting from day 1.", "開催日は1日目から連続した順番で設定してください。")
        }

        if normalized.contains("weeks与eventdays的整体起止日期不一致") {
            return LT("活动整体日期与各活动日范围不一致，请重新检查日期设置。", "The overall date range does not match the event days. Please review the schedule.", "イベント全体の日付範囲と各開催日の範囲が一致していません。日程を確認してください。")
        }

        if normalized.contains("eventday") && normalized.contains("weekindex") && normalized.contains("不存在") {
            return LT("有活动日没有正确归属到对应周次，请检查周次和日期。", "Some event days are not assigned to a valid week. Please check the week and date settings.", "一部の開催日が有効な週に紐付いていません。週と日付の設定を確認してください。")
        }

        if normalized.contains("eventday") && normalized.contains("日期不在所属week范围内") {
            return LT("有活动日不在所属周次范围内，请检查周次和日期设置。", "Some event days fall outside their assigned week. Please review the week and date settings.", "一部の開催日が所属週の範囲外です。週と日付の設定を確認してください。")
        }

        if normalized.contains("sloteventdayid") && normalized.contains("不存在于eventdays中") {
            return LT("时间表中的演出没有绑定到有效活动日，请检查时间表后再提交。", "Some timetable entries are not linked to a valid event day. Please review the timetable.", "タイムテーブル内の出演が有効な開催日に紐付いていません。確認してから送信してください。")
        }

        if normalized.contains("所有timetableslot都必须携带eventdayid") {
            return LT("时间表中的每个演出都需要绑定到具体活动日。", "Each timetable entry must be linked to a specific event day.", "各タイムテーブル項目は具体的な開催日に紐付いている必要があります。")
        }

        if normalized.contains("缺少有效的starttime/endtime") {
            return LT("时间表中的演出需要同时填写开始和结束时间。", "Each timetable entry needs both a start time and an end time.", "各タイムテーブル項目には開始時間と終了時間の両方が必要です。")
        }

        return LT("提交内容有误，请检查活动日期、活动日和时间表后重试。", "Some event details are invalid. Please review the schedule, event days, and timetable, then try again.", "イベント情報に不足または誤りがあります。日程、開催日、タイムテーブルを確認してから再度お試しください。")
    }

    private static func normalize(_ message: String) -> String {
        message
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "、", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "。", with: ".")
    }
}
