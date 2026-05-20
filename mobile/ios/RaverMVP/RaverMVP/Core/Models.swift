import Foundation

enum ConversationType: String, Codable, CaseIterable, Identifiable {
    case direct
    case group

    var id: String { rawValue }
    var title: String {
        switch self {
        case .direct: return LT("私信", "Direct", "DM")
        case .group: return LT("小队", "Squad", "Squad")
        }
    }
}

struct Session: Codable {
    let token: String
    let refreshToken: String?
    let user: UserSummary
    let accountStatus: AccountEnforcementStatus?

    init(token: String, refreshToken: String? = nil, user: UserSummary, accountStatus: AccountEnforcementStatus? = nil) {
        self.token = token
        self.refreshToken = refreshToken
        self.user = user
        self.accountStatus = accountStatus
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case accessToken
        case refreshToken
        case user
        case accountStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tokenValue = try container.decodeIfPresent(String.self, forKey: .token)
            ?? container.decode(String.self, forKey: .accessToken)
        let refreshTokenValue = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        let userValue = try container.decode(UserSummary.self, forKey: .user)
        let accountStatusValue = try container.decodeIfPresent(AccountEnforcementStatus.self, forKey: .accountStatus)

        token = tokenValue
        refreshToken = refreshTokenValue
        user = userValue
        accountStatus = accountStatusValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(user, forKey: .user)
        try container.encodeIfPresent(accountStatus, forKey: .accountStatus)
    }
}

enum SessionExpirationReason: String, Codable, Hashable {
    case expired
    case revoked
    case idleTimeout
    case absoluteTimeout
    case accountInactive
    case unknown

    var userFacingMessage: String {
        switch self {
        case .expired:
            return LT("登录已过期，请重新登录。", "Your session expired. Please log in again.", "ログインの有効期限が切れました。再度ログインしてください。")
        case .revoked:
            return LT("当前设备已被退出登录。", "This device has been signed out.", "この端末はログアウトされました。")
        case .idleTimeout:
            return LT("长时间未操作，已自动退出登录。", "You were signed out after being inactive.", "長時間操作がなかったため、自動的にログアウトしました。")
        case .absoluteTimeout:
            return LT("为了账号安全，请重新登录。", "For your account security, please log in again.", "アカウント保護のため、再度ログインしてください。")
        case .accountInactive:
            return LT("账号已删除或停用，请重新登录其他账号。", "This account has been deleted or disabled. Please log in with another account.", "このアカウントは削除または停止されています。別のアカウントでログインしてください。")
        case .unknown:
            return LT("登录状态已失效，请重新登录。", "Session expired. Please log in again.", "ログイン状態が無効です。再度ログインしてください。")
        }
    }
}

struct AuthSessionItem: Codable, Identifiable, Hashable {
    let id: String
    let clientType: String
    let deviceId: String?
    let deviceName: String?
    let platform: String?
    let appVersion: String?
    let userAgent: String?
    let ipAddressMasked: String?
    let createdAt: Date
    let lastUsedAt: Date?
    let expiresAt: Date
    let idleExpiresAt: Date?
    let absoluteExpiresAt: Date?
    let revokedAt: Date?
    let isCurrent: Bool

    var isActive: Bool { revokedAt == nil }
}

struct AuthSessionRevokeResult: Codable, Hashable {
    let success: Bool
    let revokedCurrent: Bool
}

struct IMBootstrap: Codable {
    let enabled: Bool
    let userID: String
    let token: String?
    let apiURL: String
    let wsURL: String
    let platformID: Int
    let systemUserID: String
    let expiresAt: String?
}
struct TencentIMBootstrap: Codable {
    let enabled: Bool
    let sdkAppID: Int
    let userID: String
    let userSig: String?
    let expiresAt: String?
    let region: String
    let adminIdentifier: String
}

struct UserSummary: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var isFollowing: Bool
    var isFriend: Bool? = nil
    var conversationID: String? = nil
    var friendMessage: String? = nil
    var regionCode: String? = nil
    var birthYear: Int? = nil
    var ageBand: UserAgeBand? = nil
    var guardianContactEmail: String? = nil
}

enum AccountBaseStatus: String, Codable, Hashable {
    case active
    case pendingDeletion = "pending_deletion"
    case deleted
    case disabled
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountBaseStatus(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .active: return LT("正常", "Active", "正常")
        case .pendingDeletion: return LT("删除处理中", "Deletion Pending", "削除処理中")
        case .deleted: return LT("已删除", "Deleted", "削除済み")
        case .disabled: return LT("已停用", "Disabled", "停止済み")
        case .unknown: return LT("未知", "Unknown", "不明")
        }
    }
}

enum AccountEnforcementStatusKind: String, Codable, Hashable {
    case none
    case restricted
    case suspended
    case banned
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountEnforcementStatusKind(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .none: return LT("无处罚", "No Enforcement", "処分なし")
        case .restricted: return LT("功能受限", "Restricted", "機能制限中")
        case .suspended: return LT("临时封禁", "Suspended", "一時停止")
        case .banned: return LT("封禁", "Banned", "禁止")
        case .unknown: return LT("未知状态", "Unknown", "不明な状態")
        }
    }

    var isLimited: Bool {
        self == .restricted || self == .suspended || self == .banned
    }
}

enum AccountEnforcementScope: String, Codable, Hashable, CaseIterable {
    case login
    case postCreate = "post_create"
    case commentCreate = "comment_create"
    case messageSend = "message_send"
    case mediaUpload = "media_upload"
    case eventCreate = "event_create"
    case locationShare = "location_share"
    case profileUpdate = "profile_update"
    case squadCreate = "squad_create"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountEnforcementScope(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .login: return LT("登录", "Login", "ログイン")
        case .postCreate: return LT("发帖", "Create Posts", "投稿作成")
        case .commentCreate: return LT("评论", "Comment", "コメント")
        case .messageSend: return LT("私信", "Message", "メッセージ")
        case .mediaUpload: return LT("上传媒体", "Upload Media", "メディアアップロード")
        case .eventCreate: return LT("创建活动", "Create Event", "イベント作成")
        case .locationShare: return LT("位置共享", "Share Location", "位置情報共有")
        case .profileUpdate: return LT("修改资料", "Edit Profile", "プロフィール編集")
        case .squadCreate: return LT("创建小队", "Create Squad", "Squad作成")
        case .unknown: return LT("未知范围", "Unknown Scope", "不明な範囲")
        }
    }
}

enum AccountEnforcementType: String, Codable, Hashable {
    case warning
    case contentAction = "content_action"
    case restriction
    case suspension
    case ban
    case riskFreeze = "risk_freeze"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountEnforcementType(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .warning: return LT("警告", "Warning", "警告")
        case .contentAction: return LT("内容处理", "Content Action", "コンテンツ対応")
        case .restriction: return LT("功能限制", "Restriction", "機能制限")
        case .suspension: return LT("临时封禁", "Suspension", "一時停止")
        case .ban: return LT("封禁", "Ban", "禁止")
        case .riskFreeze: return LT("风险冻结", "Risk Freeze", "リスク凍結")
        case .unknown: return LT("处罚", "Enforcement", "処分")
        }
    }
}

enum AccountEnforcementRecordStatus: String, Codable, Hashable {
    case active
    case scheduled
    case expired
    case revoked
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountEnforcementRecordStatus(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .active: return LT("生效中", "Active", "有効")
        case .scheduled: return LT("待生效", "Scheduled", "予定")
        case .expired: return LT("已到期", "Expired", "期限切れ")
        case .revoked: return LT("已撤销", "Revoked", "取消済み")
        case .unknown: return LT("未知", "Unknown", "不明")
        }
    }
}

enum AccountEnforcementAppealStatus: String, Codable, Hashable {
    case submitted
    case underReview = "under_review"
    case needMoreInfo = "need_more_info"
    case accepted
    case rejected
    case closed
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountEnforcementAppealStatus(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .submitted: return LT("已提交", "Submitted", "送信済み")
        case .underReview: return LT("审核中", "Under Review", "審査中")
        case .needMoreInfo: return LT("需补充", "Need More Info", "追加情報が必要")
        case .accepted: return LT("已通过", "Accepted", "承認済み")
        case .rejected: return LT("已驳回", "Rejected", "却下済み")
        case .closed: return LT("已关闭", "Closed", "終了")
        case .unknown: return LT("未知", "Unknown", "不明")
        }
    }
}

struct AccountEnforcementStatus: Codable, Hashable {
    let userId: String
    var accountStatus: AccountBaseStatus
    var enforcementStatus: AccountEnforcementStatusKind
    var scopes: [String]
    var nextReviewAt: Date?
    var appealable: Bool
    var activeEnforcements: [AccountEnforcement]

    static let clear = AccountEnforcementStatus(
        userId: "",
        accountStatus: .active,
        enforcementStatus: .none,
        scopes: [],
        nextReviewAt: nil,
        appealable: false,
        activeEnforcements: []
    )

    func blocks(_ scope: AccountEnforcementScope) -> Bool {
        guard enforcementStatus.isLimited else { return false }
        if scopes.contains(scope.rawValue) {
            return true
        }
        return scope != .login && scopes.contains(AccountEnforcementScope.login.rawValue)
    }

    func restriction(for scope: AccountEnforcementScope) -> AccountEnforcementRestriction? {
        restriction(for: [scope])
    }

    func restriction(for scopes: [AccountEnforcementScope]) -> AccountEnforcementRestriction? {
        guard enforcementStatus.isLimited else { return nil }
        for scope in scopes where blocks(scope) {
            let blockingEnforcements = activeEnforcements.filter { enforcement in
                enforcement.scopes.contains(scope.rawValue)
                    || (scope != .login && enforcement.scopes.contains(AccountEnforcementScope.login.rawValue))
            }
            return AccountEnforcementRestriction(
                scope: scope.rawValue,
                accountStatus: self,
                blockingEnforcements: blockingEnforcements
            )
        }
        return nil
    }

    var limitedScopeTitles: [String] {
        scopes.compactMap { AccountEnforcementScope(rawValue: $0)?.title }
    }

    var restrictionSummary: String {
        guard enforcementStatus.isLimited else { return LT("账号正常。", "Account is active.", "アカウントは正常です。") }
        let scopeText = limitedScopeTitles.isEmpty ? LT("当前操作受限。", "Current actions are restricted.", "現在の操作は制限されています。") : limitedScopeTitles.joined(separator: "、")
        if let nextReviewAt {
            return "\(scopeText) \(LT("下次复核：", "Next review: ", "次回審査: "))\(Self.formatDate(nextReviewAt))"
        }
        return scopeText
    }

    private static func formatDate(_ date: Date) -> String {
        date.appLocalizedYMDHMText()
    }
}

struct AccountEnforcement: Codable, Hashable, Identifiable {
    let id: String
    var userId: String?
    var status: AccountEnforcementRecordStatus?
    var type: AccountEnforcementType
    var scopes: [String]
    var reasonCode: String
    var userMessageI18n: [String: String]?
    var startsAt: Date
    var endsAt: Date?
    var revokedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var appeals: [AccountEnforcementAppeal]?

    var userMessage: String? {
        let language = AppLanguagePreference.current.effectiveLanguage
        let preferredKeys: [String]
        switch language {
        case .ja:
            preferredKeys = ["ja-JP", "ja", "en", "en-US", "zh", "zh-CN"]
        case .en:
            preferredKeys = ["en", "en-US", "ja-JP", "ja", "zh", "zh-CN"]
        case .zh, .system:
            preferredKeys = ["zh", "zh-CN", "ja-JP", "ja", "en", "en-US"]
        }
        for key in preferredKeys {
            if let value = userMessageI18n?[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    var displayReason: String {
        userMessage ?? Self.localizedReasonTitle(for: reasonCode)
    }

    var isAppealable: Bool {
        status == nil || status == .active || status == .scheduled
    }

    private static func localizedReasonTitle(for reasonCode: String) -> String {
        switch reasonCode {
        case "spam":
            return LT("垃圾信息或刷屏", "Spam or flooding", "スパムまたは連投")
        case "harassment":
            return LT("骚扰、辱骂或霸凌", "Harassment or bullying", "嫌がらせ、侮辱、いじめ")
        case "hate_or_discrimination":
            return LT("仇恨或歧视", "Hate or discrimination", "ヘイトまたは差別")
        case "sexual_content":
            return LT("色情或露骨内容", "Sexual content", "性的または露骨な内容")
        case "violence_or_threat":
            return LT("暴力威胁", "Violence or threats", "暴力や脅迫")
        case "illegal_activity":
            return LT("违法活动", "Illegal activity", "違法行為")
        case "impersonation":
            return LT("冒充他人", "Impersonation", "なりすまし")
        case "privacy_violation":
            return LT("泄露隐私", "Privacy violation", "プライバシー侵害")
        case "copyright":
            return LT("版权侵权", "Copyright infringement", "著作権侵害")
        case "scam_or_fraud":
            return LT("诈骗或钓鱼", "Scam or fraud", "詐欺またはフィッシング")
        case "minor_safety":
            return LT("未成年人安全", "Minor safety", "未成年者の安全")
        case "platform_abuse":
            return LT("平台滥用", "Platform abuse", "プラットフォーム悪用")
        default:
            return LT("违反社区规范", "Community guideline violation", "コミュニティガイドライン違反")
        }
    }
}

struct AccountEnforcementAppeal: Codable, Hashable, Identifiable {
    let id: String
    var enforcementId: String
    var userId: String?
    var status: AccountEnforcementAppealStatus
    var appealReason: String
    var contactEmail: String?
    var reviewerId: String?
    var decision: String?
    var decisionNote: String?
    var reviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date?
}

struct AccountEnforcementAppealInput: Encodable, Hashable {
    var appealReason: String
    var contactEmail: String?
    var attachments: [String]
}

struct AccountEnforcementRestriction: Codable, Hashable {
    let scope: String
    let accountStatus: AccountEnforcementStatus?
    let blockingEnforcements: [AccountEnforcement]
}

enum ContentReportTargetType: String, Codable, Hashable {
    case user
    case post
    case postComment = "post_comment"
    case eventLiveComment = "event_live_comment"
    case djSet = "dj_set"
    case event
    case dj
    case label
    case directChat = "direct_chat"
    case groupChat = "group_chat"
    case checkins = "checkins"
    case learnArticle = "learn_article"
    case festival
    case circleID = "circle_id"
    case ratingEvent = "rating_event"
    case ratingUnit = "rating_unit"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ContentReportTargetType(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .user: return LT("用户", "User", "ユーザー")
        case .post: return LT("动态", "Post", "投稿")
        case .postComment: return LT("评论", "Comment", "コメント")
        case .eventLiveComment: return LT("活动讨论", "Event Discussion", "イベントディスカッション")
        case .djSet: return "DJ Set"
        case .event: return LT("活动", "Event", "イベント")
        case .dj: return "DJ"
        case .label: return LT("厂牌", "Label", "レーベル")
        case .directChat: return LT("私信会话", "Direct Chat", "DM会話")
        case .groupChat: return LT("群聊", "Group Chat", "グループチャット")
        case .checkins: return LT("打卡页", "Check-ins", "チェックインページ")
        case .learnArticle: return LT("学习内容", "Learn Article", "学習コンテンツ")
        case .festival: return LT("音乐节", "Festival", "フェス")
        case .circleID: return "Circle ID"
        case .ratingEvent: return LT("评分活动", "Rating Event", "評価イベント")
        case .ratingUnit: return LT("评分单元", "Rating Unit", "評価ユニット")
        case .unknown: return LT("内容", "Content", "コンテンツ")
        }
    }
}

enum ContentReportReason: String, Codable, Hashable, CaseIterable, Identifiable {
    case spam
    case harassment
    case hateOrDiscrimination = "hate_or_discrimination"
    case sexualContent = "sexual_content"
    case violenceOrThreat = "violence_or_threat"
    case illegalActivity = "illegal_activity"
    case impersonation
    case privacyViolation = "privacy_violation"
    case copyright
    case scamOrFraud = "scam_or_fraud"
    case minorSafety = "minor_safety"
    case platformAbuse = "platform_abuse"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return LT("垃圾信息/刷屏", "Spam or flooding", "スパム/連投")
        case .harassment: return LT("骚扰、辱骂或霸凌", "Harassment or bullying", "嫌がらせ、侮辱、いじめ")
        case .hateOrDiscrimination: return LT("仇恨或歧视", "Hate or discrimination", "ヘイトまたは差別")
        case .sexualContent: return LT("色情或露骨内容", "Sexual content", "性的または露骨な内容")
        case .violenceOrThreat: return LT("暴力威胁", "Violence or threats", "暴力や脅迫")
        case .illegalActivity: return LT("违法活动", "Illegal activity", "違法行為")
        case .impersonation: return LT("冒充他人", "Impersonation", "なりすまし")
        case .privacyViolation: return LT("泄露隐私", "Privacy violation", "プライバシー侵害")
        case .copyright: return LT("版权侵权", "Copyright infringement", "著作権侵害")
        case .scamOrFraud: return LT("诈骗或钓鱼", "Scam or fraud", "詐欺またはフィッシング")
        case .minorSafety: return LT("未成年人安全", "Minor safety", "未成年者の安全")
        case .platformAbuse: return LT("平台滥用", "Platform abuse", "プラットフォーム悪用")
        case .other: return LT("其他", "Other", "その他")
        }
    }
}

struct ContentReportInput: Encodable, Hashable {
    var targetType: String
    var targetId: String
    var reason: String
    var detail: String?
    var attachments: [ContentReportAttachmentInput]?
    var source: String
}

struct ContentReportAttachmentInput: Encodable, Hashable {
    var type: String
    var url: String
    var label: String?
}

struct ContentReport: Codable, Identifiable, Hashable {
    let id: String
    var targetType: String
    var targetId: String
    var targetUserId: String?
    var targetUser: UserSummary?
    var reason: String
    var detail: String?
    var attachments: [ContentReportAttachment]?
    var source: String?
    var status: String
    var resolutionNote: String?
    var resolvedAt: Date?
    var createdAt: Date
    var updatedAt: Date?

    var targetTypeTitle: String {
        ContentReportTargetType(rawValue: targetType)?.title ?? targetType.replacingOccurrences(of: "_", with: " ")
    }

    var reasonTitle: String {
        ContentReportReason(rawValue: reason)?.title ?? reason.replacingOccurrences(of: "_", with: " ")
    }

    var statusTitle: String {
        switch status {
        case "pending": return LT("待处理", "Pending", "対応待ち")
        case "reviewing", "in_review": return LT("审核中", "In Review", "審査中")
        case "resolved", "accepted": return LT("已处理", "Resolved", "対応済み")
        case "rejected": return LT("未发现违规", "No Violation Found", "違反は確認されませんでした")
        case "closed": return LT("已关闭", "Closed", "終了")
        default: return status.replacingOccurrences(of: "_", with: " ")
        }
    }
}

struct ContentReportAttachment: Codable, Hashable {
    var type: String?
    var url: String?
    var label: String?
}

struct UserBlockStatus: Codable, Hashable {
    var isBlocked: Bool
    var blockedAt: Date?
}

struct UserBlockInput: Encodable, Hashable {
    var reason: String?
    var note: String?
    var source: String
}

struct UserBlockListItem: Codable, Identifiable, Hashable {
    let id: String
    var user: UserSummary
    var reason: String?
    var note: String?
    var source: String?
    var createdAt: Date
    var updatedAt: Date?
}

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var location: String?
    var avatarURL: String?
    var qrCodeURL: String? = nil
    var tags: [String]
    var isFollowersListPublic: Bool
    var isFollowingListPublic: Bool
    var canViewFollowersList: Bool
    var canViewFollowingList: Bool
    var followersCount: Int
    var followingCount: Int
    var friendsCount: Int
    var postsCount: Int
    var isFollowing: Bool?
    var isFriend: Bool?
}

struct ProfileBootstrapResponse: Codable {
    var profile: UserProfile
    var appearance: UserAssetAppearance
    var recentCheckins: [WebCheckin]
}

struct Post: Codable, Identifiable, Hashable {
    let id: String
    var author: UserSummary
    var content: String
    var images: [String]
    var location: String?
    var eventID: String?
    var boundDjIDs: [String]
    var boundBrandIDs: [String]
    var boundEventIDs: [String]
    var squad: PostSquad?
    var createdAt: Date
    var displayPublishedAt: Date?
    var likeCount: Int
    var repostCount: Int
    var saveCount: Int
    var shareCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isReposted: Bool
    var isSaved: Bool
    var isHidden: Bool
    var recommendationReasonCode: String?
    var recommendationReason: String?

    init(
        id: String,
        author: UserSummary,
        content: String,
        images: [String],
        location: String? = nil,
        eventID: String? = nil,
        boundDjIDs: [String] = [],
        boundBrandIDs: [String] = [],
        boundEventIDs: [String] = [],
        squad: PostSquad? = nil,
        createdAt: Date,
        displayPublishedAt: Date? = nil,
        likeCount: Int,
        repostCount: Int,
        saveCount: Int = 0,
        shareCount: Int = 0,
        commentCount: Int,
        isLiked: Bool,
        isReposted: Bool,
        isSaved: Bool = false,
        isHidden: Bool = false,
        recommendationReasonCode: String? = nil,
        recommendationReason: String? = nil
    ) {
        self.id = id
        self.author = author
        self.content = content
        self.images = images
        self.location = location
        self.eventID = eventID
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
        self.squad = squad
        self.createdAt = createdAt
        self.displayPublishedAt = displayPublishedAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.saveCount = saveCount
        self.shareCount = shareCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.isReposted = isReposted
        self.isSaved = isSaved
        self.isHidden = isHidden
        self.recommendationReasonCode = recommendationReasonCode
        self.recommendationReason = recommendationReason
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case images
        case location
        case eventID
        case boundDjIDs
        case boundBrandIDs
        case boundEventIDs
        case squad
        case createdAt
        case displayPublishedAt
        case likeCount
        case repostCount
        case saveCount
        case shareCount
        case commentCount
        case isLiked
        case isReposted
        case isSaved
        case isHidden
        case recommendationReasonCode
        case recommendationReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        author = try container.decode(UserSummary.self, forKey: .author)
        content = try container.decode(String.self, forKey: .content)
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location)
        eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
        boundDjIDs = try container.decodeIfPresent([String].self, forKey: .boundDjIDs) ?? []
        boundBrandIDs = try container.decodeIfPresent([String].self, forKey: .boundBrandIDs) ?? []
        boundEventIDs = try container.decodeIfPresent([String].self, forKey: .boundEventIDs) ?? []
        squad = try container.decodeIfPresent(PostSquad.self, forKey: .squad)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        displayPublishedAt = try container.decodeIfPresent(Date.self, forKey: .displayPublishedAt)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount) ?? 0
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        isReposted = try container.decodeIfPresent(Bool.self, forKey: .isReposted) ?? false
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        recommendationReasonCode = try container.decodeIfPresent(String.self, forKey: .recommendationReasonCode)
        recommendationReason = try container.decodeIfPresent(String.self, forKey: .recommendationReason)
    }
}

struct PostSquad: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var avatarURL: String?
}

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let postID: String
    var parentCommentID: String?
    var rootCommentID: String?
    var depth: Int
    var author: UserSummary
    var replyToAuthor: UserSummary?
    var content: String
    var createdAt: Date

    init(
        id: String,
        postID: String,
        parentCommentID: String? = nil,
        rootCommentID: String? = nil,
        depth: Int = 0,
        author: UserSummary,
        replyToAuthor: UserSummary? = nil,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.parentCommentID = parentCommentID
        self.rootCommentID = rootCommentID
        self.depth = depth
        self.author = author
        self.replyToAuthor = replyToAuthor
        self.content = content
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postID
        case parentCommentID
        case rootCommentID
        case depth
        case author
        case replyToAuthor
        case content
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postID = try container.decode(String.self, forKey: .postID)
        parentCommentID = try container.decodeIfPresent(String.self, forKey: .parentCommentID)
        rootCommentID = try container.decodeIfPresent(String.self, forKey: .rootCommentID)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        author = try container.decode(UserSummary.self, forKey: .author)
        replyToAuthor = try container.decodeIfPresent(UserSummary.self, forKey: .replyToAuthor)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    var type: ConversationType
    var title: String
    var avatarURL: String?
    var sdkConversationID: String? = nil
    var lastMessage: String
    var lastMessageSenderID: String?
    var unreadCount: Int
    var updatedAt: Date
    var peer: UserSummary?
    var isPinned: Bool
    var isMuted: Bool
    var unreadMentionType: GroupMentionAlertType = .none

    var previewText: String {
        let baseText: String
        if type == .group, let sender = lastMessageSenderID, !sender.isEmpty {
            baseText = "\(sender): \(lastMessage)"
        } else {
            baseText = lastMessage
        }
        guard unreadMentionType != .none else { return baseText }
        return "\(unreadMentionType.previewPrefix) \(baseText)"
    }

    var hasUnreadMention: Bool {
        unreadMentionType != .none
    }

    init(
        id: String,
        type: ConversationType,
        title: String,
        avatarURL: String?,
        sdkConversationID: String? = nil,
        lastMessage: String,
        lastMessageSenderID: String?,
        unreadCount: Int,
        updatedAt: Date,
        peer: UserSummary?,
        isPinned: Bool = false,
        isMuted: Bool = false,
        unreadMentionType: GroupMentionAlertType = .none
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.avatarURL = avatarURL
        self.sdkConversationID = sdkConversationID
        self.lastMessage = lastMessage
        self.lastMessageSenderID = lastMessageSenderID
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
        self.peer = peer
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.unreadMentionType = unreadMentionType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case avatarURL
        case sdkConversationID
        case lastMessage
        case lastMessageSenderID
        case unreadCount
        case updatedAt
        case peer
        case isPinned
        case isMuted
        case unreadMentionType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ConversationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        sdkConversationID = try container.decodeIfPresent(String.self, forKey: .sdkConversationID)
        lastMessage = try container.decode(String.self, forKey: .lastMessage)
        lastMessageSenderID = try container.decodeIfPresent(String.self, forKey: .lastMessageSenderID)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        peer = try container.decodeIfPresent(UserSummary.self, forKey: .peer)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        unreadMentionType = try container.decodeIfPresent(GroupMentionAlertType.self, forKey: .unreadMentionType) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(sdkConversationID, forKey: .sdkConversationID)
        try container.encode(lastMessage, forKey: .lastMessage)
        try container.encodeIfPresent(lastMessageSenderID, forKey: .lastMessageSenderID)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(peer, forKey: .peer)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(unreadMentionType, forKey: .unreadMentionType)
    }
}

enum GroupMentionAlertType: Int, Codable, Hashable {
    case none = 0
    case atMe = 1
    case atAll = 2
    case atAllAndMe = 3

    var previewPrefix: String {
        switch self {
        case .none:
            return ""
        case .atMe:
            return LT("[@你]", "[@You]", "[@あなた]")
        case .atAll:
            return LT("[@所有人]", "[@All]", "[@全員]")
        case .atAllAndMe:
            return LT("[@你][@所有人]", "[@You][@All]", "[@あなた][@全員]")
        }
    }
}

enum ChatMessageKind: String, Codable, Hashable, CaseIterable {
    case text
    case image
    case video
    case voice
    case file
    case emoji
    case location
    case card
    case custom
    case system
    case typing
    case unknown
}

enum ChatMessageDeliveryStatus: String, Codable, Hashable, CaseIterable {
    case sending
    case sent
    case failed
}

struct ChatMessageMediaPayload: Codable, Hashable {
    var mediaURL: String? = nil
    var thumbnailURL: String? = nil
    var width: Double? = nil
    var height: Double? = nil
    var durationSeconds: Int? = nil
    var fileName: String? = nil
    var fileSizeBytes: Int? = nil
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationID: String
    var sender: UserSummary
    var content: String
    var createdAt: Date
    var isMine: Bool
    var kind: ChatMessageKind = .text
    var media: ChatMessageMediaPayload? = nil
    var deliveryStatus: ChatMessageDeliveryStatus = .sent
    var deliveryError: String? = nil
    var replyToMessageID: String? = nil
    var replyPreview: String? = nil
    var mentionedUserIDs: [String] = []
    var peerRead: Bool? = nil
    var readReceiptReadCount: Int? = nil
    var readReceiptUnreadCount: Int? = nil

    init(
        id: String,
        conversationID: String,
        sender: UserSummary,
        content: String,
        createdAt: Date,
        isMine: Bool,
        kind: ChatMessageKind = .text,
        media: ChatMessageMediaPayload? = nil,
        deliveryStatus: ChatMessageDeliveryStatus = .sent,
        deliveryError: String? = nil,
        replyToMessageID: String? = nil,
        replyPreview: String? = nil,
        mentionedUserIDs: [String] = [],
        peerRead: Bool? = nil,
        readReceiptReadCount: Int? = nil,
        readReceiptUnreadCount: Int? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sender = sender
        self.content = content
        self.createdAt = createdAt
        self.isMine = isMine
        self.kind = kind
        self.media = media
        self.deliveryStatus = deliveryStatus
        self.deliveryError = deliveryError
        self.replyToMessageID = replyToMessageID
        self.replyPreview = replyPreview
        self.mentionedUserIDs = mentionedUserIDs
        self.peerRead = peerRead
        self.readReceiptReadCount = readReceiptReadCount
        self.readReceiptUnreadCount = readReceiptUnreadCount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case sender
        case content
        case createdAt
        case isMine
        case kind
        case media
        case deliveryStatus
        case deliveryError
        case replyToMessageID
        case replyPreview
        case mentionedUserIDs
        case peerRead
        case readReceiptReadCount
        case readReceiptUnreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationID = try container.decode(String.self, forKey: .conversationID)
        sender = try container.decode(UserSummary.self, forKey: .sender)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isMine = try container.decode(Bool.self, forKey: .isMine)
        kind = try container.decodeIfPresent(ChatMessageKind.self, forKey: .kind) ?? .text
        media = try container.decodeIfPresent(ChatMessageMediaPayload.self, forKey: .media)
        deliveryStatus = try container.decodeIfPresent(ChatMessageDeliveryStatus.self, forKey: .deliveryStatus) ?? .sent
        deliveryError = try container.decodeIfPresent(String.self, forKey: .deliveryError)
        replyToMessageID = try container.decodeIfPresent(String.self, forKey: .replyToMessageID)
        replyPreview = try container.decodeIfPresent(String.self, forKey: .replyPreview)
        mentionedUserIDs = try container.decodeIfPresent([String].self, forKey: .mentionedUserIDs) ?? []
        peerRead = try container.decodeIfPresent(Bool.self, forKey: .peerRead)
        readReceiptReadCount = try container.decodeIfPresent(Int.self, forKey: .readReceiptReadCount)
        readReceiptUnreadCount = try container.decodeIfPresent(Int.self, forKey: .readReceiptUnreadCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(sender, forKey: .sender)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isMine, forKey: .isMine)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(media, forKey: .media)
        try container.encode(deliveryStatus, forKey: .deliveryStatus)
        try container.encodeIfPresent(deliveryError, forKey: .deliveryError)
        try container.encodeIfPresent(replyToMessageID, forKey: .replyToMessageID)
        try container.encodeIfPresent(replyPreview, forKey: .replyPreview)
        try container.encode(mentionedUserIDs, forKey: .mentionedUserIDs)
        try container.encodeIfPresent(peerRead, forKey: .peerRead)
        try container.encodeIfPresent(readReceiptReadCount, forKey: .readReceiptReadCount)
        try container.encodeIfPresent(readReceiptUnreadCount, forKey: .readReceiptUnreadCount)
    }
}

struct FeedPage: Codable {
    let posts: [Post]
    let nextCursor: String?
}

struct EventLiveComment: Codable, Identifiable, Hashable {
    let id: String
    let eventID: String
    var parentCommentID: String?
    var rootCommentID: String?
    var depth: Int
    var author: UserSummary
    var replyToAuthor: UserSummary?
    var content: String
    var imageURLs: [String]
    var likeCount: Int
    var isLiked: Bool
    var createdAt: Date

    init(
        id: String,
        eventID: String,
        parentCommentID: String? = nil,
        rootCommentID: String? = nil,
        depth: Int = 0,
        author: UserSummary,
        replyToAuthor: UserSummary? = nil,
        content: String,
        imageURLs: [String] = [],
        likeCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.eventID = eventID
        self.parentCommentID = parentCommentID
        self.rootCommentID = rootCommentID
        self.depth = depth
        self.author = author
        self.replyToAuthor = replyToAuthor
        self.content = content
        self.imageURLs = imageURLs
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case eventID
        case parentCommentID
        case rootCommentID
        case depth
        case author
        case replyToAuthor
        case content
        case imageURLs
        case imageUrls
        case likeCount
        case isLiked
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        eventID = try container.decode(String.self, forKey: .eventID)
        parentCommentID = try container.decodeIfPresent(String.self, forKey: .parentCommentID)
        rootCommentID = try container.decodeIfPresent(String.self, forKey: .rootCommentID)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        author = try container.decode(UserSummary.self, forKey: .author)
        replyToAuthor = try container.decodeIfPresent(UserSummary.self, forKey: .replyToAuthor)
        content = try container.decode(String.self, forKey: .content)
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
            ?? container.decodeIfPresent([String].self, forKey: .imageUrls)
            ?? []
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventID, forKey: .eventID)
        try container.encodeIfPresent(parentCommentID, forKey: .parentCommentID)
        try container.encodeIfPresent(rootCommentID, forKey: .rootCommentID)
        try container.encode(depth, forKey: .depth)
        try container.encode(author, forKey: .author)
        try container.encodeIfPresent(replyToAuthor, forKey: .replyToAuthor)
        try container.encode(content, forKey: .content)
        try container.encode(imageURLs, forKey: .imageURLs)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(isLiked, forKey: .isLiked)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct EventLiveCommentPage: Codable {
    let comments: [EventLiveComment]
    let nextCursor: String?
}

struct EventLiveCommentCreateRequest: Codable {
    let content: String
    let imageURLs: [String]
    let parentCommentID: String?
}

enum EventLiveCommentSortMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case hot
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot: return LT("热度", "Hot", "人気")
        case .newest: return LT("最新", "Newest", "最新")
        case .oldest: return LT("最早", "Oldest", "古い順")
        }
    }
}

struct FeedEventInput: Codable {
    let sessionID: String
    let eventType: String
    var postID: String?
    var feedMode: FeedMode?
    var position: Int?
    var metadata: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case eventType
        case postID
        case feedMode
        case position
        case metadata
    }
}

struct FollowListPage: Codable {
    let users: [UserSummary]
    let nextCursor: String?
}

struct CreatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?
    var boundDjIDs: [String]
    var boundBrandIDs: [String]
    var boundEventIDs: [String]

    init(
        content: String,
        images: [String],
        location: String? = nil,
        boundDjIDs: [String] = [],
        boundBrandIDs: [String] = [],
        boundEventIDs: [String] = []
    ) {
        self.content = content
        self.images = images
        self.location = location
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
    }
}

struct UpdatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?
    var boundDjIDs: [String]?
    var boundBrandIDs: [String]?
    var boundEventIDs: [String]?

    init(
        content: String,
        images: [String],
        location: String? = nil,
        boundDjIDs: [String]? = nil,
        boundBrandIDs: [String]? = nil,
        boundEventIDs: [String]? = nil
    ) {
        self.content = content
        self.images = images
        self.location = location
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
    }
}

struct UpdateMyProfileInput: Codable {
    var displayName: String
    var bio: String
    var location: String?
    var tags: [String]
    var isFollowersListPublic: Bool
    var isFollowingListPublic: Bool

    init(
        displayName: String,
        bio: String,
        location: String? = nil,
        tags: [String],
        isFollowersListPublic: Bool,
        isFollowingListPublic: Bool
    ) {
        self.displayName = displayName
        self.bio = bio
        self.location = location
        self.tags = tags
        self.isFollowersListPublic = isFollowersListPublic
        self.isFollowingListPublic = isFollowingListPublic
    }
}

struct AvatarUploadResponse: Codable {
    let avatarURL: String
}

struct ActivityPostItem: Codable, Identifiable, Hashable {
    var actionAt: Date
    var post: Post

    var id: String {
        "\(post.id)_\(actionAt.timeIntervalSince1970)"
    }
}

struct ActivityPostPage: Codable {
    let items: [ActivityPostItem]
    let nextCursor: String?
}

struct SquadSummary: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var avatarURL: String?
    var bannerURL: String?
    var isPublic: Bool
    var memberCount: Int
    var isMember: Bool
    var lastMessage: String?
    var updatedAt: Date
}

struct SquadMessagePreview: Codable, Identifiable, Hashable {
    let id: String
    var content: String
    var createdAt: Date
    var sender: UserSummary
}

struct SquadMemberProfile: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var isFollowing: Bool
    var role: String
    var nickname: String?
    var isCaptain: Bool
    var isAdmin: Bool

    var shownName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? displayName : trimmed
    }
}

struct SquadActivityItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var location: String?
    var date: Date
    var createdBy: UserSummary
}

struct SquadProfile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var avatarURL: String?
    var bannerURL: String?
    var notice: String
    var qrCodeURL: String?
    var isPublic: Bool
    var maxMembers: Int
    var memberCount: Int
    var isMember: Bool
    var canEditGroup: Bool
    var myRole: String?
    var myNickname: String?
    var myNotificationsEnabled: Bool?
    var leader: UserSummary
    var members: [SquadMemberProfile]
    var lastMessage: String?
    var updatedAt: Date
    var recentMessages: [SquadMessagePreview]
    var activities: [SquadActivityItem]
}

struct UpdateSquadMySettingsInput: Codable {
    var nickname: String?
    var notificationsEnabled: Bool
}

struct UpdateSquadInfoInput: Codable {
    var name: String
    var description: String
    var isPublic: Bool?
    var avatarURL: String?
    var bannerURL: String?
    var notice: String
    var qrCodeURL: String?
}

struct CreateSquadInput: Codable {
    var name: String?
    var description: String?
    var isPublic: Bool
    var bannerURL: String?
    var memberIds: [String]
}

enum AppNotificationType: String, Codable, Hashable {
    case follow
    case like
    case comment
    case squadInvite = "squad_invite"

    var title: String {
        switch self {
        case .follow: return LT("关注", "Follow", "フォロー")
        case .like: return LT("点赞", "Like", "いいね")
        case .comment: return LT("评论", "Comment", "コメント")
        case .squadInvite: return LT("小队邀请", "Squad Invite", "Squad招待")
        }
    }

    var iconName: String {
        switch self {
        case .follow: return "person.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "text.bubble.fill"
        case .squadInvite: return "person.3.fill"
        }
    }
}

struct FollowedEventsSummary: Codable, Hashable {
    var unreadCount: Int
    var latestItemPreview: String?
    var latestOccurredAt: Date?

    static let empty = FollowedEventsSummary(
        unreadCount: 0,
        latestItemPreview: nil,
        latestOccurredAt: nil
    )
}

struct ContentReviewSummary: Codable, Hashable {
    var unreadCount: Int
    var latestItemPreview: String?
    var latestOccurredAt: Date?

    static let empty = ContentReviewSummary(
        unreadCount: 0,
        latestItemPreview: nil,
        latestOccurredAt: nil
    )
}

struct ContentReviewNotificationItem: Codable, Identifiable, Hashable {
    let id: String
    var submissionId: String
    var entityType: String
    var status: String
    var title: String
    var body: String
    var reason: String?
    var createdEntityId: String?
    var isRead: Bool
    var occurredAt: Date

    var isApproved: Bool {
        status == "approved"
    }
}

struct FollowedEventNotificationItem: Codable, Identifiable, Hashable {
    let id: String
    var type: String
    var eventID: String
    var eventName: String
    var newsID: String
    var newsTitle: String
    var newsSummary: String?
    var newsCoverImageURL: String?
    var isRead: Bool
    var occurredAt: Date

    var previewText: String {
        let trimmedSummary = newsSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSummary.isEmpty {
            return trimmedSummary
        }
        return newsTitle
    }
}

struct FollowedDJsSummary: Codable, Hashable {
    var unreadCount: Int
    var latestItemPreview: String?
    var latestOccurredAt: Date?

    static let empty = FollowedDJsSummary(
        unreadCount: 0,
        latestItemPreview: nil,
        latestOccurredAt: nil
    )
}

struct FollowedDJNotificationItem: Codable, Identifiable, Hashable {
    let id: String
    var type: String
    var djID: String
    var djName: String
    var newsID: String
    var newsTitle: String
    var newsSummary: String?
    var newsCoverImageURL: String?
    var isRead: Bool
    var occurredAt: Date

    var previewText: String {
        let trimmedSummary = newsSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSummary.isEmpty {
            return trimmedSummary
        }
        return newsTitle
    }
}

struct FollowedBrandUpdatePreference: Codable, Hashable {
    var enabled: Bool
    var reminderHours: [Int]
    var timezone: String
    var channels: [String]
    var watchedBrandIds: [String]
    var includeInfos: Bool
    var includeEvents: Bool

    static let empty = FollowedBrandUpdatePreference(
        enabled: false,
        reminderHours: [],
        timezone: TimeZone.current.identifier,
        channels: [],
        watchedBrandIds: [],
        includeInfos: true,
        includeEvents: true
    )
}

struct FollowedBrandUpdatePreferenceInput: Codable, Hashable {
    var enabled: Bool?
    var reminderHours: [Int]?
    var timezone: String?
    var channels: [String]?
    var watchedBrandIds: [String]?
    var includeInfos: Bool?
    var includeEvents: Bool?
}

struct NotificationCategoryPreference: Codable, Identifiable, Hashable {
    var category: String
    var enabled: Bool

    var id: String { category }
}

struct NotificationCategoryPreferencesInput: Codable, Hashable {
    var preferences: [NotificationCategoryPreference]
}

struct FollowedBrandsSummary: Codable, Hashable {
    var unreadCount: Int
    var latestItemPreview: String?
    var latestOccurredAt: Date?

    static let empty = FollowedBrandsSummary(
        unreadCount: 0,
        latestItemPreview: nil,
        latestOccurredAt: nil
    )
}

struct FollowedBrandNotificationItem: Codable, Identifiable, Hashable {
    let id: String
    var type: String
    var brandID: String
    var brandName: String
    var newsID: String
    var newsTitle: String
    var newsSummary: String?
    var newsCoverImageURL: String?
    var isRead: Bool
    var occurredAt: Date

    var previewText: String {
        let trimmedSummary = newsSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSummary.isEmpty {
            return trimmedSummary
        }
        return newsTitle
    }
}

struct AppNotificationTarget: Codable, Hashable {
    var type: String
    var id: String
    var title: String?
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: String
    var type: AppNotificationType
    var createdAt: Date
    var isRead: Bool
    var actor: UserSummary?
    var text: String
    var target: AppNotificationTarget?
}

struct NotificationInbox: Codable {
    var unreadCount: Int
    var items: [AppNotification]
}

struct NotificationUnreadCount: Codable {
    var total: Int
    var follows: Int
    var likes: Int
    var comments: Int
    var squadInvites: Int
}

extension Post {
    static let raverNewsMarker = "#RAVER_NEWS"

    var isRaverNews: Bool {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(Self.raverNewsMarker)
    }

    var raverNewsTitle: String {
        raverNewsValue(for: ["标题", "title"]) ?? LT("未命名资讯", "Untitled News", "無題のニュース")
    }

    var raverNewsSource: String {
        raverNewsValue(for: ["来源", "source"]) ?? LT("社区投稿", "Community Submission", "コミュニティ投稿")
    }

    var raverNewsSummary: String {
        raverNewsValue(for: ["摘要", "summary"]) ?? LT("暂无摘要", "No Summary", "概要なし")
    }

    private func raverNewsValue(for keys: [String]) -> String? {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            for key in keys {
                let prefixes = ["\(key)：", "\(key):", "\(key.uppercased())：", "\(key.uppercased()):"]
                if let prefix = prefixes.first(where: { line.hasPrefix($0) }) {
                    let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        return value
                    }
                }
            }
        }

        return nil
    }
}
