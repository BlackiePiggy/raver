import Foundation
import Combine
import OSLog
import UIKit
import AVFoundation
import CryptoKit
#if canImport(ImSDK_Plus)
import ImSDK_Plus
#endif

struct TencentC2CReadReceiptEvent: Equatable {
    let conversationID: String
    let messageID: String?
    let peerRead: Bool
    let readAt: Date?
}

struct TencentMessageRevocationEvent: Equatable {
    let conversationID: String
    let messageID: String
    let displayText: String
}

enum TencentIMIdentity {
    static func normalizePlatformUserIDForProfile(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return raw }
        return decodePlatformUserID(fromTencentIMUserID: normalized) ?? normalized
    }

    static func normalizePlatformSquadID(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return raw }
        return decodePlatformSquadID(fromTencentIMGroupID: normalized) ?? normalized
    }

    static func isTencentIMUserID(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("tu_") || normalized.hasPrefix("c2c_tu_")
    }

    static func isTencentIMSquadGroupID(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("sg_") || normalized.hasPrefix("group_sg_")
    }

    static func decodePlatformUserID(fromTencentIMUserID value: String) -> String? {
        decodeUUID(fromPrefixedValue: value, acceptedPrefixes: ["c2c_tu_", "tu_"])
    }

    static func decodePlatformSquadID(fromTencentIMGroupID value: String) -> String? {
        decodeUUID(fromPrefixedValue: value, acceptedPrefixes: ["group_sg_", "sg_"])
    }

    static func toTencentIMUserID(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("tu_") {
            return normalized
        }
        if normalized.hasPrefix("c2c_") {
            let stripped = String(normalized.dropFirst(4))
            return stripped.hasPrefix("tu_") ? stripped : "tu_\(stripped)"
        }
        return "tu_\(toStableShortID(normalized))"
    }

    static func toTencentIMSquadGroupID(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("sg_") {
            return normalized
        }
        if normalized.hasPrefix("group_") {
            let stripped = String(normalized.dropFirst(6))
            return stripped.hasPrefix("sg_") ? stripped : "sg_\(stripped)"
        }
        return "sg_\(toStableShortID(normalized))"
    }

    private static func toStableShortID(_ value: String) -> String {
        if let uuidData = toCompactUUIDData(value) {
            return base64URLEncodedString(uuidData)
        }
        let digest = SHA256.hash(data: Data(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8))
        let hashData = Data(digest)
        return String(base64URLEncodedString(hashData).prefix(22))
    }

    private static func toCompactUUIDData(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let parsed = UUID(uuidString: trimmed) {
            return withUnsafeBytes(of: parsed.uuid) { Data($0) }
        }
        let compact = trimmed.replacingOccurrences(of: "-", with: "")
        guard compact.count == 32,
              compact.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }) else {
            return nil
        }
        var data = Data(capacity: 16)
        var index = compact.startIndex
        for _ in 0..<16 {
            let next = compact.index(index, offsetBy: 2)
            let byteString = compact[index..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    private static func base64URLEncodedString(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeUUID(fromPrefixedValue value: String, acceptedPrefixes: [String]) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = acceptedPrefixes.first(where: { normalized.hasPrefix($0) }) else { return nil }
        let compact = String(normalized.dropFirst(prefix.count))
        guard compact.count == 22 || compact.count == 24 else { return nil }

        var base64 = compact
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64), data.count == 16 else { return nil }
        let bytes = [UInt8](data)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        guard hex.count == 32 else { return nil }

        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }
}

enum AppLanguage: String, CaseIterable, Codable, Hashable, Identifiable {
    case system
    case zh
    case en

    var id: String { rawValue }

    var title: String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            switch self {
            case .system: return "跟随系统"
            case .zh: return "中文"
            case .en: return "English"
            }
        case .en, .system:
            switch self {
            case .system: return "System"
            case .zh: return "Chinese"
            case .en: return "English"
            }
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.preferredLanguages.first ?? "zh-Hans"
        case .zh:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }

    var effectiveLanguage: AppLanguage {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("zh") ? .zh : .en
        case .zh, .en:
            return self
        }
    }
}

enum AppAppearance: String, CaseIterable, Codable, Hashable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L("跟随系统", "System")
        case .light:
            return L("浅色", "Light")
        case .dark:
            return L("深色", "Dark")
        }
    }
}

@inline(__always)
func L(_ zh: String, _ en: String) -> String {
    AppLanguagePreference.current.effectiveLanguage == .en ? en : zh
}

private enum AppLocalizedText {
    static let enMap: [String: String] = [
        "DJ 不存在": "DJ does not exist",
        "DJ 名称": "DJ name",
        "DJ 名称（必填）": "DJ name (required)",
        "Discogs 候选结果": "Discogs candidate results",
        "Instagram（可选）": "Instagram (optional)",
        "JSON 导入文本（Coze 格式）": "JSON import text (Coze format)",
        "Set 不存在": "Set does not exist",
        "Sets 加载中...": "Sets Loading...",
        "SoundCloud（可选）": "SoundCloud (optional)",
        "Spotify ID（可选）": "Spotify ID (optional)",
        "Spotify 导入": "Spotify import",
        "Spotify 链接（可选）": "Spotify link (optional)",
        "Tag（逗号分隔）": "Tags (comma separated)",
        "Tracklist 标题": "Tracklist title",
        "X/Twitter（可选）": "X/Twitter (optional)",
        "— 其他登录方式 —": "— Other login methods —",
        "一键清空已添加 DJ": "Clear added DJs with one click",
        "一键登录/注册": "One-click login/registration",
        "上传": "upload",
        "上传失败": "Upload failed",
        "上传封面": "Upload cover",
        "上传我的 Tracklist": "Upload my Tracklist",
        "上传活动封面图": "Upload event cover image",
        "上传活动阵容图": "Upload event lineup map",
        "上传视频到资源库": "Upload video to resource library",
        "不填则使用默认名称": "If left blank, use the default name.",
        "举办频次": "Frequency of holding",
        "事件名称": "event name",
        "事件描述（选填）": "Event description (optional)",
        "事件驱动打分": "event driven scoring",
        "仅支持从系统相册选择图片；保存后将上传并绑定到该活动。": "Only supports selecting pictures from the system album; after saving, they will be uploaded and bound to the event.",
        "从可视化生成文本": "Generate text from visualizations",
        "从活动库搜索并绑定": "Search and bind from active library",
        "从用户主页发起私信或加入小队后会显示在这里": "After you send a private message or join a team from the user's homepage, it will be displayed here.",
        "从相册选择小队头像": "Select squad avatar from album",
        "从相册选择旗帜图": "Select flag image from album",
        "价格": "price",
        "位置地图": "location map",
        "使用手动名称": "Use manual name",
        "例如：我的版本": "For example: my version",
        "候选结果": "Candidate results",
        "允许他人查看我的关注列表": "Allow others to view my watchlist",
        "允许他人查看我的粉丝列表": "Allow others to view my follower list",
        "先去打个招呼吧": "Let's go say hello first.",
        "先看看": "Take a look first",
        "先粘贴文本并解析，或手动新增 Track。": "Paste the text and parse it first, or add a track manually.",
        "关联 Spotify（可选）": "Connect to Spotify (optional)",
        "其他手机号登录": "Log in with other mobile phone numbers",
        "其他演出": "Other performances",
        "内容": "content",
        "写评论...": "Write a review...",
        "写评论…": "Write a review…",
        "分": "point",
        "分享这一刻...": "Share this moment...",
        "分类": "Classification",
        "创始人": "Founder",
        "创建": "create",
        "删除": "delete",
        "删除 Set": "Delete Set",
        "删除动态": "Delete updates",
        "删除活动": "Delete activity",
        "别名（英文逗号分隔）": "Aliases (comma separated)",
        "加载地图中...": "Loading map...",
        "加载更多即将开始": "Loading more will start soon",
        "加载更多资讯": "Load more information",
        "动态详情": "动态详情",
        "单位信息": "Unit information",
        "单位名称": "Unit name",
        "单位描述（选填）": "Unit description (optional)",
        "厂牌加载中...": "Brand loading...",
        "厂牌详情": "Brand details",
        "原文链接": "Original link",
        "去发现页完成活动或 DJ 打卡，记录会按你选择的观演时间展示。": "Go to the discovery page to complete activities or DJ check-ins, and the records will be displayed according to the viewing time you selected.",
        "去活动打卡": "Check in at the event",
        "参演 DJ": "Participating DJ",
        "双方互相关注后会出现在这里": "Both parties will appear here after paying attention to each other",
        "发布": "release",
        "发布新活动": "Post a new event",
        "发布方": "publisher",
        "发布类型": "Release type",
        "发布资讯": "Publish information",
        "发送评论": "发送评论",
        "同步中...": "Syncing...",
        "名称": "name",
        "启用多 Week 时间表": "Enable multiple Week schedules",
        "国家": "nation",
        "国家（可选）": "Country (optional)",
        "图片": "picture",
        "图片 URL（选填）": "Image URL (optional)",
        "图片加载失败": "Image loading failed",
        "图片（上传到 OSS 的 DJ 文件夹）": "Pictures (uploaded to DJ folder in OSS)",
        "地图选点": "Map point selection",
        "场地": "site",
        "场地定位": "Site positioning",
        "城市": "City",
        "基础": "Base",
        "基础信息": "Basic information",
        "填入 Demo 视频": "Fill in Demo video",
        "复制地址": "Copy address",
        "外链（选填）": "External links (optional)",
        "失败": "fail",
        "头像 URL（可选）": "Avatar URL (optional)",
        "头像上传中...": "Avatar uploading...",
        "如: Techno, House": "Such as: Techno, House",
        "媒体": "media",
        "学习内容加载中...": "Learning content is loading...",
        "完成": "Finish",
        "官网链接": "Official website link",
        "官网链接（可选）": "Official website link (optional)",
        "定位": "position",
        "定位信息": "Positioning information",
        "定位标签": "Positioning tags",
        "定制路线": "Customized route",
        "导入 DJ": "Import DJ",
        "导入方式": "Import method",
        "导入草稿（可编辑）": "Import draft (editable)",
        "封面": "cover",
        "封面 URL": "Cover URL",
        "封面 URL（选填）": "Cover URL (optional)",
        "封面图": "cover image",
        "封面图 URL（选填）": "Cover image URL (optional)",
        "小队": "squad",
        "小队不存在": "The team does not exist",
        "小队二维码": "Team QR code",
        "小队二维码 URL（可选）": "Squad QR code URL (optional)",
        "小队名称": "Team name",
        "小队名称（可选）": "Squad name (optional)",
        "小队性质": "Team nature",
        "小队性质（必选）": "Team nature (required)",
        "小队成员": "team member",
        "小队旗帜图（可选，用于小队卡片背景）": "Squad flag image (optional, used for squad card background)",
        "小队活动": "Team activities",
        "小队简介（可选）": "Team introduction (optional)",
        "小队详情": "Squad details",
        "小队通知": "Squad notification",
        "小队通知内容": "Team notification content",
        "尚未在地图选择定位，仍可仅使用手动输入地址。": "If you haven't selected a location on the map yet, you can still just enter the address manually.",
        "尚未添加 DJ，点击上方按钮新增。": "No DJ has been added yet, click the button above to add it.",
        "展示": "exhibit",
        "已启用后，DJ 时间可按 WeekN · DayN 选择；未启用则按 DayN 选择。": "When enabled, DJ time can be selected by WeekN · DayN; when not enabled, DJ time can be selected by DayN.",
        "已添加阵容": "Lineup added",
        "已选定位": "Targeting selected",
        "已选择本地单位图，保存时会自动上传并使用该图片。": "A local unit image has been selected and will be automatically uploaded and used when saving.",
        "已选择本地图片，发布时会自动上传并作为打分单位封面。": "A local image has been selected and will be automatically uploaded and used as the cover of the scoring unit when publishing.",
        "已选择本地封面图，保存时会自动上传并使用该图片。": "A local cover image has been selected and will be automatically uploaded and used when saving.",
        "已选择本地封面图，发布时会自动上传并使用该图片。": "A local cover image has been selected and will be automatically uploaded and used when publishing.",
        "币种": "Currency",
        "平台信息": "Platform information",
        "库里没有时可手动输入": "If it is not available in the library, it can be entered manually.",
        "开始时间（如 0:00）": "Start time (e.g. 0:00)",
        "当前 Set 信息": "Current Set information",
        "当前 Tracklist 信息": "Current Tracklist information",
        "当前仅支持原生直连媒体地址（mp4/mov/webm/m3u8）。": "Currently only native direct media addresses (mp4/mov/webm/m3u8) are supported.",
        "当前歌单文本（已填充）": "Current playlist text (filled in)",
        "当前绑定": "current binding",
        "当日暂无活动": "There are no activities on that day",
        "成为第一个发帖的人，开始你的社群互动。": "Be the first to post and start your community interaction.",
        "我发布的打分事件": "Scoring events I posted",
        "我发布的打分单位": "The scoring unit I published",
        "我同意《用户服务条款》《用户协议》《隐私政策》": "I agree to the \"User Terms of Service\", \"User Agreement\" and \"Privacy Policy\"",
        "我的小队设置": "My squad settings",
        "我的活动历史": "My activity history",
        "手动填写": "Fill in manually",
        "手动填写 DJ 信息": "Manually fill in DJ information",
        "手动填写活动名称": "Manually fill in event name",
        "打分": "Score",
        "打分事件详情": "Scoring event details",
        "打卡方式": "Check-in method",
        "打开地图App": "Open the map app",
        "批量粘贴": "Batch paste",
        "描述（选填）": "Description (optional)",
        "搜索": "search",
        "搜索 DJ 中...": "Searching for DJ...",
        "搜索 Discogs Artist": "Search Discogs Artist",
        "搜索 Sets / DJ": "Search Sets / DJ",
        "搜索 Spotify DJ": "Search Spotify DJ",
        "搜索 Spotify 用于补全链接": "Search Spotify for link completion",
        "搜索厂牌名 / 简介": "Search brand name / introduction",
        "搜索地点": "Search places",
        "搜索活动中...": "Search active...",
        "搜索电音节名 / 城市 / 国家": "Search electronic syllable name / city / country",
        "搜索结果": "Search results",
        "支持 Coze 返回格式：`normalized_text + lineup_info`，也支持直接粘贴数组。": "Supports Coze return format: `normalized_text + lineup_info`, and also supports direct pasting of arrays.",
        "收到新的关注、点赞、评论或小队邀请后会显示在这里": "New follows, likes, comments or squad invitations will appear here.",
        "新增 DJ（点击右侧勾勾后并入下方列表）": "Add a new DJ (click the check mark on the right to merge it into the list below)",
        "新增 Track": "Add Track",
        "新增电音节": "Added electronic music festival",
        "新增舞台": "Add new stage",
        "旗帜图 URL（可选）": "Flag image URL (optional)",
        "旗帜图上传中...": "Flag image is uploading...",
        "无法直接播放该视频地址": "The video address cannot be played directly",
        "时间": "time",
        "昵称": "Nick name",
        "显示名（可选）": "Display name (optional)",
        "暂无 DJ": "No DJ yet",
        "暂无 Tracklist": "No Tracklist yet",
        "暂无候选，可切换到手动导入。": "There are no candidates yet, you can switch to manual import.",
        "暂无候选，可继续搜索或切换到手动导入。": "There are no candidates yet. You can continue searching or switch to manual import.",
        "暂无候选，输入名称后点击搜索。": "There are no candidates yet. Enter the name and click Search.",
        "暂无关联打分": "No related scoring yet",
        "暂无关联活动": "No related activities yet",
        "暂无内容": "暂无内容",
        "暂无动态": "No news yet",
        "暂无匹配电音节": "No matching electronic syllables yet",
        "暂无厂牌": "No brand yet",
        "暂无历史活动": "No historical events yet",
        "暂无发布 Set": "No set released yet",
        "暂无发布打分": "No ratings released yet",
        "暂无发布活动": "No publishing activities yet",
        "暂无发布资讯": "No release information yet",
        "暂无可导入条目，请先识别阵容图或粘贴 JSON 后解析。": "There are currently no entries to import. Please identify the lineup diagram or paste the JSON and then parse it.",
        "暂无对应 Sets": "No corresponding Sets yet",
        "暂无对应打分事件": "There is currently no corresponding scoring event",
        "暂无我的活动": "There are no activities for me yet",
        "暂无榜单": "No list yet",
        "暂无活动": "No activity yet",
        "暂无相关动态": "No related news yet",
        "暂无票档，点击下方按钮添加。": "There is currently no ticket slot, click the button below to add it.",
        "暂无评论": "no comments",
        "暂无资讯": "No information yet",
        "暂无阵容信息": "No lineup information yet",
        "更换头像": "Change avatar",
        "更换横幅": "Change banner",
        "更换背景": "Change background",
        "最新": "up to date",
        "未绑定活动": "Unbound activities",
        "未能精确定位，仍可在地图中拖动查看区域。": "If the precise positioning is not possible, you can still drag the viewing area on the map.",
        "未选择 DJ": "No DJ selected",
        "未选择舞台": "No stage selected",
        "本小队昵称": "Nickname of this team",
        "来源名称": "source name",
        "查看全部": "View all",
        "查看原文链接": "View original link",
        "查看地图": "View map",
        "标题": "title",
        "榜单": "List",
        "榜单为空": "List is empty",
        "榜单分区": "List partition",
        "模式": "model",
        "歌手": "singer",
        "歌曲名": "song title",
        "正在加载事件…": "Loading events…",
        "正在加载关联活动...": "Loading associated activities...",
        "正在加载品牌动态...": "Loading brand updates...",
        "正在加载打分事件…": "Loading scoring events...",
        "正在加载评分单位…": "Loading scoring units…",
        "正在定位场地...": "Locating venue...",
        "正在拉取 Discogs 候选列表...": "Pulling Discogs candidate list...",
        "正在拉取 Spotify 候选列表...": "Pulling Spotify shortlist...",
        "正在搜索 Spotify...": "Searching Spotify...",
        "正在解析位置…": "Resolving location...",
        "正在识别图片并生成导入草稿...": "Recognizing images and generating import drafts...",
        "正在读取 Discogs 详情并自动填充...": "Reading Discogs details and autofilling...",
        "正文": "text",
        "正文（选填）": "Text (optional)",
        "每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`": "每行格式：`0:00~3:30 - 艺术家 - 歌曲名 | Spotify链接(可选) | 网易云链接(可选)`",
        "没有找到匹配活动": "No matching event found",
        "没有找到可导入活动": "No importable activities found",
        "没有更多匹配活动": "No more matching activity",
        "活动不存在": "Activity does not exist",
        "活动介绍": "Activity introduction",
        "活动加载中...": "Activities loading...",
        "活动名称": "Activity name",
        "活动性质": "Nature of activity",
        "活动日历": "events calendar",
        "活动阵容图": "Event lineup chart",
        "流派树": "genre tree",
        "添加": "Add to",
        "添加 DJ": "Add DJ",
        "添加票档": "Add ticket slot",
        "清空全部": "Clear all",
        "清除": "Clear",
        "演出形式": "Performance form",
        "点击右上角 +，在这个事件下发布第一个打分单位。": "Click + in the upper right corner to publish the first scoring unit under this event.",
        "点击右上角“发布事件”，先创建一个事件，再在事件内添加打分单位。": "Click \"Publish Event\" in the upper right corner, first create an event, and then add a scoring unit to the event.",
        "点击右上角“发布资讯”发布图文内容后会显示在这里。": "Click \"Publish Information\" in the upper right corner to publish graphic content and it will be displayed here.",
        "热门": "Popular",
        "用户上传版本": "User uploaded version",
        "用户不存在": "User does not exist",
        "用户名": "username",
        "电音节加载中...": "Electronic music festival loading...",
        "电音节名称": "Electronic syllable name",
        "相关 DJ": "Related DJs",
        "知道了": "knew",
        "确认导入信息": "Confirm import information",
        "确认导入信息（支持二次修改）": "Confirm the import information (supports secondary modification)",
        "票务信息": "Ticket information",
        "票务备注（可选）": "Ticketing notes (optional)",
        "票档信息": "Ticket information",
        "票档名称（如 Early Bird）": "Ticket stall name (e.g. Early Bird)",
        "私信": "private message",
        "移除封面图": "Remove cover image",
        "移除阵容图": "Remove lineup chart",
        "稍后再来看看新的社群": "Check back later for new communities",
        "等待时间表发布": "Waiting for schedule release",
        "签名": "sign",
        "简介": "Introduction",
        "简介（可选）": "Introduction (optional)",
        "绑定到活动（优先）": "Bind to activity (preferred)",
        "绑定活动": "Binding activity",
        "结束时间（可选）": "End time (optional)",
        "编辑": "edit",
        "编辑 DJ": "Edit DJ",
        "编辑 Set": "Edit Set",
        "编辑 Tracklist": "Edit Tracklist",
        "编辑小队信息": "Edit squad information",
        "编辑打分事件": "Edit scoring event",
        "编辑打分单位": "Edit scoring unit",
        "编辑电音节": "Edit electronic syllables",
        "网易云链接（可选）": "NetEase Cloud link (optional)",
        "聊天历史记录": "Chat history",
        "粉丝列表不可见": "Followers list is private",
        "关注列表不可见": "Following list is private",
        "接口返回格式不匹配，请检查 BFF 契约": "Response format mismatch. Please check BFF contract.",
        "接口返回格式不匹配，请检查 Web BFF 契约": "Response format mismatch. Please check Web BFF contract.",
        "权限不足": "Forbidden",
        "请填写正文或添加媒体": "Please enter content or add media.",
        "动态不存在": "Post does not exist.",
        "无权编辑该动态": "No permission to edit this post.",
        "无权删除该动态": "No permission to delete this post.",
        "评论不能为空": "Comment cannot be empty.",
        "请输入用户名": "Please enter a username.",
        "只能从好友列表中选择小队成员": "Squad members can only be selected from friends.",
        "仅小队管理员可修改小队头像": "Only squad admins can update squad avatar.",
        "你还不是小队成员": "You are not a squad member yet.",
        "仅小队管理员可修改小队资料": "Only squad admins can update squad info.",
        "小队名称不能为空": "Squad name cannot be empty.",
        "昵称不能为空": "Nickname cannot be empty.",
        "缓存响应未命中最新数据，请下拉刷新重试": "Cached response is stale. Pull down to refresh.",
        "spotifyId 不能为空": "spotifyId cannot be empty.",
        "discogsArtistId 不能为空": "discogsArtistId cannot be empty.",
        "DJ 名称不能为空": "DJ name cannot be empty.",
        "Tracklist 不存在": "Tracklist does not exist.",
        "Tracklist 至少包含 1 条有效曲目": "Tracklist must include at least 1 valid track.",
        "评论不存在": "Comment does not exist.",
        "type 必须是 event 或 dj": "type must be event or dj.",
        "该活动已打卡，请直接编辑原有记录": "This event is already checked in. Please edit the existing record.",
        "打卡不存在": "Check-in does not exist.",
        "打分事件不存在": "Rating event does not exist.",
        "事件名称不能为空": "Event name cannot be empty.",
        "打分单位名称不能为空": "Rating unit name cannot be empty.",
        "打分单位不存在": "Rating unit does not exist.",
        "请先评分": "Please rate first.",
        "电音节名称不能为空": "Festival name cannot be empty.",
        "电音节不存在": "Festival does not exist.",
        "榜单不存在": "Ranking does not exist.",
        "自动链接": "automatic link",
        "舞台信息": "stage information",
        "视频上传中...": "Video uploading...",
        "视频资源": "Video resources",
        "视频链接（可选）": "Video link (optional)",
        "解析并替换": "parse and replace",
        "解析并追加": "parse and append",
        "认证 DJ": "Certified DJ",
        "评分": "score",
        "评论": "Comment",
        "评论列表": "Comment list",
        "识别完成，可直接修改后一键导入。": "After the recognition is completed, you can modify it directly and import it with one click.",
        "试试不同关键词": "Try different keywords",
        "试试输入更完整的用户名": "Try entering a more complete username",
        "详细地址（手动输入）": "Detailed address (enter manually)",
        "说点什么...": "Say something...",
        "请在搜索或历史中选择一场活动。": "Please select an event in search or history.",
        "请尝试修改关键词，或先创建活动。": "Please try modifying the keywords, or create an event first.",
        "请输入昵称": "Please enter a nickname",
        "读取你的活动历史...": "Read your activity history...",
        "贡献者": "Contributor",
        "购票链接（可选）": "Ticket purchase link (optional)",
        "资讯": "Information",
        "资讯加载中...": "Information loading...",
        "资讯摘要": "Information summary",
        "资讯标题": "Information title",
        "资讯详情": "Information details",
        "输入 DJ 名称": "Enter DJ name",
        "输入旗帜图 URL 或选择本地图片上传": "Enter the flag image URL or select a local image to upload",
        "近期暂无活动": "No recent activity",
        "还没有动态": "No updates yet",
        "还没有打分事件": "There are no rated events yet",
        "还没有打分单位": "No scoring unit yet",
        "还没有消息，加入后来发第一条吧。": "There is no news yet, please join and post the first one.",
        "还没有点赞记录": "There is no like record yet",
        "还没有观演记录": "No performance record yet",
        "还没有评论，来写第一条吧": "There are no comments yet. Be the first one.",
        "还没有评论，来抢沙发吧。": "There are no comments yet, be the first to be the first.",
        "还没有转发记录": "There is no forwarding record yet",
        "这次打卡的 DJ": "The DJ who checked in this time",
        "进入对应电音节活动详情": "Enter the details of the corresponding electronic music festival activities",
        "进入榜单详情": "Enter list details",
        "进小队": "Join the team",
        "选择 Tracklist": "Select Tracklist",
        "选择头像": "Select avatar",
        "选择好友": "Select friends",
        "选择定位": "Select targeting",
        "选择旗帜图": "Select flag chart",
        "选择横幅": "Select banner",
        "选择活动定位": "Select activity targeting",
        "选择版本": "Select version",
        "选择背景": "Select background",
        "通知权限": "Notification permissions",
        "通过 JSON 文本导入": "Import via JSON text",
        "邮箱": "Mail",
        "阵容导入": "Lineup import",
        "预解析视频": "Pre-parsed video",
        "首办时间": "First opening time",
        "默认 Tracklist": "Default Tracklist",
        "默认币种（例如 CNY / USD）": "Default currency (e.g. CNY/USD)",
    ]

    static let zhMap: [String: String] = {
        var mapping: [String: String] = [:]
        for (zh, en) in enMap where mapping[en] == nil {
            mapping[en] = zh
        }
        return mapping
    }()

    @inline(__always)
    static func resolveForCurrentLanguage(_ text: String) -> String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .en:
            return enMap[text] ?? text
        case .zh, .system:
            return zhMap[text] ?? text
        }
    }
}

@inline(__always)
func LL(_ zh: String) -> String {
    AppLocalizedText.resolveForCurrentLanguage(zh)
}

enum AppLanguagePreference {
    private static let key = "raver.app.language"

    static var current: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let value = AppLanguage(rawValue: raw) else {
                return .system
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

enum AppAppearancePreference {
    private static let key = "raver.app.appearance"

    static var current: AppAppearance {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let value = AppAppearance(rawValue: raw) else {
                return .dark
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

struct SystemDeepLinkEvent: Identifiable, Equatable {
    let id = UUID()
    let deeplink: String
    let source: String
}

enum TencentIMConnectionState: Equatable {
    case idle
    case disabled
    case unavailable
    case initializing
    case connecting
    case connected(userID: String)
    case userSigExpired
    case kickedOffline
    case failed(String)
}

#if canImport(ImSDK_Plus)
final class TencentIMAPNSBadgeBridge: NSObject, V2TIMAPNSListener {
    static let shared = TencentIMAPNSBadgeBridge()

    private let lock = NSLock()
    private var unifiedUnreadCount: UInt32 = 0

    func setUnifiedUnreadCount(_ count: Int) {
        lock.lock()
        unifiedUnreadCount = UInt32(max(0, count))
        lock.unlock()
    }

    func onSetAPPUnreadCount() -> UInt32 {
        lock.lock()
        let count = unifiedUnreadCount
        lock.unlock()
        return count
    }
}
#endif

@MainActor
final class TencentIMSession: NSObject {
    static let shared = TencentIMSession()
    private static let loggedInStatusRawValue = 1
    private static let loggedOutStatusRawValue = 3
    private static let infoLogLevelRawValue = 4
    private static let messageStatusSendingRawValue = 1
    private static let messageStatusSentRawValue = 2
    private static let messageStatusFailedRawValue = 3
    private static let messageStatusLocalRevokedRawValue = 6
    private static let elemTypeTextRawValue = 1
    private static let elemTypeCustomRawValue = 2
    private static let elemTypeImageRawValue = 3
    private static let elemTypeSoundRawValue = 4
    private static let elemTypeVideoRawValue = 5
    private static let elemTypeFileRawValue = 6
    private static let elemTypeLocationRawValue = 7
    private static let elemTypeFaceRawValue = 8
    private static let elemTypeGroupTipsRawValue = 9
    private static let elemTypeMergerRawValue = 10
    private static let elemTypeStreamRawValue = 11
    private static let conversationTypeDirectRawValue = 1
    private static let conversationTypeGroupRawValue = 2
    private static let receiveMessageOptRawValue = 0
    private static let receiveNoNotifyRawValue = 2
    private static let typingBusinessID = "user_typing_status"
    private static let customCardBusinessID = "raver_custom_card"

    private struct TencentEventCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: EventShareCardPayload
    }

    private struct TencentDJCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: DJShareCardPayload
    }

    var onStateChange: ((TencentIMConnectionState) -> Void)?
    var onUnreadCountChange: ((Int) -> Void)?
    let messageSubject = PassthroughSubject<ChatMessage, Never>()
    let conversationSubject = PassthroughSubject<[Conversation], Never>()
    let totalUnreadSubject = PassthroughSubject<Int, Never>()
    let c2cReadReceiptSubject = PassthroughSubject<[TencentC2CReadReceiptEvent], Never>()
    let messageRevocationSubject = PassthroughSubject<TencentMessageRevocationEvent, Never>()
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    var conversationPublisher: AnyPublisher<[Conversation], Never> {
        conversationSubject.eraseToAnyPublisher()
    }
    var totalUnreadPublisher: AnyPublisher<Int, Never> {
        totalUnreadSubject.eraseToAnyPublisher()
    }
    var c2cReadReceiptPublisher: AnyPublisher<[TencentC2CReadReceiptEvent], Never> {
        c2cReadReceiptSubject.eraseToAnyPublisher()
    }
    var messageRevocationPublisher: AnyPublisher<TencentMessageRevocationEvent, Never> {
        messageRevocationSubject.eraseToAnyPublisher()
    }

    private(set) var state: TencentIMConnectionState = .idle {
        didSet {
            onStateChange?(state)
        }
    }
    private(set) var unreadCount: Int = 0 {
        didSet {
            guard oldValue != unreadCount else { return }
            onUnreadCountChange?(unreadCount)
        }
    }

    private var hasInitializedSDK = false
    private var hasRegisteredListeners = false
    private var currentBootstrap: TencentIMBootstrap?
    private var currentUserID: String?
    private var latestAPNSTokenData: Data?

    private override init() {
        super.init()
    }

    func updateAPNSToken(hexToken: String) async {
        latestAPNSTokenData = Self.decodeHexAPNSToken(hexToken)
        await applyAPNSConfigurationIfPossible(reason: "token-updated")
    }

    func connectionStateSnapshot() -> TencentIMConnectionState {
        state
    }

    func totalUnreadCountSnapshot() -> Int {
        unreadCount
    }

    func currentBusinessUserIDSnapshot() -> String? {
        currentUserID
    }

    func isBootstrapEnabledSnapshot() -> Bool {
        currentBootstrap?.enabled == true
    }

    func recoverSessionAfterAppBecameActive() async -> Bool {
#if canImport(ImSDK_Plus)
        guard hasInitializedSDK,
              let manager = V2TIMManager.sharedInstance() else { return false }
        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue,
              let userID = manager.getLoginUser(),
              !userID.isEmpty else {
            return false
        }

        currentUserID = userID
        state = .connected(userID: userID)
        await applyAPNSConfigurationIfPossible(reason: "recover-after-active")
        await refreshTotalUnreadCount()
        return true
#else
        false
#endif
    }

    func reset() {
#if canImport(ImSDK_Plus)
        if let manager = V2TIMManager.sharedInstance() {
            if hasRegisteredListeners {
                manager.removeIMSDKListener(listener: self)
                manager.removeConversationListener(listener: self)
                manager.removeAdvancedMsgListener(listener: self)
                hasRegisteredListeners = false
            }
            if hasInitializedSDK {
                manager.unInitSDK()
            }
        }
#endif
        hasInitializedSDK = false
        hasRegisteredListeners = false
        currentBootstrap = nil
        currentUserID = nil
        unreadCount = 0
        state = .idle
    }

    func sync(with bootstrap: TencentIMBootstrap?) async {
        guard let bootstrap else {
            reset()
            return
        }

        currentBootstrap = bootstrap

        guard bootstrap.enabled else {
            reset()
            state = .disabled
            return
        }

        guard bootstrap.sdkAppID > 0 else {
            reset()
            state = .failed("Tencent IM bootstrap missing sdkAppID")
            return
        }

        guard let userSig = bootstrap.userSig, !userSig.isEmpty else {
            reset()
            state = .failed("Tencent IM bootstrap missing userSig")
            return
        }

#if canImport(ImSDK_Plus)
        guard let manager = V2TIMManager.sharedInstance() else {
            state = .unavailable
            return
        }
        state = .initializing

        if !hasInitializedSDK {
            let config = V2TIMSDKConfig()
            config.logLevel = V2TIMLogLevel(rawValue: Self.infoLogLevelRawValue) ?? config.logLevel
            let initialized = manager.initSDK(Int32(bootstrap.sdkAppID), config: config)
            guard initialized else {
                state = .failed("Tencent IM initSDK failed")
                return
            }
            hasInitializedSDK = true
        }

        if !hasRegisteredListeners {
            manager.addIMSDKListener(listener: self)
            manager.addConversationListener(listener: self)
            manager.addAdvancedMsgListener(listener: self)
            hasRegisteredListeners = true
        }

        let loginStatus = manager.getLoginStatus()
        let loginUserID = manager.getLoginUser()
        if loginStatus.rawValue == Self.loggedInStatusRawValue, loginUserID == bootstrap.userID {
            currentUserID = bootstrap.userID
            state = .connected(userID: bootstrap.userID)
            await applyAPNSConfigurationIfPossible(reason: "reuse-existing-login")
            await refreshTotalUnreadCount()
            return
        }

        if loginStatus.rawValue != Self.loggedOutStatusRawValue {
            do {
                try await logout(manager: manager)
            } catch {
                // Continue attempting a clean login with the latest bootstrap.
            }
        }

        state = .connecting
        do {
            try await login(manager: manager, userID: bootstrap.userID, userSig: userSig)
            currentUserID = bootstrap.userID
            state = .connected(userID: bootstrap.userID)
            await applyAPNSConfigurationIfPossible(reason: "fresh-login")
            await refreshTotalUnreadCount()
        } catch {
            state = .failed(error.localizedDescription)
        }
#else
        state = .unavailable
#endif
    }

#if canImport(ImSDK_Plus)
    func fetchConversations(type: ConversationType) async throws -> [Conversation]? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let remote = try await fetchAllConversations(manager: manager)
        return remote.compactMap(mapConversation(_:)).filter { $0.type == type }
    }

    func markConversationRead(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        try await withCheckedThrowingContinuation { continuation in
            manager.cleanConversationUnreadMessageCount(
                conversationID: target.rawConversationID,
                cleanTimestamp: 0,
                cleanSequence: 0
            ) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Mark conversation read failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        try await withCheckedThrowingContinuation { continuation in
            manager.pinConversation(conversationID: target.rawConversationID, isPinned: pinned) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set conversation pinned failed"))
            }
        }
        return true
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let markType = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue)
        try await withCheckedThrowingContinuation { continuation in
            manager.markConversation(
                conversationIDList: [target.rawConversationID],
                markType: markType,
                enableMark: unread
            ) { _ in
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Mark conversation unread failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func hideConversation(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let markType = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue)
        try await withCheckedThrowingContinuation { continuation in
            manager.markConversation(
                conversationIDList: [target.rawConversationID],
                markType: markType,
                enableMark: true
            ) { _ in
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Hide conversation failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let receiveOpt = V2TIMReceiveMessageOpt(
            rawValue: muted ? Self.receiveNoNotifyRawValue : Self.receiveMessageOptRawValue
        ) ?? V2TIMReceiveMessageOpt(rawValue: Self.receiveMessageOptRawValue)

        guard let opt = receiveOpt else {
            throw ServiceError.message("Tencent IM receive option unavailable")
        }

        switch target.type {
        case .direct:
            guard let userID = target.userID else {
                throw ServiceError.message("Tencent IM direct conversation missing userID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.setC2CReceiveMessageOpt(userIDList: [userID], opt: opt) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set direct conversation mute failed"))
                }
            }
        case .group:
            guard let groupID = target.groupID else {
                throw ServiceError.message("Tencent IM group conversation missing groupID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupReceiveMessageOpt(groupID: groupID, opt: opt) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set group conversation mute failed"))
                }
            }
        }

        return true
    }

    func clearConversationHistory(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)

        switch target.type {
        case .direct:
            guard let userID = target.userID else {
                throw ServiceError.message("Tencent IM direct conversation missing userID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.clearC2CHistoryMessage(userID: userID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Clear direct conversation history failed"))
                }
            }
        case .group:
            guard let groupID = target.groupID else {
                throw ServiceError.message("Tencent IM group conversation missing groupID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.clearGroupHistoryMessage(groupID: groupID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Clear group conversation history failed"))
                }
            }
        }

        await refreshTotalUnreadCount()
        return true
    }

    func inviteUsersToSquad(squadID: String, userIDs: [String]) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let normalizedSquadID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserIDs = Array(
            Set(
                userIDs
                    .map { TencentIMIdentity.toTencentIMUserID($0) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        ).sorted()

        guard !normalizedSquadID.isEmpty else {
            throw ServiceError.message("Tencent IM groupID is empty")
        }

        guard !targetUserIDs.isEmpty else {
            return true
        }

        let manager = try requireReadyManager()
        let _: [V2TIMGroupMemberOperationResult] = try await withCheckedThrowingContinuation { continuation in
            manager.inviteUserToGroup(groupID: normalizedSquadID, userList: targetUserIDs) { results in
                continuation.resume(returning: results ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Invite users to Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption {
        guard currentBootstrap?.enabled == true else {
            return .forbid
        }

        let manager = try requireReadyManager()
        let groupInfo = try await fetchGroupInfo(
            groupID: TencentIMIdentity.toTencentIMSquadGroupID(squadID),
            manager: manager
        )

        switch groupInfo.groupApproveOpt {
        case .GROUP_ADD_ANY:
            return .any
        case .GROUP_ADD_AUTH:
            return .auth
        case .GROUP_ADD_FORBID:
            return .forbid
        default:
            return .forbid
        }
    }

    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMGroupInfo()
        info.groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        switch option {
        case .forbid:
            info.groupApproveOpt = .GROUP_ADD_FORBID
        case .auth:
            info.groupApproveOpt = .GROUP_ADD_AUTH
        case .any:
            info.groupApproveOpt = .GROUP_ADD_ANY
        }

        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Set Tencent IM group invite option failed"
                    )
                )
            }
        }
        return true
    }

    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory {
        guard currentBootstrap?.enabled == true else {
            return GroupMemberDirectory(members: [], myRole: nil)
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let loginUserID = manager.getLoginUser()
        var nextSeq: UInt64 = 0
        var aggregatedMembers: [V2TIMGroupMemberFullInfo] = []

        repeat {
            let page: (nextSeq: UInt64, members: [V2TIMGroupMemberFullInfo]) = try await withCheckedThrowingContinuation { continuation in
                manager.getGroupMemberList(
                    groupID,
                    filter: UInt32(V2TIMGroupMemberFilter.GROUP_MEMBER_FILTER_ALL.rawValue),
                    nextSeq: nextSeq
                ) { fetchedNextSeq, memberList in
                    continuation.resume(returning: (fetchedNextSeq, memberList ?? []))
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Fetch Tencent IM group member list failed"
                        )
                    )
                }
            }

            aggregatedMembers.append(contentsOf: page.members)
            nextSeq = page.nextSeq
        } while nextSeq != 0

        let members = aggregatedMembers.map { mapSquadMemberProfile(from: $0) }
        let myRole = aggregatedMembers.first(where: { normalizedText($0.userID) == normalizedText(loginUserID) }).map {
            mapSquadMemberRole(rawValue: $0.role)
        }
        return GroupMemberDirectory(members: members, myRole: myRole)
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        guard currentBootstrap?.enabled == true else {
            throw ServiceError.message("Tencent IM unavailable")
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let groupInfo = try await fetchGroupInfo(groupID: groupID, manager: manager)
        let memberDirectory = try await fetchSquadMemberDirectory(squadID: squadID)
        let loginUserID = normalizedText(manager.getLoginUser()) ?? ""
        let myMember = memberDirectory.members.first {
            TencentIMIdentity.toTencentIMUserID($0.id) == loginUserID
        }

        let ownerTencentUserID = normalizedText(groupInfo.owner) ?? ""
        let ownerMember = memberDirectory.members.first {
            TencentIMIdentity.toTencentIMUserID($0.id) == ownerTencentUserID
        }
        let leader = ownerMember.map { member in
            UserSummary(
                id: member.id,
                username: member.username,
                displayName: member.displayName,
                avatarURL: member.avatarURL,
                isFollowing: member.isFollowing
            )
        } ?? UserSummary(
            id: TencentIMIdentity.normalizePlatformUserIDForProfile(ownerTencentUserID),
            username: TencentIMIdentity.normalizePlatformUserIDForProfile(ownerTencentUserID),
            displayName: ownerTencentUserID.isEmpty ? (normalizedText(groupInfo.groupName) ?? squadID) : ownerTencentUserID,
            avatarURL: nil,
            isFollowing: false
        )

        let myRole = memberDirectory.myRole ?? mapSquadMemberRole(rawValue: groupInfo.role)
        let updatedTimestamp = max(groupInfo.lastInfoTime, groupInfo.lastMessageTime, groupInfo.createTime)

        return SquadProfile(
            id: TencentIMIdentity.normalizePlatformSquadID(groupID),
            name: normalizedText(groupInfo.groupName) ?? TencentIMIdentity.normalizePlatformSquadID(groupID),
            description: normalizedText(groupInfo.introduction),
            avatarURL: normalizedText(groupInfo.faceURL),
            bannerURL: nil,
            notice: normalizedText(groupInfo.notification) ?? "",
            qrCodeURL: nil,
            isPublic: isTencentPublicGroupType(groupInfo.groupType),
            maxMembers: max(0, Int(groupInfo.memberMaxCount)),
            memberCount: max(memberDirectory.members.count, Int(groupInfo.memberCount)),
            isMember: true,
            canEditGroup: myRole == "leader" || myRole == "admin",
            myRole: myRole,
            myNickname: myMember?.nickname,
            myNotificationsEnabled: isGroupNotificationsEnabled(groupInfo.recvOpt),
            leader: leader,
            members: memberDirectory.members,
            lastMessage: nil,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedTimestamp)),
            recentMessages: [],
            activities: []
        )
    }

    func joinSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.joinGroup(groupID: groupID, msg: nil) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Join Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func leaveSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.quitGroup(groupID: groupID) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Leave Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func disbandSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.dismissGroup(groupID: groupID) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Dismiss Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func createSquad(input: CreateSquadInput) async throws -> Conversation? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let platformGroupUUID = UUID().uuidString.lowercased()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(platformGroupUUID)
        let groupInfo = V2TIMGroupInfo()
        groupInfo.groupID = groupID
        groupInfo.groupType = input.isPublic ? "Public" : "Work"
        let groupName = input.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        groupInfo.groupName = (groupName?.isEmpty == false ? groupName : L("新建群聊", "New Group"))!
        groupInfo.introduction = input.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        let memberList: [V2TIMCreateGroupMemberInfo] = Array(Set(input.memberIds)).map { rawUserID in
            let info = V2TIMCreateGroupMemberInfo()
            info.userID = TencentIMIdentity.toTencentIMUserID(rawUserID)
            return info
        }

        let createdGroupID: String = try await withCheckedThrowingContinuation { continuation in
            manager.createGroup(info: groupInfo, memberList: memberList) { createdGroupID in
                continuation.resume(returning: createdGroupID ?? groupID)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Create Tencent IM group failed"
                    )
                )
            }
        }

        return Conversation(
            id: TencentIMIdentity.normalizePlatformSquadID(createdGroupID),
            type: .group,
            title: groupInfo.groupName ?? L("新建群聊", "New Group"),
            avatarURL: normalizedText(groupInfo.faceURL),
            sdkConversationID: "group_\(createdGroupID)",
            lastMessage: L("暂无消息", "No messages yet"),
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: Date(),
            peer: nil
        )
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)

        let memberInfo = V2TIMGroupMemberFullInfo()
        memberInfo.userID = manager.getLoginUser()
        let trimmedNameCard = normalizedText(input.nickname)
        memberInfo.nameCard = trimmedNameCard
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupMemberInfo(groupID: groupID, info: memberInfo) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group nickname failed"
                    )
                )
            }
        }

        let opt = V2TIMReceiveMessageOpt(
            rawValue: input.notificationsEnabled ? Self.receiveMessageOptRawValue : Self.receiveNoNotifyRawValue
        ) ?? V2TIMReceiveMessageOpt(rawValue: Self.receiveMessageOptRawValue)
        guard let opt else {
            throw ServiceError.message("Tencent IM group receive option unavailable")
        }
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupReceiveMessageOpt(groupID: groupID, opt: opt) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group receive option failed"
                    )
                )
            }
        }
        return true
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMGroupInfo()
        info.groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        info.groupName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        info.introduction = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        info.notification = input.notice.trimmingCharacters(in: .whitespacesAndNewlines)
        info.faceURL = normalizedText(input.avatarURL)
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group info failed"
                    )
                )
            }
        }
        return true
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserID = TencentIMIdentity.toTencentIMUserID(memberUserID)

        switch role {
        case "leader":
            try await withCheckedThrowingContinuation { continuation in
                manager.transferGroupOwner(groupID: groupID, memberUserID: targetUserID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Transfer Tencent IM group owner failed"
                        )
                    )
                }
            }
        case "admin":
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupMemberRole(
                    groupID: groupID,
                    memberUserID: targetUserID,
                    newRole: UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue)
                ) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Promote Tencent IM admin failed"
                        )
                    )
                }
            }
        default:
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupMemberRole(
                    groupID: groupID,
                    memberUserID: targetUserID,
                    newRole: UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_MEMBER.rawValue)
                ) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Demote Tencent IM member failed"
                        )
                    )
                }
            }
        }
        return true
    }

    func removeUsersFromSquad(squadID: String, userIDs: [String]) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let normalizedSquadID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserIDs = Array(
            Set(
                userIDs
                    .map { TencentIMIdentity.toTencentIMUserID($0) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        ).sorted()

        guard !normalizedSquadID.isEmpty else {
            throw ServiceError.message("Tencent IM groupID is empty")
        }

        guard !targetUserIDs.isEmpty else {
            return true
        }

        let manager = try requireReadyManager()
        let _: [V2TIMGroupMemberOperationResult] = try await withCheckedThrowingContinuation { continuation in
            manager.kickGroupMember(normalizedSquadID, memberList: targetUserIDs, reason: "") { results in
                continuation.resume(returning: results ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Remove users from Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let results: [V2TIMFriendInfoResult] = try await withCheckedThrowingContinuation { continuation in
            manager.getFriendsInfo([targetUserID]) { infoResults in
                continuation.resume(returning: infoResults ?? [])
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Fetch friend remark failed"))
            }
        }

        let match = results.first {
            $0.friendInfo.userID == targetUserID
        } ?? results.first
        return normalizedText(match?.friendInfo.friendRemark)
    }

    func isTencentFriend(userID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let results: [V2TIMFriendCheckResult] = try await withCheckedThrowingContinuation { continuation in
            manager.checkFriend(userIDList: [targetUserID], checkType: .FRIEND_TYPE_BOTH) { resultList in
                continuation.resume(returning: resultList ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Check Tencent friend relation failed"
                    )
                )
            }
        }

        guard let result = results.first else { return false }
        switch result.relationType {
        case .FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST, .FRIEND_RELATION_TYPE_BOTH_WAY:
            return true
        default:
            return false
        }
    }

    func setFriendRemark(userID: String, remark: String?) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMFriendInfo()
        info.userID = TencentIMIdentity.toTencentIMUserID(userID)
        let trimmedRemark = normalizedText(remark)
        info.friendRemark = trimmedRemark
        try await withCheckedThrowingContinuation { continuation in
            manager.setFriendInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set friend remark failed"))
            }
        }
        return true
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let list: [V2TIMFriendInfo] = try await withCheckedThrowingContinuation { continuation in
            manager.getBlackList { infoList in
                continuation.resume(returning: infoList ?? [])
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Fetch blacklist failed"))
            }
        }
        return list.contains { $0.userID == targetUserID }
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)

        if blacklisted {
            let _: [V2TIMFriendOperationResult] = try await withCheckedThrowingContinuation { continuation in
                manager.addToBlackList(userIDList: [targetUserID]) { results in
                    continuation.resume(returning: results ?? [])
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Add to blacklist failed"))
                }
            }
        } else {
            let _: [V2TIMFriendOperationResult] = try await withCheckedThrowingContinuation { continuation in
                manager.deleteFromBlackList(userIDList: [targetUserID]) { results in
                    continuation.resume(returning: results ?? [])
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Remove from blacklist failed"))
                }
            }
        }

        return true
    }

    func fetchMessages(conversationID: String, count: Int = 50) async throws -> [ChatMessage]? {
        let page = try await fetchMessagesPage(
            conversationID: conversationID,
            startClientMsgID: nil,
            count: count
        )
        return page?.messages
    }

    func fetchMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int = 50
    ) async throws -> ChatMessageHistoryPage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let anchorMessage = try await resolveHistoryAnchorMessage(
            manager: manager,
            target: target,
            startClientMsgID: startClientMsgID
        )
        let remoteMessages = try await fetchHistoryMessages(
            manager: manager,
            target: target,
            count: max(1, count),
            lastMessage: anchorMessage
        )

        var mapped: [ChatMessage] = []
        mapped.reserveCapacity(remoteMessages.count)
        for message in remoteMessages {
            mapped.append(await mapMessage(message, conversationID: target.businessConversationID))
        }

        let sorted = mapped.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
        return ChatMessageHistoryPage(messages: sorted, isEnd: remoteMessages.count < max(1, count))
    }

    func sendTextMessage(conversationID: String, content: String) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard let message = manager.createTextMessage(text: content) else {
            throw ServiceError.message("Tencent IM create text message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildTextOfflinePushInfo(
            manager: manager,
            target: target,
            content: content
        )
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
    }

    func sendEventCardMessage(
        conversationID: String,
        payload: EventShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentEventCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "event",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create event card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.eventName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendDJCardMessage(
        conversationID: String,
        payload: DJShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentDJCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "dj",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create dj card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.djName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard let message = manager.createImageMessage(imagePath: fileURL.path) else {
            throw ServiceError.message("Tencent IM create image message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: onProgress
        )
    }

    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let snapshotURL = try makeVideoSnapshotURL(for: fileURL)
        guard let message = manager.createVideoMessage(
            videoFilePath: fileURL.path,
            type: fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension,
            duration: 0,
            snapshotPath: snapshotURL.path
        ) else {
            throw ServiceError.message("Tencent IM create video message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: onProgress
        )
    }

    func sendVoiceMessage(
        conversationID: String,
        fileURL: URL
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let duration = try audioDurationSeconds(for: fileURL)
        guard let message = manager.createSoundMessage(audioFilePath: fileURL.path, duration: duration) else {
            throw ServiceError.message("Tencent IM create voice message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
    }

    func sendFileMessage(
        conversationID: String,
        fileURL: URL
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let fileName = fileURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioDuration = audioFileDurationSecondsIfSupported(for: fileURL)
        let fileSizeBytes = fileSizeInBytes(for: fileURL)
        guard let message = manager.createFileMessage(
            filePath: fileURL.path,
            fileName: fileName.isEmpty ? fileURL.lastPathComponent : fileName
        ) else {
            throw ServiceError.message("Tencent IM create file message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        var sentMessage = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
        if audioDuration != nil || fileSizeBytes != nil {
            var media = sentMessage.media ?? ChatMessageMediaPayload()
            if media.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                media.mediaURL = fileURL.path
            }
            if media.fileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                media.fileName = fileName.isEmpty ? fileURL.lastPathComponent : fileName
            }
            if media.fileSizeBytes == nil {
                media.fileSizeBytes = fileSizeBytes
            }
            if media.durationSeconds == nil {
                media.durationSeconds = audioDuration
            }
            sentMessage.media = media
        }
        return sentMessage
    }

    func sendTypingStatus(
        conversationID: String,
        isTyping: Bool
    ) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard target.type == .direct else {
            return false
        }

        let payload: [String: Any] = [
            "businessID": Self.typingBusinessID,
            "typingStatus": isTyping ? 1 : 0,
            "version": 1,
            "userAction": 14,
            "actionParam": isTyping ? "EIMAMSG_InputStatus_Ing" : "EIMAMSG_InputStatus_End"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create typing message failed")
        }

        guard let priority = V2TIMMessagePriority(rawValue: 2) else {
            throw ServiceError.message("Tencent IM message priority unavailable")
        }

        try await withCheckedThrowingContinuation { continuation in
            _ = manager.sendMessage(
                message: message,
                receiver: target.userID,
                groupID: target.groupID,
                priority: priority,
                onlineUserOnly: true,
                offlinePushInfo: nil,
                progress: nil,
                succ: {
                    continuation.resume()
                },
                fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Send Tencent IM typing status failed"
                        )
                    )
                }
            )
        }

        return true
    }

    func revokeMessage(
        conversationID: String,
        messageID: String
    ) async throws -> String? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let message = try await findMessage(
            manager: manager,
            messageID: messageID,
            conversationID: target.businessConversationID
        )
        let displayText = revokeDisplayText(for: message, operateUser: nil)

        try await withCheckedThrowingContinuation { continuation in
            manager.revokeMessage(msg: message) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Revoke Tencent IM message failed"
                    )
                )
            }
        }

        return displayText
    }

    func deleteMessage(
        conversationID: String,
        messageID: String
    ) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let message = try await findMessage(
            manager: manager,
            messageID: messageID,
            conversationID: target.businessConversationID
        )

        try await withCheckedThrowingContinuation { continuation in
            manager.deleteMessages(msgList: [message]) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Delete Tencent IM message failed"
                    )
                )
            }
        }

        return true
    }

    func fetchTotalUnreadCount() async -> Int? {
        guard currentBootstrap?.enabled == true, hasInitializedSDK else {
            return nil
        }

        guard let manager = V2TIMManager.sharedInstance(),
              manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else {
            return nil
        }

        return await requestTotalUnreadCount(manager: manager)
    }

    private func login(manager: V2TIMManager, userID: String, userSig: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.login(userID: userID, userSig: userSig) {
                continuation.resume()
            } fail: { code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent IM login failed (\(code))" : message
                continuation.resume(throwing: ServiceError.message(resolved))
            }
        }
    }

    private func logout(manager: V2TIMManager) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.logout {
                continuation.resume()
            } fail: { code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent IM logout failed (\(code))" : message
                continuation.resume(throwing: ServiceError.message(resolved))
            }
        }
    }

    private func refreshTotalUnreadCount() async {
        guard let manager = V2TIMManager.sharedInstance() else {
            unreadCount = 0
            return
        }
        unreadCount = await requestTotalUnreadCount(manager: manager) ?? 0
    }

    private func requestTotalUnreadCount(manager: V2TIMManager) async -> Int? {
        await withCheckedContinuation { continuation in
            manager.getTotalUnreadMessageCount { totalUnreadCount in
                continuation.resume(returning: Int(totalUnreadCount))
            } fail: { _, _ in
                continuation.resume(returning: nil)
            }
        }
    }

    private struct TencentConversationTarget {
        let businessConversationID: String
        let rawConversationID: String
        let type: ConversationType
        let userID: String?
        let groupID: String?
    }

    private struct TencentConversationPage {
        let list: [V2TIMConversation]
        let nextSeq: UInt64
        let isFinished: Bool
    }

    private func requireReadyManager() throws -> V2TIMManager {
        guard let manager = V2TIMManager.sharedInstance(), hasInitializedSDK else {
            throw ServiceError.message("Tencent IM SDK not initialized")
        }

        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else {
            throw ServiceError.message("Tencent IM not connected")
        }

        return manager
    }

    private func applyAPNSConfigurationIfPossible(reason: String) async {
#if canImport(ImSDK_Plus)
        guard currentBootstrap?.enabled == true else { return }
        guard AppConfig.tencentIMAPNSBusinessID > 0 else { return }
        guard let token = latestAPNSTokenData, !token.isEmpty else { return }
        guard let manager = V2TIMManager.sharedInstance(), hasInitializedSDK else { return }
        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else { return }

        manager.setAPNSListener(apnsListener: TencentIMAPNSBadgeBridge.shared)
        let config = V2TIMAPNSConfig()
        config.token = token
        config.businessID = Int32(AppConfig.tencentIMAPNSBusinessID)

        await withCheckedContinuation { continuation in
            manager.setAPNS(config: config) { [weak self] in
                self?.debugAPNS("config applied reason=\(reason) businessID=\(AppConfig.tencentIMAPNSBusinessID)")
                continuation.resume()
            } fail: { [weak self] code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent APNS config failed (\(code))" : message
                self?.debugAPNS("config failed reason=\(reason): \(resolved)")
                continuation.resume()
            }
        }
#else
        _ = reason
#endif
    }

    private static func decodeHexAPNSToken(_ hexToken: String) -> Data? {
        let normalized = hexToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: normalized.count / 2)
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    private func debugAPNS(_ message: String) {
#if DEBUG
        print("[TencentIMAPNS] \(message)")
#endif
    }

    private func shouldRequestReadReceipt(for target: TencentConversationTarget) -> Bool {
        target.type == .direct || target.type == .group
    }

    private func fetchAllConversations(manager: V2TIMManager) async throws -> [V2TIMConversation] {
        var nextSeq: UInt64 = 0
        var merged: [V2TIMConversation] = []
        var isFinished = false

        repeat {
            let page = try await fetchConversationPage(
                manager: manager,
                nextSeq: nextSeq,
                count: 100
            )
            merged.append(contentsOf: page.list)
            nextSeq = page.nextSeq
            isFinished = page.isFinished
        } while !isFinished

        return merged
    }

    private func fetchConversationPage(
        manager: V2TIMManager,
        nextSeq: UInt64,
        count: Int
    ) async throws -> TencentConversationPage {
        try await withCheckedThrowingContinuation { continuation in
            manager.getConversationList(nextSeq: nextSeq, count: Int32(max(1, count))) { list, nextSeq, isFinished in
                continuation.resume(
                    returning: TencentConversationPage(
                        list: list ?? [],
                        nextSeq: nextSeq,
                        isFinished: isFinished
                    )
                )
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM conversations failed"
                    )
                )
            }
        }
    }

    private func fetchGroupInfo(groupID: String, manager: V2TIMManager) async throws -> V2TIMGroupInfo {
        let results: [V2TIMGroupInfoResult] = try await withCheckedThrowingContinuation { continuation in
            manager.getGroupsInfo([groupID]) { resultList in
                continuation.resume(returning: resultList ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM group info failed"
                    )
                )
            }
        }

        guard let info = results.first?.info else {
            throw ServiceError.message("Tencent IM group info unavailable")
        }
        return info
    }

    private func mapSquadMemberProfile(from info: V2TIMGroupMemberFullInfo) -> SquadMemberProfile {
        let rawTencentUserID = normalizedText(info.userID) ?? ""
        let platformUserID = TencentIMIdentity.normalizePlatformUserIDForProfile(rawTencentUserID)
        let resolvedDisplayName = normalizedText(info.nameCard)
            ?? normalizedText(info.friendRemark)
            ?? normalizedText(info.nickName)
            ?? (platformUserID.isEmpty ? rawTencentUserID : platformUserID)
        let role = mapSquadMemberRole(rawValue: info.role)

        return SquadMemberProfile(
            id: platformUserID.isEmpty ? rawTencentUserID : platformUserID,
            username: platformUserID.isEmpty ? rawTencentUserID : platformUserID,
            displayName: resolvedDisplayName,
            avatarURL: normalizedText(info.faceURL),
            isFollowing: false,
            role: role,
            nickname: normalizedText(info.nameCard),
            isCaptain: role == "leader",
            isAdmin: role == "admin"
        )
    }

    private func mapSquadMemberRole(rawValue: UInt32) -> String {
        switch rawValue {
        case UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_SUPER.rawValue):
            return "leader"
        case UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue):
            return "admin"
        default:
            return "member"
        }
    }

    private func isTencentPublicGroupType(_ rawType: String?) -> Bool {
        let normalized = rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized != "work"
    }

    private func isGroupNotificationsEnabled(_ opt: V2TIMReceiveMessageOpt) -> Bool {
        opt.rawValue == Self.receiveMessageOptRawValue
    }

    private func resolveConversationTarget(
        conversationID: String,
        manager: V2TIMManager
    ) async throws -> TencentConversationTarget {
        let trimmed = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.message("Conversation ID is empty")
        }

        if trimmed.hasPrefix("c2c_") {
            let userID = String(trimmed.dropFirst(4))
            return TencentConversationTarget(
                businessConversationID: userID,
                rawConversationID: trimmed,
                type: .direct,
                userID: userID,
                groupID: nil
            )
        }

        if trimmed.hasPrefix("tu_") {
            return TencentConversationTarget(
                businessConversationID: trimmed,
                rawConversationID: "c2c_\(trimmed)",
                type: .direct,
                userID: trimmed,
                groupID: nil
            )
        }

        if trimmed.hasPrefix("group_") {
            let groupID = String(trimmed.dropFirst(6))
            return TencentConversationTarget(
                businessConversationID: groupID,
                rawConversationID: trimmed,
                type: .group,
                userID: nil,
                groupID: groupID
            )
        }

        let conversations = try await fetchAllConversations(manager: manager)
        for item in conversations {
            guard let mapped = mapConversation(item) else { continue }
            if mapped.id == trimmed || mapped.sdkConversationID == trimmed {
                return TencentConversationTarget(
                    businessConversationID: mapped.id,
                    rawConversationID: mapped.sdkConversationID ?? mapped.id,
                    type: mapped.type,
                    userID: mapped.type == .direct ? mapped.id : nil,
                    groupID: mapped.type == .group ? mapped.id : nil
                )
            }
        }

        throw ServiceError.message("Tencent IM conversation not found")
    }

    private func fetchHistoryMessages(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        count: Int,
        lastMessage: V2TIMMessage?
    ) async throws -> [V2TIMMessage] {
        try await withCheckedThrowingContinuation { continuation in
            let success: V2TIMMessageListSucc = { messages in
                continuation.resume(returning: messages ?? [])
            }
            let failure: V2TIMFail = { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM history messages failed"
                    )
                )
            }

            switch target.type {
            case .direct:
                guard let userID = target.userID else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM direct conversation missing userID"))
                    return
                }
                manager.getC2CHistoryMessageList(
                    userID: userID,
                    count: Int32(max(1, count)),
                    lastMsg: lastMessage,
                    succ: success,
                    fail: failure
                )
            case .group:
                guard let groupID = target.groupID else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM group conversation missing groupID"))
                    return
                }
                manager.getGroupHistoryMessageList(
                    groupID: groupID,
                    count: Int32(max(1, count)),
                    lastMsg: lastMessage,
                    succ: success,
                    fail: failure
                )
            }
        }
    }

    private func searchLocalMessages(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        query: String,
        limit: Int
    ) async throws -> [V2TIMMessage] {
        try await withCheckedThrowingContinuation { continuation in
            let searchParam = V2TIMMessageSearchParam()
            searchParam.keywordList = [query]
            searchParam.messageTypeList = nil
            searchParam.conversationID = target.rawConversationID
            searchParam.searchTimePosition = 0
            searchParam.searchTimePeriod = 0
            searchParam.pageIndex = 0
            searchParam.pageSize = UInt(max(1, limit))

            manager.searchLocalMessages(param: searchParam) { searchResult in
                guard let searchResult else {
                    continuation.resume(returning: [])
                    return
                }

                let items = searchResult.messageSearchResultItems ?? []
                let flattened = items.flatMap { $0.messageList ?? [] }
                continuation.resume(returning: flattened)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Search Tencent IM local messages failed"
                    )
                )
            }
        }
    }

    private func resolveHistoryAnchorMessage(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        startClientMsgID: String?
    ) async throws -> V2TIMMessage? {
        guard let startClientMsgID = normalizedText(startClientMsgID) else {
            return nil
        }

        let messages = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[V2TIMMessage], Error>) in
            manager.findMessages(messageIDList: [startClientMsgID], succ: { messages in
                continuation.resume(returning: messages ?? [])
            }, fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Resolve Tencent IM history anchor failed"
                    )
                )
            })
        }

        return messages.first(where: { [weak self] message in
            guard let self else { return false }
            return self.resolveBusinessConversationID(for: message) == target.businessConversationID
        }) ?? messages.first
    }

    private func findMessage(
        manager: V2TIMManager,
        messageID: String,
        conversationID: String? = nil
    ) async throws -> V2TIMMessage {
        let trimmedMessageID = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessageID.isEmpty else {
            throw ServiceError.message("Tencent IM message ID is empty")
        }

        let messages = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[V2TIMMessage], Error>) in
            manager.findMessages(messageIDList: [trimmedMessageID], succ: { messages in
                continuation.resume(returning: messages ?? [])
            }, fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Find Tencent IM message failed"
                    )
                )
            })
        }

        if let conversationID,
           let matched = messages.first(where: { [weak self] message in
               guard let self else { return false }
               return self.resolveBusinessConversationID(for: message) == conversationID
           }) {
            return matched
        }

        if let first = messages.first {
            return first
        }

        throw ServiceError.message("Tencent IM message not found")
    }

    private func sendMessage(
        manager: V2TIMManager,
        message: V2TIMMessage,
        target: TencentConversationTarget,
        offlinePushInfo: V2TIMOfflinePushInfo? = nil,
        progress: ((Int) -> Void)?
    ) async throws -> ChatMessage {
        guard let priority = V2TIMMessagePriority(rawValue: 2) else {
            throw ServiceError.message("Tencent IM message priority unavailable")
        }

        let sentMessage = try await withCheckedThrowingContinuation { continuation in
            _ = manager.sendMessage(
                message: message,
                receiver: target.userID,
                groupID: target.groupID,
                priority: priority,
                onlineUserOnly: false,
                offlinePushInfo: offlinePushInfo,
                progress: { percent in
                    progress?(Int(percent))
                },
                succ: {
                    continuation.resume(returning: message)
                },
                fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Send Tencent IM message failed"
                        )
                    )
                }
            )
        }

        await refreshTotalUnreadCount()
        return await mapMessage(sentMessage, conversationID: target.businessConversationID)
    }

    private func buildTextOfflinePushInfo(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        content: String
    ) async -> V2TIMOfflinePushInfo? {
        let trimmedContent = normalizedPushText(content)
        guard !trimmedContent.isEmpty else { return nil }

        let conversation = await fetchConversationIfPossible(
            manager: manager,
            conversationID: target.rawConversationID
        )
        let conversationTitle = normalizedText(conversation?.showName)
        let receiveOpt = conversation?.recvOpt.rawValue

        let info = V2TIMOfflinePushInfo()
        switch target.type {
        case .direct:
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = trimmedContent
        case .group:
            let senderName = await resolveCurrentUserPushDisplayName(manager: manager)
                ?? currentUserID
                ?? L("成员", "Member")
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = "\(senderName): \(trimmedContent)"
        }

        info.disablePush = false
        info.ignoreIOSBadge = true
        info.iOSSound = "default"
        info.ext = buildPushRoutingExt(
            target: target,
            conversationTitle: conversationTitle,
            previewText: trimmedContent,
            receiveOpt: receiveOpt
        )
        return info
    }

    private func fetchConversationIfPossible(
        manager: V2TIMManager,
        conversationID: String
    ) async -> V2TIMConversation? {
        await withCheckedContinuation { continuation in
            manager.getConversation(conversationID: conversationID) { conversation in
                continuation.resume(returning: conversation)
            } fail: { _, _ in
                continuation.resume(returning: nil)
            }
        }
    }

    private func fetchUserFullInfo(
        userID: String,
        manager: V2TIMManager
    ) async throws -> V2TIMUserFullInfo {
        try await withCheckedThrowingContinuation { continuation in
            manager.getUsersInfo([userID]) { infos in
                guard let info = infos?.first else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM user info unavailable"))
                    return
                }
                continuation.resume(returning: info)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM user info failed"
                    )
                )
            }
        }
    }

    private func resolveCurrentUserPushDisplayName(manager: V2TIMManager) async -> String? {
        guard let loginUserID = currentUserID, !loginUserID.isEmpty else { return nil }
        guard let info = try? await fetchUserFullInfo(userID: loginUserID, manager: manager) else { return nil }
        return normalizedText(info.nickName)
            ?? normalizedText(info.userID)
    }

    private func buildPushRoutingExt(
        target: TencentConversationTarget,
        conversationTitle: String?,
        previewText: String,
        receiveOpt: Int?
    ) -> String {
        let payload: [String: Any] = [
            "route": "chat",
            "conversationType": target.type.rawValue,
            "conversationID": target.businessConversationID,
            "sdkConversationID": target.rawConversationID,
            "peerID": target.userID ?? "",
            "groupID": target.groupID ?? "",
            "title": conversationTitle ?? "",
            "preview": previewText,
            "recvOpt": receiveOpt ?? Self.receiveMessageOptRawValue,
            "version": 1
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func normalizedPushText(_ content: String) -> String {
        let collapsed = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "" }
        let limit = 120
        if collapsed.count <= limit {
            return collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<endIndex]) + "…"
    }

    private func mapConversation(_ item: V2TIMConversation) -> Conversation? {
        let rawType = item.type.rawValue
        let conversationType: ConversationType
        let businessID: String

        switch rawType {
        case Self.conversationTypeDirectRawValue:
            guard let userID = normalizedText(item.userID) else { return nil }
            conversationType = .direct
            businessID = userID
        case Self.conversationTypeGroupRawValue:
            guard let groupID = normalizedText(item.groupID) else { return nil }
            conversationType = .group
            businessID = groupID
        default:
            return nil
        }

        let title = normalizedText(item.showName) ?? businessID
        let avatarURL = normalizedText(item.faceUrl)
        let senderID = previewSenderLabel(for: item.lastMessage, conversationType: conversationType)
        let updatedAt = item.lastMessage?.timestamp ?? item.draftTimestamp ?? .distantPast
        let peer: UserSummary?
        if conversationType == .direct {
            peer = UserSummary(
                id: businessID,
                username: businessID,
                displayName: title,
                avatarURL: avatarURL,
                isFollowing: false
            )
        } else {
            peer = nil
        }

#if DEBUG
        print(
            """
            [IMProfile][ConversationMap] \
            type=\(conversationType == .direct ? "direct" : "group") \
            businessID=\(businessID) \
            showName=\(title) \
            faceUrl=\(avatarURL ?? "nil") \
            userID=\(normalizedText(item.userID) ?? "nil") \
            groupID=\(normalizedText(item.groupID) ?? "nil") \
            sdkConversationID=\(normalizedText(item.conversationID) ?? "nil")
            """
        )
#endif

        return Conversation(
            id: businessID,
            type: conversationType,
            title: title,
            avatarURL: avatarURL,
            sdkConversationID: normalizedText(item.conversationID),
            lastMessage: previewText(for: item.lastMessage),
            lastMessageSenderID: senderID,
            unreadCount: max(0, Int(item.unreadCount)),
            updatedAt: updatedAt,
            peer: peer,
            isPinned: item.isPinned,
            isMuted: item.recvOpt.rawValue == Self.receiveNoNotifyRawValue
        )
    }

    private func previewSenderLabel(
        for message: V2TIMMessage?,
        conversationType: ConversationType
    ) -> String? {
        guard let message else { return nil }

        let senderID = normalizedText(message.sender)
        let resolvedIsMine = senderID == currentUserID || message.isSelf
        if resolvedIsMine {
            return L("我", "Me")
        }

        let displayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
        if let displayName {
            return displayName
        }

        // Direct chats should stay visually stable even when the SDK only returns a raw sender id.
        // Falling back to nil avoids "username: content" replacing an already-correct display name preview.
        if conversationType == .direct {
            return nil
        }

        return senderID
    }

    private func previewText(for message: V2TIMMessage?) -> String {
        guard let message else {
            return L("暂无消息", "No messages yet")
        }

        switch message.elemType.rawValue {
        case Self.elemTypeTextRawValue:
            return normalizedText(message.textElem?.text) ?? ""
        case Self.elemTypeImageRawValue:
            return L("[图片]", "[Image]")
        case Self.elemTypeSoundRawValue:
            return L("[语音]", "[Voice]")
        case Self.elemTypeVideoRawValue:
            return L("[视频]", "[Video]")
        case Self.elemTypeFileRawValue:
            return normalizedText(message.fileElem?.filename) ?? L("[文件]", "[File]")
        case Self.elemTypeLocationRawValue:
            return normalizedText(message.locationElem?.desc) ?? L("[位置]", "[Location]")
        case Self.elemTypeFaceRawValue:
            return L("[表情]", "[Sticker]")
        case Self.elemTypeCustomRawValue:
            if let typingStatus = typingStatusPayload(from: message.customElem?.data) {
                return typingStatus == 1
                    ? L("正在输入...", "Typing...")
                    : L("停止输入", "Typing ended")
            }
            if let eventCard = customEventCardPayload(from: message.customElem?.data) {
                return "\(L("[活动卡片]", "[Event Card]")) \(eventCard.eventName)"
            }
            if let djCard = customDJCardPayload(from: message.customElem?.data) {
                return "\(L("[DJ卡片]", "[DJ Card]")) \(djCard.djName)"
            }
            return normalizedText(message.customElem?.desc) ?? L("[自定义消息]", "[Custom Message]")
        case Self.elemTypeGroupTipsRawValue:
            return L("[群提示]", "[Group Notice]")
        case Self.elemTypeMergerRawValue:
            return L("[聊天记录]", "[Merged Messages]")
        case Self.elemTypeStreamRawValue:
            return L("[流式消息]", "[Stream Message]")
        default:
            return L("[消息]", "[Message]")
        }
    }

    private func mapMessage(_ message: V2TIMMessage, conversationID: String) async -> ChatMessage {
        let senderID = normalizedText(message.sender) ?? "unknown"
        let senderDisplayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
            ?? senderID
        let resolvedIsMine = (currentUserID == senderID) || message.isSelf
        let sender = UserSummary(
            id: senderID,
            username: senderID,
            displayName: senderDisplayName,
            avatarURL: normalizedText(message.faceURL),
            isFollowing: false
        )

        if message.status.rawValue == Self.messageStatusLocalRevokedRawValue {
            return ChatMessage(
                id: normalizedText(message.msgID) ?? fallbackMessageID(for: message, conversationID: conversationID),
                conversationID: conversationID,
                sender: sender,
                content: revokeDisplayText(for: message, operateUser: nil),
                createdAt: message.timestamp ?? Date(),
                isMine: resolvedIsMine,
                kind: .system,
                media: nil,
                deliveryStatus: .sent,
                deliveryError: nil,
                peerRead: nil,
                readReceiptReadCount: nil,
                readReceiptUnreadCount: nil
            )
        }

        var kind: ChatMessageKind = .unknown
        var content = previewText(for: message)
        var media: ChatMessageMediaPayload?

        switch message.elemType.rawValue {
        case Self.elemTypeTextRawValue:
            kind = .text
            content = normalizedText(message.textElem?.text) ?? ""
        case Self.elemTypeImageRawValue:
            kind = .image
            content = L("[图片]", "[Image]")
            media = mapImagePayload(from: message.imageElem)
        case Self.elemTypeSoundRawValue:
            kind = .voice
            content = L("[语音]", "[Voice]")
            media = await mapSoundPayload(from: message.soundElem)
        case Self.elemTypeVideoRawValue:
            kind = .video
            content = L("[视频]", "[Video]")
            media = await mapVideoPayload(from: message.videoElem)
        case Self.elemTypeFileRawValue:
            kind = .file
            content = normalizedText(message.fileElem?.filename) ?? L("[文件]", "[File]")
            media = await mapFilePayload(from: message.fileElem)
        case Self.elemTypeLocationRawValue:
            kind = .location
            content = normalizedText(message.locationElem?.desc) ?? L("[位置]", "[Location]")
        case Self.elemTypeFaceRawValue:
            kind = .emoji
            content = L("[表情]", "[Sticker]")
        case Self.elemTypeCustomRawValue:
            if let typingStatus = typingStatusPayload(from: message.customElem?.data) {
                kind = .typing
                content = typingStatus == 1
                    ? L("正在输入...", "Typing...")
                    : L("停止输入", "Typing ended")
            } else if let eventCard = customEventCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(eventCard), encoding: .utf8))
                    ?? eventCard.eventName
                media = ChatMessageMediaPayload(
                    thumbnailURL: eventCard.coverImageURL
                )
            } else if let djCard = customDJCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(djCard), encoding: .utf8))
                    ?? djCard.djName
                media = ChatMessageMediaPayload(
                    thumbnailURL: djCard.coverImageURL
                )
            } else {
                kind = .custom
                content = normalizedText(message.customElem?.desc) ?? L("[自定义消息]", "[Custom Message]")
            }
        case Self.elemTypeGroupTipsRawValue:
            kind = .system
            content = L("[群提示]", "[Group Notice]")
        case Self.elemTypeMergerRawValue:
            kind = .card
            content = L("[聊天记录]", "[Merged Messages]")
        case Self.elemTypeStreamRawValue:
            kind = .custom
            content = L("[流式消息]", "[Stream Message]")
        default:
            break
        }

        let deliveryStatus: ChatMessageDeliveryStatus
        switch message.status.rawValue {
        case Self.messageStatusSendingRawValue:
            deliveryStatus = .sending
        case Self.messageStatusFailedRawValue:
            deliveryStatus = .failed
        case Self.messageStatusSentRawValue:
            deliveryStatus = .sent
        default:
            deliveryStatus = resolvedIsMine ? .sending : .sent
        }

#if DEBUG
        print(
            """
            [IMProfile][MessageMap] \
            conversationID=\(conversationID) \
            msgID=\(normalizedText(message.msgID) ?? "nil") \
            senderID=\(senderID) \
            senderName=\(senderDisplayName) \
            senderFace=\(normalizedText(message.faceURL) ?? "nil") \
            sdk_isSelf=\(message.isSelf) \
            resolved_isMine=\(resolvedIsMine) \
            currentUserID=\(currentUserID ?? "nil")
            """
        )
#endif

        return ChatMessage(
            id: normalizedText(message.msgID) ?? fallbackMessageID(for: message, conversationID: conversationID),
            conversationID: conversationID,
            sender: sender,
            content: content,
            createdAt: message.timestamp ?? Date(),
            isMine: resolvedIsMine,
            kind: kind,
            media: media,
            deliveryStatus: deliveryStatus,
            deliveryError: deliveryStatus == .failed ? L("发送失败", "Send failed") : nil,
            peerRead: dynamicBoolValue("isPeerRead", from: message),
            readReceiptReadCount: dynamicIntValue("groupReadCount", from: message)
                ?? dynamicIntValue("readCount", from: message)
                ?? dynamicIntValue("readReceiptCount", from: message),
            readReceiptUnreadCount: dynamicIntValue("groupUnreadCount", from: message)
                ?? dynamicIntValue("unreadCount", from: message)
                ?? dynamicIntValue("unreadReceiptCount", from: message)
        )
    }

    private func mapImagePayload(from elem: V2TIMImageElem?) -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let images = elem.imageList ?? []
        let thumbnail = images.min { lhs, rhs in
            let lhsArea = max(1, lhs.width) * max(1, lhs.height)
            let rhsArea = max(1, rhs.width) * max(1, rhs.height)
            return lhsArea < rhsArea
        }
        let original = images.max { lhs, rhs in
            let lhsScore = max(lhs.size, lhs.width * lhs.height)
            let rhsScore = max(rhs.size, rhs.width * rhs.height)
            return lhsScore < rhsScore
        }

        return ChatMessageMediaPayload(
            mediaURL: normalizedText(original?.url) ?? normalizedText(thumbnail?.url),
            thumbnailURL: normalizedText(thumbnail?.url) ?? normalizedText(original?.url),
            width: {
                guard let value = original?.width ?? thumbnail?.width, value > 0 else { return nil }
                return Double(value)
            }(),
            height: {
                guard let value = original?.height ?? thumbnail?.height, value > 0 else { return nil }
                return Double(value)
            }(),
            durationSeconds: nil,
            fileName: nil,
            fileSizeBytes: {
                let value = original?.size ?? 0
                return value > 0 ? Int(value) : nil
            }()
        )
    }

    private func typingStatusPayload(from data: Data?) -> Int? {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let businessID = object["businessID"] as? String,
              businessID == Self.typingBusinessID else {
            return nil
        }

        if let typingStatus = object["typingStatus"] as? Int {
            return typingStatus
        }
        if let typingStatus = object["typingStatus"] as? NSNumber {
            return typingStatus.intValue
        }
        return nil
    }

    private func customEventCardPayload(from data: Data?) -> EventShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentEventCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "event" else {
            return nil
        }
        return envelope.payload
    }

    private func customDJCardPayload(from data: Data?) -> DJShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentDJCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "dj" else {
            return nil
        }
        return envelope.payload
    }

    private func mapSoundPayload(from elem: V2TIMSoundElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let remoteURL = await resolveSoundURL(elem)
        return ChatMessageMediaPayload(
            mediaURL: remoteURL ?? normalizedText(elem.path),
            thumbnailURL: nil,
            width: nil,
            height: nil,
            durationSeconds: elem.duration > 0 ? Int(elem.duration) : nil,
            fileName: normalizedText(elem.uuid),
            fileSizeBytes: elem.dataSize > 0 ? Int(elem.dataSize) : nil
        )
    }

    private func mapVideoPayload(from elem: V2TIMVideoElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        async let videoURL = resolveVideoURL(elem)
        async let snapshotURL = resolveVideoSnapshotURL(elem)
        let resolvedVideoURL = await videoURL
        let resolvedSnapshotURL = await snapshotURL
        return ChatMessageMediaPayload(
            mediaURL: resolvedVideoURL ?? normalizedText(elem.videoPath),
            thumbnailURL: resolvedSnapshotURL ?? normalizedText(elem.snapshotPath),
            width: elem.snapshotWidth > 0 ? Double(elem.snapshotWidth) : nil,
            height: elem.snapshotHeight > 0 ? Double(elem.snapshotHeight) : nil,
            durationSeconds: elem.duration > 0 ? Int(elem.duration) : nil,
            fileName: normalizedText(elem.videoUUID),
            fileSizeBytes: elem.videoSize > 0 ? Int(elem.videoSize) : nil
        )
    }

    private func mapFilePayload(from elem: V2TIMFileElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let remoteURL = await resolveFileURL(elem)
        return ChatMessageMediaPayload(
            mediaURL: remoteURL ?? normalizedText(elem.path),
            thumbnailURL: nil,
            width: nil,
            height: nil,
            durationSeconds: nil,
            fileName: normalizedText(elem.filename),
            fileSizeBytes: elem.fileSize > 0 ? Int(elem.fileSize) : nil
        )
    }

    private func fallbackMessageID(for message: V2TIMMessage, conversationID: String) -> String {
        "\(conversationID)-\(message.seq)-\(message.random)"
    }

    private func buildTencentIMError(code: Int32, desc: String?, fallback: String) -> ServiceError {
        let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if message.isEmpty {
            return .message("\(fallback) (\(code))")
        }
        return .message(message)
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func dynamicBoolValue(_ key: String, from object: NSObject) -> Bool? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        if let value = object.value(forKey: key) as? NSNumber {
            return value.boolValue
        }
        return object.value(forKey: key) as? Bool
    }

    private func dynamicIntValue(_ key: String, from object: NSObject) -> Int? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        if let value = object.value(forKey: key) as? NSNumber {
            return value.intValue
        }
        return object.value(forKey: key) as? Int
    }

    private func resolveSoundURL(_ elem: V2TIMSoundElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveVideoURL(_ elem: V2TIMVideoElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getVideoUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveVideoSnapshotURL(_ elem: V2TIMVideoElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getSnapshotUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveFileURL(_ elem: V2TIMFileElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func makeVideoSnapshotURL(for fileURL: URL) throws -> URL {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) else {
            throw ServiceError.message("Failed to create Tencent IM video snapshot")
        }

        let image = UIImage(cgImage: imageRef)
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw ServiceError.message("Failed to encode Tencent IM video snapshot")
        }

        let snapshotURL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent("tencent-im-video-\(UUID().uuidString).jpg")
        try data.write(to: snapshotURL, options: .atomic)
        return snapshotURL
    }

    private func audioDurationSeconds(for fileURL: URL) throws -> Int32 {
        let asset = AVURLAsset(url: fileURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite, durationSeconds > 0 {
            let clamped = max(1, min(Int(durationSeconds.rounded()), 600))
            return Int32(clamped)
        }
        return 1
    }

    private func audioFileDurationSecondsIfSupported(for fileURL: URL) -> Int? {
        guard isSupportedAudioFile(fileURL) else { return nil }
        guard let duration = try? audioDurationSeconds(for: fileURL) else { return nil }
        let resolved = Int(duration)
        return resolved > 0 ? resolved : nil
    }

    private func isSupportedAudioFile(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["mp3", "m4a", "aac", "wav", "caf"].contains(ext)
    }

    private func fileSizeInBytes(for fileURL: URL) -> Int? {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }

    private func resolveBusinessConversationID(for message: V2TIMMessage) -> String? {
        if let groupID = normalizedText(message.groupID) {
            return groupID
        }
        if let userID = normalizedText(message.userID) {
            return userID
        }
        if let senderID = normalizedText(message.sender), message.isSelf {
            // Fallback for some SDK edge cases where userID is empty.
            return senderID
        }
        return nil
    }

    private func revokeDisplayText(
        for message: V2TIMMessage,
        operateUser: V2TIMUserFullInfo?
    ) -> String {
        let revokerID = normalizedText(operateUser?.userID)
            ?? normalizedText(message.revokerInfo?.userID)
            ?? normalizedText(message.sender)
        let messageSenderID = normalizedText(message.sender)
        let senderDisplayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
            ?? messageSenderID
            ?? L("用户", "User")
        let revokerDisplayName = normalizedText(operateUser?.nickName)
            ?? normalizedText(message.revokerInfo?.nickName)
            ?? senderDisplayName

        if revokerID == messageSenderID {
            if message.isSelf {
                return L("你撤回了一条消息", "You recalled a message")
            }
            if normalizedText(message.userID) != nil {
                return L("对方撤回了一条消息", "The other user recalled a message")
            }
            return String(format: L("%@ 撤回了一条消息", "%@ recalled a message"), senderDisplayName)
        }

        return String(format: L("%@ 撤回了一条消息", "%@ recalled a message"), revokerDisplayName)
    }
#endif
}

#if canImport(ImSDK_Plus)
extension TencentIMSession: V2TIMSDKListener {
    nonisolated func onConnecting() {
        Task { @MainActor [weak self] in
            self?.state = .connecting
        }
    }

    nonisolated func onConnectSuccess() {
        Task { @MainActor [weak self] in
            guard let self, let currentUserID = self.currentUserID else { return }
            self.state = .connected(userID: currentUserID)
        }
    }

    nonisolated func onConnectFailed(_ code: Int32, err: String?) {
        let message = err?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolved = message.isEmpty ? "Tencent IM connect failed (\(code))" : message
        Task { @MainActor [weak self] in
            self?.state = .failed(resolved)
        }
    }

    nonisolated func onKickedOffline() {
        Task { @MainActor [weak self] in
            self?.unreadCount = 0
            self?.state = .kickedOffline
        }
    }

    nonisolated func onUserSigExpired() {
        Task { @MainActor [weak self] in
            self?.state = .userSigExpired
        }
    }
}

extension TencentIMSession: V2TIMConversationListener {
    nonisolated func onNewConversation(conversationList: [V2TIMConversation]) {
        Task { @MainActor [weak self] in
            self?.publishConversationChanges(conversationList)
        }
    }

    nonisolated func onConversationChanged(conversationList: [V2TIMConversation]) {
        Task { @MainActor [weak self] in
            self?.publishConversationChanges(conversationList)
        }
    }

    nonisolated func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        Task { @MainActor [weak self] in
            let count = Int(totalUnreadCount)
            self?.unreadCount = count
            self?.totalUnreadSubject.send(max(0, count))
        }
    }
}

extension TencentIMSession: V2TIMAdvancedMsgListener {
    nonisolated func onRecvNewMessage(msg: V2TIMMessage) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let conversationID = self.resolveBusinessConversationID(for: msg) else { return }
            let mapped = await self.mapMessage(msg, conversationID: conversationID)
            self.messageSubject.send(mapped)
        }
    }

    nonisolated func onRecvMessageRevoked(msgID: String, operateUser: V2TIMUserFullInfo, reason: String?) {
        _ = reason
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let manager = V2TIMManager.sharedInstance() else { return }
            guard let revokedMessage = try? await self.findMessage(manager: manager, messageID: msgID) else { return }
            guard let conversationID = self.resolveBusinessConversationID(for: revokedMessage) else { return }
            let mapped = await self.mapMessage(revokedMessage, conversationID: conversationID)
            self.messageSubject.send(mapped)
            self.messageRevocationSubject.send(
                TencentMessageRevocationEvent(
                    conversationID: conversationID,
                    messageID: mapped.id,
                    displayText: self.revokeDisplayText(for: revokedMessage, operateUser: operateUser)
                )
            )
        }
    }

    nonisolated func onRecvC2CReadReceipt(receiptList: [V2TIMMessageReceipt]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let events = receiptList.compactMap { receipt -> TencentC2CReadReceiptEvent? in
                guard let conversationID = self.normalizedText(receipt.userID) else { return nil }
                let messageID = self.normalizedText(receipt.msgID)
                let readAt = receipt.timestamp > 0 ? Date(timeIntervalSince1970: TimeInterval(receipt.timestamp)) : nil
                return TencentC2CReadReceiptEvent(
                    conversationID: conversationID,
                    messageID: messageID,
                    peerRead: receipt.isPeerRead,
                    readAt: readAt
                )
            }
            guard !events.isEmpty else { return }
            self.c2cReadReceiptSubject.send(events)
        }
    }
}

#if canImport(ImSDK_Plus)
@MainActor
private extension TencentIMSession {
    func publishConversationChanges(_ items: [V2TIMConversation]) {
        let conversations = items.compactMap(mapConversation(_:))
        guard !conversations.isEmpty else { return }
        conversationSubject.send(conversations)
    }
}
#endif
#endif

#if !canImport(ImSDK_Plus)
@MainActor
extension TencentIMSession {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]? {
        _ = type
        return nil
    }

    func markConversationRead(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws -> Bool {
        _ = conversationID
        _ = pinned
        return false
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws -> Bool {
        _ = conversationID
        _ = unread
        return false
    }

    func hideConversation(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws -> Bool {
        _ = conversationID
        _ = muted
        return false
    }

    func clearConversationHistory(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        _ = userID
        return nil
    }

    func setFriendRemark(userID: String, remark: String?) async throws -> Bool {
        _ = userID
        _ = remark
        return false
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        _ = userID
        return false
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws -> Bool {
        _ = userID
        _ = blacklisted
        return false
    }

    func fetchMessages(conversationID: String, count: Int = 50) async throws -> [ChatMessage]? {
        _ = conversationID
        _ = count
        return nil
    }

    func fetchMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int = 50
    ) async throws -> ChatMessageHistoryPage? {
        _ = conversationID
        _ = startClientMsgID
        _ = count
        return nil
    }

    func sendTextMessage(conversationID: String, content: String) async throws -> ChatMessage? {
        _ = conversationID
        _ = content
        return nil
    }

    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        _ = onProgress
        return nil
    }

    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        _ = onProgress
        return nil
    }

    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        return nil
    }

    func revokeMessage(conversationID: String, messageID: String) async throws -> String? {
        _ = conversationID
        _ = messageID
        return nil
    }

    func deleteMessage(conversationID: String, messageID: String) async throws -> Bool {
        _ = conversationID
        _ = messageID
        return false
    }
}
#endif

@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "AppState"
    )
    @Published var session: Session?
    @Published var errorMessage: String?
    @Published var isAuthBootstrapping: Bool = true
    @Published var unreadMessagesCount: Int = 0
    @Published var tencentIMBootstrap: TencentIMBootstrap?
    @Published var tencentIMConnectionState: TencentIMConnectionState = .idle
    @Published var systemDeepLinkEvent: SystemDeepLinkEvent?
    @Published var preferredLanguage: AppLanguage = AppLanguagePreference.current
    @Published var preferredAppearance: AppAppearance = AppAppearancePreference.current

    let service: SocialService
    private var cancellables: Set<AnyCancellable> = []
    private let tencentIMSession = TencentIMSession.shared
    private let uiTestForceSessionExpiredOnBootstrap: Bool
    private var hasAppliedUITestForcedExpiry = false
    private var tencentIMBootstrapRefreshTask: Task<Void, Never>?
    private var cachedCommunityUnread = 0
    private var latestPushToken: String?
    private var lastTencentIMBootstrapRefreshAt: Date?

    init(service: SocialService) {
        self.service = service
        self.uiTestForceSessionExpiredOnBootstrap = Self.parseBool(
            ProcessInfo.processInfo.environment["RAVER_UI_TEST_FORCE_SESSION_EXPIRED_ON_BOOT"],
            fallback: false
        )
        tencentIMSession.onStateChange = { [weak self] state in
            self?.handleTencentIMStateChange(state)
        }
        tencentIMSession.onUnreadCountChange = { [weak self] count in
            guard let self, self.session != nil else { return }
            self.recomputeUnreadMessagesCount(chatsUnread: count, source: "tencent-im-realtime")
        }

        NotificationCenter.default.publisher(for: .raverSessionExpired)
            .sink { [weak self] _ in
                guard let self else { return }
                self.session = nil
                self.resetUnreadCounts()
                SessionTokenStore.shared.clear()
                self.errorMessage = L("登录状态已失效，请重新登录", "Session expired. Please log in again.")
                self.tencentIMBootstrap = nil
                self.tencentIMSession.reset()
                self.tencentIMBootstrapRefreshTask?.cancel()
                self.tencentIMBootstrapRefreshTask = nil
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.session != nil else { return }
                Task {
                    let shouldRefreshTencentBootstrap = self.shouldRefreshTencentIMBootstrapOnActive()
                    if shouldRefreshTencentBootstrap {
                        await self.refreshTencentIMBootstrap(source: "didBecomeActive")
                    }
                    await self.refreshUnreadMessages()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .raverDidRegisterPushToken)
            .sink { [weak self] notification in
                guard let self else { return }
                let token = (notification.object as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !token.isEmpty else { return }
                self.latestPushToken = token
                Task {
                    await self.tencentIMSession.updateAPNSToken(hexToken: token)
                    guard self.session != nil else { return }
                    await self.uploadPushTokenIfPossible()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .raverDidOpenSystemNotification)
            .sink { [weak self] notification in
                guard let self, self.session != nil else { return }
                let userInfo = notification.userInfo ?? [:]
                self.handleSystemNotificationPayload(userInfo, source: "notification-center")
                Task {
                    await self.refreshTencentIMBootstrap(source: "system-notification-open")
                    await self.refreshUnreadMessages()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .raverCommunityUnreadDidChange)
            .sink { [weak self] notification in
                guard let self, self.session != nil else { return }
                guard let total = Self.parseCommunityUnreadTotal(from: notification.userInfo) else { return }
                self.cachedCommunityUnread = max(0, total)
                self.recomputeUnreadMessagesCount(source: "community-event")
                self.debug("community unread updated total=\(self.cachedCommunityUnread)")
            }
            .store(in: &cancellables)

        if let pendingPayload = RaverAppDelegate.consumePendingSystemNotificationUserInfo() {
            handleSystemNotificationPayload(pendingPayload, source: "launch-options")
        }

        Task {
            await bootstrapSessionIfPossible()
        }
    }

    var isLoggedIn: Bool {
        session != nil
    }

    private func bootstrapSessionIfPossible() async {
        defer { isAuthBootstrapping = false }

        guard let restored = await service.restoreSession() else {
            return
        }

        session = restored
        await refreshTencentIMBootstrap(source: "bootstrap-restore-session")
        await refreshUnreadMessages()
        await uploadPushTokenIfPossible()
        errorMessage = nil

        if uiTestForceSessionExpiredOnBootstrap && !hasAppliedUITestForcedExpiry {
            hasAppliedUITestForcedExpiry = true
            NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
        }
    }

    private static func parseBool(_ value: String?, fallback: Bool) -> Bool {
        guard let value else { return fallback }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on" {
            return true
        }
        if normalized == "0" || normalized == "false" || normalized == "no" || normalized == "off" {
            return false
        }
        return fallback
    }

    func login(username: String, password: String) async {
        do {
            session = try await service.login(username: username, password: password)
            await refreshTencentIMBootstrap(source: "login-password")
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loginWithSms(phoneNumber: String, code: String) async {
        do {
            session = try await service.loginWithSms(phoneNumber: phoneNumber, code: code)
            await refreshTencentIMBootstrap(source: "login-sms")
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func sendLoginSmsCode(phoneNumber: String) async -> Int? {
        do {
            let expiresInSeconds = try await service.sendLoginSmsCode(phoneNumber: phoneNumber)
            errorMessage = nil
            return expiresInSeconds
        } catch {
            errorMessage = error.userFacingMessage
            return nil
        }
    }

    func register(username: String, email: String, password: String, displayName: String) async {
        do {
            session = try await service.register(
                username: username,
                email: email,
                password: password,
                displayName: displayName
            )
            await refreshTencentIMBootstrap(source: "register")
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func logout() {
        let shouldDeactivatePushToken = session != nil
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device-unknown"
        Task {
            if shouldDeactivatePushToken {
                do {
                    try await service.deactivateDevicePushToken(deviceID: deviceID, platform: "ios")
                    debug("deactivate push token success deviceID=\(deviceID)")
                } catch {
                    debug("deactivate push token failed: \(error.localizedDescription)")
                }
            }
            await service.logout()
            SessionTokenStore.shared.clear()
        }
        session = nil
        resetUnreadCounts()
        tencentIMBootstrap = nil
        tencentIMSession.reset()
        tencentIMBootstrapRefreshTask?.cancel()
        tencentIMBootstrapRefreshTask = nil
    }

    func setPreferredLanguage(_ language: AppLanguage) {
        guard preferredLanguage != language else { return }
        preferredLanguage = language
        AppLanguagePreference.current = language
    }

    func setPreferredAppearance(_ appearance: AppAppearance) {
        guard preferredAppearance != appearance else { return }
        preferredAppearance = appearance
        AppAppearancePreference.current = appearance
    }

    func refreshUnreadMessages() async {
        guard session != nil else {
            resetUnreadCounts()
            return
        }

        do {
            async let notificationsUnreadTask = service.fetchNotificationUnreadCount()
            let chatsUnread = try await fetchChatUnreadCount()
            let socialUnread = try await notificationsUnreadTask
            cachedCommunityUnread = Self.communityUnreadCount(from: socialUnread)
            recomputeUnreadMessagesCount(chatsUnread: chatsUnread, source: "refresh-success")
        } catch {
            // Keep current count when refresh fails.
            recomputeUnreadMessagesCount(source: "refresh-fallback")
        }
    }

    private func resetUnreadCounts() {
        cachedCommunityUnread = 0
        unreadMessagesCount = 0
#if canImport(ImSDK_Plus)
        TencentIMAPNSBadgeBridge.shared.setUnifiedUnreadCount(0)
#endif
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    private func uploadPushTokenIfPossible() async {
        guard session != nil else { return }
        guard let latestPushToken, !latestPushToken.isEmpty else { return }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device-unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let locale = Locale.preferredLanguages.first
        do {
            try await service.registerDevicePushToken(
                deviceID: deviceID,
                platform: "ios",
                pushToken: latestPushToken,
                appVersion: appVersion,
                locale: locale
            )
            debug("register push token success deviceID=\(deviceID)")
        } catch {
            debug("register push token failed: \(error.localizedDescription)")
        }
    }

    private func recomputeUnreadMessagesCount(chatsUnread: Int? = nil, source: String = "unspecified") {
        let previous = unreadMessagesCount
        let chatUnread = max(0, chatsUnread ?? localChatUnreadSnapshot())
        let communityUnread = max(0, cachedCommunityUnread)
        let next = chatUnread + communityUnread
        unreadMessagesCount = next
#if canImport(ImSDK_Plus)
        TencentIMAPNSBadgeBridge.shared.setUnifiedUnreadCount(next)
#endif
        UIApplication.shared.applicationIconBadgeNumber = next
        if previous != next {
            debug("badge recompute source=\(source) from=\(previous) to=\(next) chat=\(chatUnread) community=\(communityUnread)")
        }
    }

    private func localChatUnreadSnapshot() -> Int {
        max(0, tencentIMSession.totalUnreadCountSnapshot())
    }

    private func fetchChatUnreadCount() async throws -> Int {
        max(0, tencentIMSession.totalUnreadCountSnapshot())
    }

    private static func communityUnreadCount(from count: NotificationUnreadCount) -> Int {
        max(0, count.follows)
            + max(0, count.likes)
            + max(0, count.comments)
            + max(0, count.squadInvites)
    }

    private static func parseCommunityUnreadTotal(from userInfo: [AnyHashable: Any]?) -> Int? {
        guard let raw = userInfo?["total"] else { return nil }
        if let value = raw as? Int {
            return value
        }
        if let value = raw as? NSNumber {
            return value.intValue
        }
        return nil
    }

    @MainActor
    func refreshTencentIMBootstrap(source: String = "unspecified") async {
        if let inFlight = tencentIMBootstrapRefreshTask {
            debug("refreshTencentIMBootstrap join in-flight source=\(source)")
            await inFlight.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.tencentIMBootstrapRefreshTask = nil
            }
            await self.performRefreshTencentIMBootstrap(source: source)
        }
        tencentIMBootstrapRefreshTask = task
        await task.value
    }

    @MainActor
    private func performRefreshTencentIMBootstrap(source: String) async {
        guard session != nil else {
            tencentIMBootstrap = nil
            tencentIMSession.reset()
            return
        }

        do {
            let bootstrap = try await service.fetchTencentIMBootstrap()
            debug(
                "refreshTencentIMBootstrap success source=\(source) enabled=\(bootstrap.enabled) userID=\(bootstrap.userID)"
            )
            tencentIMBootstrap = bootstrap
            await tencentIMSession.sync(with: bootstrap)
            lastTencentIMBootstrapRefreshAt = Date()
        } catch {
            debug("refreshTencentIMBootstrap failed source=\(source): \(error.localizedDescription)")
            if tencentIMBootstrap == nil {
                tencentIMSession.reset()
            }
        }
    }

    private func shouldRefreshTencentIMBootstrapOnActive() -> Bool {
        switch tencentIMConnectionState {
        case .connected:
            break
        case .idle, .disabled, .unavailable, .initializing, .connecting, .userSigExpired, .kickedOffline, .failed:
            return true
        }

        guard let last = lastTencentIMBootstrapRefreshAt else {
            return true
        }

        return Date().timeIntervalSince(last) >= 90
    }

    private func handleTencentIMStateChange(_ state: TencentIMConnectionState) {
        if tencentIMConnectionState == state {
            return
        }
        tencentIMConnectionState = state
        debug("TencentIM state -> \(state)")

        guard session != nil else { return }
        switch state {
        case .userSigExpired:
            Task { @MainActor [weak self] in
                await self?.refreshTencentIMBootstrap(source: "usersig-expired")
                await self?.refreshUnreadMessages()
            }
        case .kickedOffline:
            errorMessage = L(
                "腾讯云 IM 已在其他设备登录，请重新进入或重新登录",
                "Tencent Cloud IM was logged in on another device. Please re-enter or sign in again."
            )
        case .idle, .disabled, .unavailable, .initializing, .connecting, .connected, .failed:
            break
        }
    }

    private func debug(_ message: String) {
        #if DEBUG
        Self.logger.debug("[AppState] \(message, privacy: .public)")
        print("[AppState] \(message)")
        IMProbeLogger.log("[AppState] \(message)")
        #endif
    }

    private func handleSystemNotificationPayload(_ payload: [AnyHashable: Any], source: String) {
        let deeplink = Self.readSystemDeeplink(from: payload)
        guard let deeplink else { return }
        systemDeepLinkEvent = SystemDeepLinkEvent(deeplink: deeplink, source: source)
        debug("system deeplink received source=\(source) deeplink=\(deeplink)")
    }

    private static func readSystemDeeplink(from payload: [AnyHashable: Any]) -> String? {
        let preferredKeys = ["deeplink", "deep_link", "url", "link", "target_url"]

        for key in preferredKeys {
            if let value = payload[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        if let nested = payload["metadata"] as? [String: Any] {
            for key in preferredKeys {
                if let value = nested[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        if let aps = payload["aps"] as? [String: Any],
           let nested = aps["metadata"] as? [String: Any] {
            for key in preferredKeys {
                if let value = nested[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        return nil
    }
}

extension Notification.Name {
    static let raverSessionExpired = Notification.Name("raver.session.expired")
    static let raverCommunityUnreadDidChange = Notification.Name("raver.community.unreadDidChange")
}
