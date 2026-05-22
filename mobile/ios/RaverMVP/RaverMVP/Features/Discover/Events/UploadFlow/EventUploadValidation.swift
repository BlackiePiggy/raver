import Foundation

struct EventUploadValidationIssue: Identifiable, Hashable {
    let id = UUID()
    var step: EventUploadStep
    var message: String
}

enum EventUploadValidation {
    static func issues(for draft: EventUploadDraft) -> [EventUploadValidationIssue] {
        var issues: [EventUploadValidationIssue] = []
        let language = draft.preferredLanguage

        if draft.posterImages.isEmpty {
            issues.append(.init(step: .media, message: LT("请至少上传 1 张 Poster 海报。", "Add at least one Poster image.", "Poster画像を1枚以上追加してください。")))
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
            let names = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if names.count != slot.actType.performerCount || names.contains(where: { $0.isEmpty }) {
                issues.append(.init(step: .timetable, message: LT("第 \(index + 1) 个时间表条目有未填写的 DJ，请补全或删除。", "Timetable item #\(index + 1) has empty DJ names. Complete or remove it.", "\(index + 1)番目のタイムテーブル項目に未入力のDJがあります。入力または削除してください。")))
            }
            if slot.startTime == nil || slot.endTime == nil {
                issues.append(.init(step: .timetable, message: LT("第 \(index + 1) 个时间表条目必须填写开始和结束时间。", "Start and end time are required for timetable item #\(index + 1).", "\(index + 1)番目のタイムテーブル項目は開始時間と終了時間が必須です。")))
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
