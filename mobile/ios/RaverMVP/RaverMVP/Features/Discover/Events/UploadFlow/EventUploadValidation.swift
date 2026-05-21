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
        if !draft.timetableSlots.isEmpty {
            let normalizedStages = draft.stageEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if normalizedStages.isEmpty {
                issues.append(.init(step: .timetable, message: LT("如果要填写时间表，请至少添加 1 个舞台；名称留空会默认展示为主舞台。", "Add at least one stage before filling a timetable. Empty names will default to Main Stage.", "タイムテーブルを入力する場合は、少なくとも1つのステージを追加してください。空欄名はメインステージとして扱われます。")))
            }
        }
        for (index, slot) in draft.timetableSlots.enumerated() {
            let names = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if names.count != slot.actType.performerCount || names.contains(where: { $0.isEmpty }) {
                issues.append(.init(step: .timetable, message: LT("第 \(index + 1) 个时间表条目有未填写的 DJ，请补全或删除。", "Timetable item #\(index + 1) has empty DJ names. Complete or remove it.", "\(index + 1)番目のタイムテーブル項目に未入力のDJがあります。入力または削除してください。")))
            }
            if slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(step: .timetable, message: LT("第 \(index + 1) 个时间表条目请选择舞台。", "Choose a stage for timetable item #\(index + 1).", "\(index + 1)番目のタイムテーブル項目でステージを選択してください。")))
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
            issues.append(.init(step: .review, message: LT("请填写有效的购票链接。", "Enter a valid ticket URL.", "有効なチケットURLを入力してください。")))
        }

        return issues
    }

    static func canAdvance(from step: EventUploadStep, draft: EventUploadDraft) -> Bool {
        !issues(for: draft).contains { $0.step == step }
    }
}
