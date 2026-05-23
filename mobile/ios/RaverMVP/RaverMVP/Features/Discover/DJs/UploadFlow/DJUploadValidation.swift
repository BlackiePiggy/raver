import Foundation

struct DJUploadValidationIssue: Identifiable, Hashable {
    var id: String { "\(step.rawValue)-\(message)" }
    let step: DJUploadStep
    let message: String
}

enum DJUploadValidation {
    static func issues(for draft: DJUploadDraft) -> [DJUploadValidationIssue] {
        var issues: [DJUploadValidationIssue] = []

        if draft.primaryName.isEmpty {
            issues.append(DJUploadValidationIssue(step: .identity, message: LT("请填写 DJ 名称", "Enter the DJ name", "DJ名を入力してください")))
        }
        if draft.avatar == nil {
            issues.append(DJUploadValidationIssue(step: .identity, message: LT("请上传 DJ 头像", "Upload a DJ avatar", "DJアバターをアップロードしてください")))
        }
        if !draft.hasPlatformLink && draft.proofImage == nil {
            issues.append(DJUploadValidationIssue(step: .links, message: LT("请至少填写一个平台链接，或上传一张证明图片", "Add at least one platform link or upload a proof image", "プラットフォームリンクを1つ以上追加するか、証明画像をアップロードしてください")))
        }

        for value in [
            draft.spotifyUrl,
            draft.instagramUrl,
            draft.facebookUrl,
            draft.soundcloudUrl,
            draft.twitterUrl,
            draft.youtubeUrl,
            draft.neteaseUrl,
            draft.qqMusicUrl,
            draft.website,
            draft.otherPlatformUrl,
        ] where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                issues.append(DJUploadValidationIssue(step: .links, message: LT("平台链接格式不正确", "One platform link is invalid", "リンク形式が正しくありません")))
                break
            }
        }

        for value in [
            draft.spotifyFollowers,
            draft.trackCount,
            draft.playlistCount,
            draft.soundCloudFollowers,
            draft.soundCloudFavorites,
        ] where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if Int(value.trimmingCharacters(in: .whitespacesAndNewlines)).map({ $0 >= 0 }) != true {
                issues.append(DJUploadValidationIssue(step: .links, message: LT("平台数据只能填写非负整数", "Platform stats must be non-negative integers", "プラットフォーム統計は0以上の整数で入力してください")))
                break
            }
        }

        return issues
    }

    static func canAdvance(from step: DJUploadStep, draft: DJUploadDraft) -> Bool {
        !issues(for: draft).contains { $0.step == step }
    }
}
