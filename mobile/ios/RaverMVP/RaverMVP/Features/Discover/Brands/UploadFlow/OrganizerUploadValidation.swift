import Foundation

struct OrganizerUploadValidationIssue: Identifiable, Hashable {
    var id: String { "\(step.rawValue)-\(message)" }
    let step: OrganizerUploadStep
    let message: String
}

enum OrganizerUploadValidation {
    static func issues(for draft: OrganizerUploadDraft) -> [OrganizerUploadValidationIssue] {
        var issues: [OrganizerUploadValidationIssue] = []

        if draft.avatarImage == nil {
            issues.append(OrganizerUploadValidationIssue(
                step: .media,
                message: LT("请上传主办方头像", "Upload an organizer avatar", "主催者のアバターをアップロードしてください")
            ))
        }
        if draft.primaryName.isEmpty {
            issues.append(OrganizerUploadValidationIssue(
                step: .basic,
                message: LT("请填写主办方名称", "Enter the organizer name", "主催者名を入力してください")
            ))
        }
        if draft.introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(OrganizerUploadValidationIssue(
                step: .profile,
                message: LT("请填写主办方介绍", "Enter the organizer profile", "主催者紹介を入力してください")
            ))
        }
        if !draft.hasAnyLink && draft.proofImages.isEmpty {
            issues.append(OrganizerUploadValidationIssue(
                step: .links,
                message: LT("请至少填写一个官方链接，或上传证明图片", "Add at least one official link or upload proof", "公式リンクを1つ以上追加するか、証明画像をアップロードしてください")
            ))
        }
        if !draft.rightsConfirmed || !draft.identityConfirmed {
            issues.append(OrganizerUploadValidationIssue(
                step: .review,
                message: LT("请确认资料权利与身份声明", "Confirm the rights and identity declarations", "権利と本人確認の宣言を確認してください")
            ))
        }

        for value in [
            draft.officialWebsite,
            draft.instagram,
            draft.facebook,
            draft.twitter,
            draft.youtube,
            draft.tiktok,
        ] where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                issues.append(OrganizerUploadValidationIssue(
                    step: .links,
                    message: LT("链接格式不正确", "One link is invalid", "リンク形式が正しくありません")
                ))
                break
            }
        }

        return issues
    }

    static func canAdvance(from step: OrganizerUploadStep, draft: OrganizerUploadDraft) -> Bool {
        !issues(for: draft).contains { $0.step == step }
    }
}
