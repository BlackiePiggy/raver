import Foundation
import Combine
import OSLog
import UIKit


enum AppLanguage: String, CaseIterable, Codable, Hashable, Identifiable {
    case system
    case zh
    case en
    case ja

    var id: String { rawValue }

    var title: String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .zh:
            switch self {
            case .system: return "跟随系统"
            case .zh: return "中文"
            case .en: return "English"
            case .ja: return "日本語"
            }
        case .en, .system:
            switch self {
            case .system: return "System"
            case .zh: return "Chinese"
            case .en: return "English"
            case .ja: return "Japanese"
            }
        case .ja:
            switch self {
            case .system: return "システムに合わせる"
            case .zh: return "中文"
            case .en: return "English"
            case .ja: return "日本語"
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
        case .ja:
            return "ja-JP"
        }
    }

    var effectiveLanguage: AppLanguage {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            if preferred.hasPrefix("ja") { return .ja }
            if preferred.hasPrefix("zh") { return .zh }
            return .en
        case .zh, .en, .ja:
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
            return LT("跟随系统", "System", "システムに従う")
        case .light:
            return LT("浅色", "Light", "ライト")
        case .dark:
            return LT("深色", "Dark", "ダーク")
        }
    }
}

struct AppLocalizedTextValue: Hashable {
    let zh: String
    let en: String
    let ja: String

    func text(for language: AppLanguage = AppLanguagePreference.current.effectiveLanguage) -> String {
        switch language {
        case .zh, .system:
            return zh
        case .en:
            return en
        case .ja:
            return ja
        }
    }
}

@inline(__always)
func LT(_ zh: String, _ en: String, _ ja: String) -> String {
    AppLocalizedTextValue(zh: zh, en: en, ja: ja).text()
}

@inline(__always)
func L(_ zh: String, _ en: String) -> String {
    switch AppLanguagePreference.current.effectiveLanguage {
    case .zh, .system:
        return zh
    case .en:
        return en
    case .ja:
        return AppLocalizedText.jaMap[zh] ?? en
    }
}

@inline(__always)
func L(_ zh: String, _ en: String, _ ja: String) -> String {
    LT(zh, en, ja)
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

    static let jaMap: [String: String] = [
        "跟随系统": "システムに合わせる",
        "浅色": "ライト",
        "深色": "ダーク",
        "提示": "お知らせ",
        "知道了": "OK",
        "确定": "OK",
        "取消": "キャンセル",
        "提交": "送信",
        "保存": "保存",
        "编辑": "編集",
        "删除": "削除",
        "重试": "再試行",
        "关闭": "閉じる",
        "加载失败": "読み込みに失敗しました",
        "正在更新": "更新中",
        "账号": "アカウント",
        "编辑资料": "プロフィールを編集",
        "账号安全": "アカウントの安全",
        "隐私设置": "プライバシー設定",
        "通知": "通知",
        "推送通知": "プッシュ通知",
        "消息提醒": "メッセージ通知",
        "内容偏好": "コンテンツ設定",
        "主题设置": "テーマ設定",
        "兴趣标签": "興味タグ",
        "语言设置": "言語設定",
        "内容过滤": "コンテンツフィルター",
        "数据与存储": "データとストレージ",
        "缓存管理": "キャッシュ管理",
        "数据使用": "データ使用量",
        "下载设置": "ダウンロード設定",
        "关于": "情報",
        "帮助中心": "ヘルプセンター",
        "服务条款": "利用規約",
        "隐私政策": "プライバシーポリシー",
        "关于我们": "Raver について",
        "版本": "バージョン",
        "退出登录": "ログアウト",
        "设置": "設定",
        "显示语言": "表示言語",
        "显示主题": "表示テーマ",
        "删除账号": "アカウント削除",
        "确认删除账号": "アカウントを削除",
        "删除后你将退出登录，账号会被停用并清除个人资料。此操作不可撤销。": "削除後はログアウトされ、アカウントは無効化され個人情報が消去されます。この操作は元に戻せません。",
        "我的举报记录": "自分の通報履歴",
        "暂无举报记录。": "通報履歴はありません。",
        "重复举报同一对象会更新补充说明，不会无限创建重复记录。": "同じ対象を再度通報すると補足内容が更新され、重複記録は作成されません。",
        "拉黑列表": "ブロックリスト",
        "暂无拉黑用户。": "ブロック中のユーザーはいません。",
        "解除拉黑后，对方可能重新通过私信或互动与你接触。": "ブロックを解除すると、相手が再びメッセージや交流で接触できる場合があります。",
        "举报": "通報",
        "举报已提交": "通報を送信しました",
        "举报已提交，并已拉黑该用户": "通報を送信し、このユーザーをブロックしました",
        "拉黑": "ブロック",
        "解除拉黑": "ブロック解除",
        "申诉": "異議申し立て",
        "封禁": "停止",
        "账号正常。": "アカウントは正常です。",
        "当前操作受限。": "現在、一部操作が制限されています。",
        "下次复核：": "次回確認：",
        "禁止邀请": "招待禁止",
        "管理员审批": "管理者承認",
        "自动通过": "自動承認",
        "推荐": "おすすめ",
        "最新": "最新",
        "服务响应无效": "サービス応答が無効です",
        "登录状态已失效，请重新登录": "ログインの有効期限が切れました。もう一度ログインしてください。",
        "请先登录": "ログインしてください。",
        "请填写申诉理由": "異議申し立ての理由を入力してください。",
        "账号当前受限，无法发帖。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているため投稿できません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "账号当前受限，无法评论。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているためコメントできません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "账号当前受限，无法私信。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているためメッセージを送信できません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "账号当前受限，无法上传媒体。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているためメディアをアップロードできません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "账号当前受限，无法修改资料。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているためプロフィールを変更できません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "账号当前受限，无法位置共享。你可以在账号安全页查看详情并提交申诉。": "現在アカウントが制限されているため位置情報を共有できません。アカウントの安全ページで詳細を確認し、異議申し立てできます。",
        "先看看": "あとで見る",
        "我同意《用户服务条款》《用户协议》《隐私政策》": "利用規約、ユーザー契約、プライバシーポリシーに同意します",
        "一键登录": "ワンタップでログイン",
        "其他手机号登录": "別の電話番号でログイン",
        "注册新账号": "新規登録",
        "— 其他登录方式 —": "— その他のログイン方法 —",
        "收起": "閉じる",
        "登录方式": "ログイン方法",
        "手机号（含区号）": "電話番号（国番号を含む）",
        "验证码": "認証コード",
        "发送验证码": "コードを送信",
        "账号登录": "アカウントでログイン",
        "验证码登录": "SMSでログイン",
        "用户名": "ユーザー名",
        "密码": "パスワード",
        "还没有账号？注册": "アカウントをお持ちでない方は登録",
        "第三方登录即将开放，先使用账号登录": "外部ログインは準備中です。先にアカウントログインをご利用ください。",
        "请先勾选并同意用户协议": "先に利用規約への同意にチェックしてください。",
        "请先输入手机号": "電話番号を入力してください。",
        "创建账号": "アカウントを作成",
        "补充头像、昵称和登录信息，完成后即可进入 Raver。": "アイコン、ニックネーム、ログイン情報を入力すると Raver を始められます。",
        "上传头像": "アイコンをアップロード",
        "更换头像": "アイコンを変更",
        "邮箱": "メールアドレス",
        "昵称": "ニックネーム",
        "昵称全平台唯一，不区分大小写，提交后进入审核。": "ニックネームは全体で一意です。大文字小文字は区別されず、送信後に審査されます。",
        "确认密码": "パスワード確認",
        "完成注册": "登録を完了",
        "头像读取失败，请重新选择": "アイコンの読み込みに失敗しました。もう一度選択してください。",
        "请输入邮箱": "メールアドレスを入力してください。",
        "请输入昵称": "ニックネームを入力してください。",
        "密码至少需要 6 位": "パスワードは6文字以上で入力してください。",
        "两次输入的密码不一致": "入力したパスワードが一致しません。",
        "注册成功，但头像上传失败，请稍后在个人主页重试": "登録は完了しましたが、アイコンのアップロードに失敗しました。後ほどプロフィールから再試行してください。",
        "短信": "SMS",
        "私信": "メッセージ",
        "小队": "Squad",
        "暂无消息": "メッセージはありません",
        "[图片]": "[画像]",
        "[视频]": "[動画]",
        "[语音]": "[音声]",
        "[文件]": "[ファイル]",
        "[名片]": "[カード]",
        "[位置]": "[位置]",
        "[引用消息]": "[引用]",
        "[表情]": "[絵文字]",
        "[自定义消息]": "[カスタムメッセージ]",
        "[消息]": "[メッセージ]",
        "系统": "システム",
        "[系统消息]": "[システムメッセージ]",
        "关注": "フォロー",
        "已关注": "フォロー中",
        "动态": "投稿",
        "粉丝": "フォロワー",
        "好友": "友達",
        "快捷入口": "クイック操作",
        "我的发布": "自分の投稿",
        "我的收藏": "保存済み",
        "我的路线": "自分のルート",
        "小工具": "ツール",
        "二维码": "QRコード",
        "暂无内容": "コンテンツはありません",
        "暂无动态": "投稿はありません",
        "还没有动态": "投稿はまだありません",
        "活动": "イベント",
        "活动加载中...": "イベントを読み込み中...",
        "近期暂无活动": "近日中のイベントはありません",
        "活动详情": "イベント詳細",
        "活动日历": "イベントカレンダー",
        "购票链接（可选）": "チケットリンク（任意）",
        "城市": "都市",
        "国家": "国",
        "搜索": "検索",
        "搜索结果": "検索結果",
        "没有找到匹配活动": "一致するイベントが見つかりません",
        "试试不同关键词": "別のキーワードをお試しください",
        "即将开始": "まもなく開始",
        "进行中": "開催中",
        "已结束": "終了",
        "已取消": "キャンセル済み",
        "加载活动中...": "イベントを読み込み中...",
        "加载 Set 中...": "Set を読み込み中...",
        "加载打分事件中...": "評価イベントを読み込み中...",
        "加载打分单位中...": "評価対象を読み込み中..."
    ]

    @inline(__always)
    static func resolveForCurrentLanguage(_ text: String) -> String {
        switch AppLanguagePreference.current.effectiveLanguage {
        case .en:
            return enMap[text] ?? text
        case .ja:
            return jaMap[text] ?? enMap[text] ?? text
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

enum PushRouteTrace {
    private static let queue = DispatchQueue(
        label: "com.raver.mvp.push-route-trace",
        qos: .utility
    )
    private static let maxFileSizeBytes: UInt64 = 1 * 1024 * 1024
    private static let filename = "push-route.log"
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static var resolvedURL: URL?

    static func log(_ category: String, _ message: String) {
        let entry = "[\(category)] \(formatter.string(from: Date())) \(message)"
        print(entry)
        IMProbeLogger.log(entry)
        queue.async {
            guard let url = logFileURL() else { return }
            rotateIfNeeded(url: url)
            append(line: entry, to: url)
        }
    }

    static func dumpToConsole() {
        guard let url = logFileURL(),
              let contents = try? String(contentsOf: url, encoding: .utf8),
              !contents.isEmpty else { return }
        print("[PushRouteReplay] ---- begin ----")
        for entry in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            print("[PushRouteReplay] \(entry)")
        }
        print("[PushRouteReplay] ---- end ----")
    }

    static func clear() {
        guard let url = logFileURL() else { return }
        try? Data().write(to: url, options: .atomic)
    }

    static var currentLogFilePath: String? {
        logFileURL()?.path
    }

    private static func logFileURL() -> URL? {
        if let resolvedURL {
            return resolvedURL
        }

        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let url = documentsDir.appendingPathComponent(filename, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        resolvedURL = url
        return url
    }

    private static func rotateIfNeeded(url: URL) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? UInt64 ?? 0
        guard size > maxFileSizeBytes else { return }
        try? Data().write(to: url, options: .atomic)
    }

    private static func append(line: String, to url: URL) {
        let payload = "\(line)\n"
        guard let data = payload.data(using: .utf8) else { return }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            FileManager.default.createFile(atPath: url.path, contents: data)
            return
        }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }
}


@MainActor
final class AppState: ObservableObject {
    private enum SharedPushContext {
        static let suiteName = "group.com.raver.mvp"
        static let currentUserIDKey = "push.currentUserID"
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "AppState"
    )
    private static func pushRouteLog(_ message: String) {
        PushRouteTrace.log("SystemPushRoute", message)
    }
    @Published var session: Session? {
        didSet {
            syncSharedPushContext()
            accountEnforcementStatus = session?.accountStatus ?? .clear
            if session == nil {
                accountEnforcements = []
                accountEnforcementAppeals = []
            }
        }
    }
    @Published var errorMessage: String?
    @Published var isAuthBootstrapping: Bool = true
    @Published var isRegistrationOnboardingActive: Bool = false
    @Published var unreadMessagesCount: Int = 0
    @Published var tencentIMBootstrap: TencentIMBootstrap?
    @Published var tencentIMConnectionState: TencentIMConnectionState = .idle
    @Published var systemDeepLinkEvent: SystemDeepLinkEvent?
    @Published var preferredLanguage: AppLanguage = AppLanguagePreference.current
    @Published var preferredAppearance: AppAppearance = AppAppearancePreference.current
    @Published var realNameVerificationStatus: RealNameVerificationStatus = .unverified
    @Published var accountEnforcementStatus: AccountEnforcementStatus = .clear
    @Published var accountEnforcements: [AccountEnforcement] = []
    @Published var accountEnforcementAppeals: [AccountEnforcementAppeal] = []
    @Published var isLoadingAccountEnforcements = false

    let service: SocialService
    private var cancellables: Set<AnyCancellable> = []
    private let tencentIMSession = TencentIMSession.shared
    private let uiTestForceSessionExpiredOnBootstrap: Bool
    private var hasAppliedUITestForcedExpiry = false
    private var tencentIMBootstrapRefreshTask: Task<Void, Never>?
    private var cachedCommunityUnread = 0
    private var cachedFollowedEventsUnread = 0
    private var cachedFollowedDJsUnread = 0
    private var cachedFollowedBrandsUnread = 0
    private var latestPushToken: String?
    private var lastTencentIMBootstrapRefreshAt: Date?
    private var pendingSystemNotificationPayload: ([AnyHashable: Any], String)?

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
            .sink { [weak self] notification in
                guard let self else { return }
                let reason = (notification.object as? SessionExpirationReason) ?? .expired
                self.session = nil
                self.resetUnreadCounts()
                SessionTokenStore.shared.clear()
                self.errorMessage = reason.userFacingMessage
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
                    await self.refreshAccountEnforcements()
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
                Self.pushRouteLog("publisher didOpenSystemNotification received hasSession=\(self?.session != nil) keys=\(Self.summarizeNotificationPayloadKeys(notification.userInfo ?? [:]))")
                guard let self else { return }
                let userInfo = notification.userInfo ?? [:]
                guard self.session != nil else {
                    self.pendingSystemNotificationPayload = (userInfo, "notification-center")
                    Self.pushRouteLog("publisher buffered payload because session is nil")
                    return
                }
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
            Self.pushRouteLog("init consumed pending payload keys=\(Self.summarizeNotificationPayloadKeys(pendingPayload))")
            if session != nil {
                handleSystemNotificationPayload(pendingPayload, source: "launch-options")
            } else {
                pendingSystemNotificationPayload = (pendingPayload, "launch-options")
                Self.pushRouteLog("init buffered pending payload because session is nil")
            }
        } else {
            Self.pushRouteLog("init found no pending payload")
        }

        syncSharedPushContext()

        Task {
            await bootstrapSessionIfPossible()
        }
    }

    var isLoggedIn: Bool {
        session != nil
    }

    var shouldKeepLoginGatePresented: Bool {
        session == nil || isRegistrationOnboardingActive
    }

    private func bootstrapSessionIfPossible() async {
        defer { isAuthBootstrapping = false }

        guard let restored = await service.restoreSession() else {
            return
        }

        session = restored
        await refreshTencentIMBootstrap(source: "bootstrap-restore-session")
        await refreshAccountEnforcements()
        await refreshUnreadMessages()
        await uploadPushTokenIfPossible()
        flushPendingSystemNotificationPayloadIfPossible(trigger: "bootstrap-restore-session")
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
            await refreshAccountEnforcements()
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            flushPendingSystemNotificationPayloadIfPossible(trigger: "login-password")
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loginWithEmailCode(email: String, code: String) async {
        do {
            session = try await service.loginWithEmailCode(email: email, code: code)
            await refreshTencentIMBootstrap(source: "login-email")
            await refreshAccountEnforcements()
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            flushPendingSystemNotificationPayloadIfPossible(trigger: "login-email")
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loginWithSms(phoneNumber: String, code: String) async {
        do {
            session = try await service.loginWithSms(phoneNumber: phoneNumber, code: code)
            await refreshTencentIMBootstrap(source: "login-sms")
            await refreshAccountEnforcements()
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            flushPendingSystemNotificationPayloadIfPossible(trigger: "login-sms")
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loginWithFirebasePhoneIdToken(_ idToken: String, birthYear: Int? = nil, regionCode: String? = nil, displayName: String? = nil) async {
        do {
            try await loginWithFirebasePhoneIdTokenOrThrow(
                idToken,
                birthYear: birthYear,
                regionCode: regionCode,
                displayName: displayName
            )
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loginWithFirebasePhoneIdTokenOrThrow(_ idToken: String, birthYear: Int? = nil, regionCode: String? = nil, displayName: String? = nil) async throws {
        session = try await service.loginWithFirebasePhoneIdToken(idToken, birthYear: birthYear, regionCode: regionCode, displayName: displayName)
        await refreshTencentIMBootstrap(source: "login-firebase-phone")
        await refreshAccountEnforcements()
        await refreshUnreadMessages()
        await uploadPushTokenIfPossible()
        flushPendingSystemNotificationPayloadIfPossible(trigger: "login-firebase-phone")
    }

    func applyCurrentUserProfile(_ profile: UserProfile) {
        guard let current = session, current.user.id == profile.id else { return }
        let existing = current.user
        let updatedUser = UserSummary(
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName,
            avatarURL: profile.avatarURL,
            isFollowing: existing.isFollowing,
            isFriend: existing.isFriend,
            conversationID: existing.conversationID,
            friendMessage: existing.friendMessage,
            regionCode: existing.regionCode,
            birthYear: existing.birthYear,
            ageBand: existing.ageBand,
            guardianContactEmail: existing.guardianContactEmail
        )
        session = Session(
            token: current.token,
            refreshToken: current.refreshToken,
            user: updatedUser,
            accountStatus: current.accountStatus
        )
    }

    func updateCurrentUserAvatarURL(_ avatarURL: String?) {
        guard let current = session else { return }
        let existing = current.user
        let updatedUser = UserSummary(
            id: existing.id,
            username: existing.username,
            displayName: existing.displayName,
            avatarURL: avatarURL,
            isFollowing: existing.isFollowing,
            isFriend: existing.isFriend,
            conversationID: existing.conversationID,
            friendMessage: existing.friendMessage,
            regionCode: existing.regionCode,
            birthYear: existing.birthYear,
            ageBand: existing.ageBand,
            guardianContactEmail: existing.guardianContactEmail
        )
        session = Session(
            token: current.token,
            refreshToken: current.refreshToken,
            user: updatedUser,
            accountStatus: current.accountStatus
        )
    }

    func currentUserProfileSnapshot(avatarURL: String? = nil) -> UserProfile? {
        guard let user = session?.user else { return nil }
        return UserProfile(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            bio: "",
            avatarURL: avatarURL ?? user.avatarURL,
            tags: [],
            isFollowersListPublic: true,
            isFollowingListPublic: true,
            canViewFollowersList: true,
            canViewFollowingList: true,
            followersCount: 0,
            followingCount: 0,
            friendsCount: 0,
            postsCount: 0,
            isFollowing: user.isFollowing,
            isFriend: user.isFriend
        )
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

    func sendEmailAuthCode(email: String, scene: String) async -> Int? {
        do {
            let expiresInSeconds = try await service.sendEmailAuthCode(email: email, scene: scene)
            errorMessage = nil
            return expiresInSeconds
        } catch {
            errorMessage = error.userFacingMessage
            return nil
        }
    }

    func checkDisplayNameAvailability(_ displayName: String) async throws -> DisplayNameAvailability {
        try await service.checkDisplayNameAvailability(displayName)
    }

    func registerWithEmailCode(
        email: String,
        code: String,
        displayName: String,
        birthYear: Int?,
        regionCode: String?
    ) async throws {
        session = try await service.registerWithEmailCode(
            email: email,
            code: code,
            displayName: displayName,
            birthYear: birthYear,
            regionCode: regionCode
        )
        await refreshTencentIMBootstrap(source: "register-email")
        await refreshAccountEnforcements()
        await refreshUnreadMessages()
        await uploadPushTokenIfPossible()
        flushPendingSystemNotificationPayloadIfPossible(trigger: "register-email")
    }

    func beginRegistrationOnboarding() {
        isRegistrationOnboardingActive = true
    }

    func finishRegistrationOnboarding() {
        isRegistrationOnboardingActive = false
    }

    func register(
        email: String,
        password: String,
        displayName: String,
        birthYear: Int?,
        regionCode: String?
    ) async {
        do {
            session = try await service.register(
                email: email,
                password: password,
                displayName: displayName,
                birthYear: birthYear,
                regionCode: regionCode
            )
            await refreshTencentIMBootstrap(source: "register")
            await refreshAccountEnforcements()
            await refreshUnreadMessages()
            await uploadPushTokenIfPossible()
            flushPendingSystemNotificationPayloadIfPossible(trigger: "register")
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func logout() {
        let shouldDeactivatePushToken = session != nil
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device-unknown"
        realNameVerificationStatus = .unverified
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
        isRegistrationOnboardingActive = false
        resetUnreadCounts()
        tencentIMBootstrap = nil
        tencentIMSession.reset()
        tencentIMBootstrapRefreshTask?.cancel()
        tencentIMBootstrapRefreshTask = nil
        accountEnforcementStatus = .clear
        accountEnforcements = []
        accountEnforcementAppeals = []
    }

    func logoutAllDevices() async -> Bool {
        guard session != nil else {
            errorMessage = LT("请先登录", "Please log in first.", "先にログインしてください。")
            return false
        }

        do {
            try await service.logoutAll()
            SessionTokenStore.shared.clear()
            session = nil
            realNameVerificationStatus = .unverified
            resetUnreadCounts()
            tencentIMBootstrap = nil
            tencentIMSession.reset()
            tencentIMBootstrapRefreshTask?.cancel()
            tencentIMBootstrapRefreshTask = nil
            accountEnforcementStatus = .clear
            accountEnforcements = []
            accountEnforcementAppeals = []
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    func deleteAccount() async -> Bool {
        guard session != nil else {
            errorMessage = LT("请先登录", "Please log in first.", "先にログインしてください。")
            return false
        }

        do {
            try await service.deleteAccount()
            SessionTokenStore.shared.clear()
            session = nil
            realNameVerificationStatus = .unverified
            resetUnreadCounts()
            tencentIMBootstrap = nil
            tencentIMSession.reset()
            tencentIMBootstrapRefreshTask?.cancel()
            tencentIMBootstrapRefreshTask = nil
            accountEnforcementStatus = .clear
            accountEnforcements = []
            accountEnforcementAppeals = []
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    func refreshAccountEnforcements() async {
        guard session != nil else { return }
        isLoadingAccountEnforcements = true
        defer { isLoadingAccountEnforcements = false }
        do {
            async let statusRequest = service.fetchAccountEnforcementStatus()
            async let enforcementsRequest = service.fetchAccountEnforcements()
            async let appealsRequest = service.fetchAccountEnforcementAppeals()
            let (status, enforcements, appeals) = try await (statusRequest, enforcementsRequest, appealsRequest)
            accountEnforcementStatus = status
            accountEnforcements = enforcements
            accountEnforcementAppeals = appeals
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func submitAccountEnforcementAppeal(enforcementID: String, input: AccountEnforcementAppealInput) async -> Bool {
        guard session != nil else {
            errorMessage = LT("请先登录", "Please log in first.", "先にログインしてください。")
            return false
        }
        let reason = input.appealReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = LT("请填写申诉理由", "Please enter an appeal reason.", "申立理由を入力してください。")
            return false
        }

        do {
            let appeal = try await service.submitAccountEnforcementAppeal(
                enforcementID: enforcementID,
                input: AccountEnforcementAppealInput(
                    appealReason: reason,
                    contactEmail: input.contactEmail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                    attachments: input.attachments
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )
            )
            accountEnforcementAppeals.removeAll { $0.id == appeal.id }
            accountEnforcementAppeals.insert(appeal, at: 0)
            await refreshAccountEnforcements()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    private func syncSharedPushContext() {
        guard let defaults = UserDefaults(suiteName: SharedPushContext.suiteName) else { return }
        let currentUserID = session?.user.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentUserID, !currentUserID.isEmpty {
            defaults.set(currentUserID, forKey: SharedPushContext.currentUserIDKey)
        } else {
            defaults.removeObject(forKey: SharedPushContext.currentUserIDKey)
        }
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
            async let followedEventsSummaryTask = service.fetchFollowedEventsSummary()
            async let followedDJsSummaryTask = service.fetchFollowedDJsSummary()
            async let followedBrandsSummaryTask = service.fetchFollowedBrandsSummary()
            let chatsUnread = try await fetchChatUnreadCount()
            let socialUnread = try await notificationsUnreadTask
            let followedEventsSummary = try await followedEventsSummaryTask
            let followedDJsSummary = try await followedDJsSummaryTask
            let followedBrandsSummary = try await followedBrandsSummaryTask
            cachedCommunityUnread = Self.communityUnreadCount(from: socialUnread)
            cachedFollowedEventsUnread = max(0, followedEventsSummary.unreadCount)
            cachedFollowedDJsUnread = max(0, followedDJsSummary.unreadCount)
            cachedFollowedBrandsUnread = max(0, followedBrandsSummary.unreadCount)
            recomputeUnreadMessagesCount(chatsUnread: chatsUnread, source: "refresh-success")
        } catch {
            // Keep current count when refresh fails.
            recomputeUnreadMessagesCount(source: "refresh-fallback")
        }
    }

    private func resetUnreadCounts() {
        cachedCommunityUnread = 0
        cachedFollowedEventsUnread = 0
        cachedFollowedDJsUnread = 0
        cachedFollowedBrandsUnread = 0
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
        let followedEventsUnread = max(0, cachedFollowedEventsUnread)
        let followedDJsUnread = max(0, cachedFollowedDJsUnread)
        let followedBrandsUnread = max(0, cachedFollowedBrandsUnread)
        let next = chatUnread + communityUnread + followedEventsUnread + followedDJsUnread + followedBrandsUnread
        unreadMessagesCount = next
#if canImport(ImSDK_Plus)
        TencentIMAPNSBadgeBridge.shared.setUnifiedUnreadCount(next)
#endif
        UIApplication.shared.applicationIconBadgeNumber = next
        if previous != next {
            debug("badge recompute source=\(source) from=\(previous) to=\(next) chat=\(chatUnread) community=\(communityUnread) followedEvents=\(followedEventsUnread) followedDJs=\(followedDJsUnread) followedBrands=\(followedBrandsUnread)")
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
            errorMessage = LT("腾讯云 IM 已在其他设备登录，请重新进入或重新登录", "Tencent Cloud IM was logged in on another device. Please re-enter or sign in again.", "Tencent Cloud IM が別の端末でログインされました。再度入るかログインし直してください。")
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
        Self.pushRouteLog("handle payload source=\(source) summary=\(Self.summarizeSystemNotificationPayload(payload))")
        if let extPayload = Self.extractPushExtPayload(from: payload) {
            Self.pushRouteLog("handle ext source=\(source) summary=\(Self.summarizePushExtPayload(extPayload))")
            handleEventUpdatePushSideEffectsIfNeeded(extPayload, source: source)
            handleDJUpdatePushSideEffectsIfNeeded(extPayload, source: source)
            handleBrandUpdatePushSideEffectsIfNeeded(extPayload, source: source)
        } else {
            Self.pushRouteLog("handle ext source=\(source) summary=nil")
        }
        let deeplink = Self.readSystemDeeplink(from: payload)
        guard let deeplink else {
            Self.pushRouteLog("handle deeplink source=\(source) resolved=nil")
            return
        }
        systemDeepLinkEvent = SystemDeepLinkEvent(deeplink: deeplink, source: source)
        Self.pushRouteLog("handle deeplink source=\(source) resolved=\(deeplink)")
    }

    private func flushPendingSystemNotificationPayloadIfPossible(trigger: String) {
        guard session != nil else {
            Self.pushRouteLog("flush pending skipped trigger=\(trigger) because session is nil")
            return
        }
        guard let (payload, source) = pendingSystemNotificationPayload else {
            Self.pushRouteLog("flush pending found no payload trigger=\(trigger)")
            return
        }
        pendingSystemNotificationPayload = nil
        Self.pushRouteLog("flush pending handling trigger=\(trigger) originalSource=\(source)")
        handleSystemNotificationPayload(payload, source: source)
    }

    private func handleEventUpdatePushSideEffectsIfNeeded(_ payload: [String: Any], source: String) {
        let route = (payload["route"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard route == "event_update" else { return }

        let itemID = [
            payload["itemID"] as? String,
            payload["itemId"] as? String,
            payload["notificationID"] as? String,
            payload["notificationId"] as? String,
            payload["inboxID"] as? String,
            payload["inboxId"] as? String
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let newsID = (payload["newsID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"

        guard let itemID else {
            Self.pushRouteLog("event_update open no itemID source=\(source) newsID=\(newsID)")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.markFollowedEventNotificationRead(notificationID: itemID)
                self.cachedFollowedEventsUnread = max(0, self.cachedFollowedEventsUnread - 1)
                self.recomputeUnreadMessagesCount(source: "event-update-open")
                NotificationCenter.default.post(name: .raverFollowedEventsDidMutate, object: nil)
                Self.pushRouteLog("event_update mark-read success itemID=\(itemID) source=\(source) newsID=\(newsID)")
            } catch {
                Self.pushRouteLog("event_update mark-read failed itemID=\(itemID) source=\(source) newsID=\(newsID) error=\(error.localizedDescription)")
            }
        }
    }

    private func handleDJUpdatePushSideEffectsIfNeeded(_ payload: [String: Any], source: String) {
        let route = (payload["route"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard route == "dj_update" else { return }

        let itemID = [
            payload["itemID"] as? String,
            payload["itemId"] as? String,
            payload["notificationID"] as? String,
            payload["notificationId"] as? String,
            payload["inboxID"] as? String,
            payload["inboxId"] as? String
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let newsID = (payload["newsID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"

        guard let itemID else {
            Self.pushRouteLog("dj_update open no itemID source=\(source) newsID=\(newsID)")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.markFollowedDJNotificationRead(notificationID: itemID)
                self.cachedFollowedDJsUnread = max(0, self.cachedFollowedDJsUnread - 1)
                self.recomputeUnreadMessagesCount(source: "dj-update-open")
                NotificationCenter.default.post(name: .raverFollowedDJsDidMutate, object: nil)
                Self.pushRouteLog("dj_update mark-read success itemID=\(itemID) source=\(source) newsID=\(newsID)")
            } catch {
                Self.pushRouteLog("dj_update mark-read failed itemID=\(itemID) source=\(source) newsID=\(newsID) error=\(error.localizedDescription)")
            }
        }
    }

    private func handleBrandUpdatePushSideEffectsIfNeeded(_ payload: [String: Any], source: String) {
        let route = (payload["route"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard route == "brand_update" else { return }

        let itemID = [
            payload["itemID"] as? String,
            payload["itemId"] as? String,
            payload["notificationID"] as? String,
            payload["notificationId"] as? String,
            payload["inboxID"] as? String,
            payload["inboxId"] as? String
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let newsID = (payload["newsID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"

        guard let itemID else {
            Self.pushRouteLog("brand_update open no itemID source=\(source) newsID=\(newsID)")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.markFollowedBrandNotificationRead(notificationID: itemID)
                self.cachedFollowedBrandsUnread = max(0, self.cachedFollowedBrandsUnread - 1)
                self.recomputeUnreadMessagesCount(source: "brand-update-open")
                NotificationCenter.default.post(name: .raverFollowedBrandsDidMutate, object: nil)
                Self.pushRouteLog("brand_update mark-read success itemID=\(itemID) source=\(source) newsID=\(newsID)")
            } catch {
                Self.pushRouteLog("brand_update mark-read failed itemID=\(itemID) source=\(source) newsID=\(newsID) error=\(error.localizedDescription)")
            }
        }
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

        if let extPayload = extractPushExtPayload(from: payload),
           let deeplink = buildSystemDeeplink(fromPushExt: extPayload) {
            return deeplink
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

    private static func extractPushExtPayload(from payload: [AnyHashable: Any]) -> [String: Any]? {
        if let ext = payload["ext"] as? [String: Any] {
            return ext
        }
        if let ext = payload["entity"] as? [String: Any] {
            return ext
        }
        if let ext = payload["ext"] as? String,
           let decoded = decodePushJSONObject(from: ext) {
            return decoded
        }
        if let ext = payload["entity"] as? String,
           let decoded = decodePushJSONObject(from: ext) {
            return decoded
        }
        if let metadata = payload["metadata"] as? [String: Any] {
            if let ext = metadata["ext"] as? [String: Any] {
                return ext
            }
            if let ext = metadata["entity"] as? [String: Any] {
                return ext
            }
            if let ext = metadata["ext"] as? String,
               let decoded = decodePushJSONObject(from: ext) {
                return decoded
            }
            if let ext = metadata["entity"] as? String,
               let decoded = decodePushJSONObject(from: ext) {
                return decoded
            }
        }
        return nil
    }

    private static func decodePushJSONObject(from string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func buildSystemDeeplink(fromPushExt payload: [String: Any]) -> String? {
        let route = (payload["route"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if route == "event_update" {
            if let explicitDeeplink = (payload["deeplink"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !explicitDeeplink.isEmpty {
                return explicitDeeplink
            }

            if let newsID = (payload["newsID"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !newsID.isEmpty {
                let encodedNewsID = newsID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? newsID
                return "raver://news/\(encodedNewsID)"
            }

            if let eventID = (payload["eventID"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !eventID.isEmpty {
                let encodedEventID = eventID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventID
                return "raver://event/\(encodedEventID)"
            }
            return nil
        }

        if route == "dj_update" {
            if let explicitDeeplink = (payload["deeplink"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !explicitDeeplink.isEmpty {
                return explicitDeeplink
            }

            if let newsID = (payload["newsID"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !newsID.isEmpty {
                let encodedNewsID = newsID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? newsID
                return "raver://news/\(encodedNewsID)"
            }

            if let djID = (payload["djID"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !djID.isEmpty {
                let encodedDJID = djID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? djID
                return "raver://dj/\(encodedDJID)"
            }
            return nil
        }

        guard route == "chat" else { return nil }

        let conversationID = [
            payload["sdkConversationID"] as? String,
            payload["conversationID"] as? String,
            payload["groupID"] as? String,
            payload["peerID"] as? String
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        guard let conversationID else { return nil }
        let encodedID = conversationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? conversationID
        var components = URLComponents()
        components.scheme = "raver"
        components.host = "messages"
        components.path = "/conversation/\(encodedID)"

        var queryItems: [URLQueryItem] = []
        if let conversationType = (payload["conversationType"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !conversationType.isEmpty {
            queryItems.append(URLQueryItem(name: "conversationType", value: conversationType))
        }
        if let peerID = (payload["peerID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !peerID.isEmpty {
            queryItems.append(URLQueryItem(name: "peerID", value: peerID))
        }
        if let groupID = (payload["groupID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !groupID.isEmpty {
            queryItems.append(URLQueryItem(name: "groupID", value: groupID))
        }
        if let businessConversationID = (payload["conversationID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !businessConversationID.isEmpty {
            queryItems.append(URLQueryItem(name: "conversationID", value: businessConversationID))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url?.absoluteString ?? "raver://messages/conversation/\(encodedID)"
    }

    private static func summarizeSystemNotificationPayload(_ payload: [AnyHashable: Any]) -> String {
        let keys = payload.keys
            .compactMap { $0 as? String }
            .sorted()
        let apsKeys = (payload["aps"] as? [String: Any])?.keys.sorted() ?? []
        let metadataKeys = (payload["metadata"] as? [String: Any])?.keys.sorted() ?? []
        return "keys=\(keys) apsKeys=\(apsKeys) metadataKeys=\(metadataKeys)"
    }

    private static func summarizePushExtPayload(_ payload: [String: Any]) -> String {
        let route = (payload["route"] as? String) ?? "nil"
        let conversationType = (payload["conversationType"] as? String) ?? "nil"
        let conversationID = (payload["conversationID"] as? String) ?? "nil"
        let sdkConversationID = (payload["sdkConversationID"] as? String) ?? "nil"
        let peerID = (payload["peerID"] as? String) ?? "nil"
        let groupID = (payload["groupID"] as? String) ?? "nil"
        let mentionAll = (payload["mentionAll"] as? Bool) ?? false
        let mentionedUserIDs = (payload["mentionedUserIDs"] as? [Any])?
            .compactMap { value -> String? in
                if let string = value as? String {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
                return nil
            } ?? []
        let itemID = (payload["itemID"] as? String)
            ?? (payload["itemId"] as? String)
            ?? (payload["notificationID"] as? String)
            ?? (payload["notificationId"] as? String)
            ?? (payload["inboxID"] as? String)
            ?? (payload["inboxId"] as? String)
        let eventID = (payload["eventID"] as? String) ?? "nil"
        let eventName = (payload["eventName"] as? String) ?? "nil"
        let newsID = (payload["newsID"] as? String) ?? "nil"
        let newsTitle = (payload["newsTitle"] as? String) ?? "nil"
        let updateKind = (payload["updateKind"] as? String) ?? "nil"
        let deeplink = (payload["deeplink"] as? String) ?? "nil"
        return "route=\(route) type=\(conversationType) conversationID=\(conversationID) sdkConversationID=\(sdkConversationID) peerID=\(peerID) groupID=\(groupID) mentionAll=\(mentionAll) mentionedUserIDs=\(mentionedUserIDs) itemID=\(itemID ?? "nil") eventID=\(eventID) eventName=\(eventName) newsID=\(newsID) newsTitle=\(newsTitle) updateKind=\(updateKind) deeplink=\(deeplink)"
    }

    private static func summarizeNotificationPayloadKeys(_ payload: [AnyHashable: Any]) -> String {
        let keys = payload.keys.compactMap { $0 as? String }.sorted()
        let apsKeys = (payload["aps"] as? [String: Any])?.keys.sorted() ?? []
        let metadataKeys = (payload["metadata"] as? [String: Any])?.keys.sorted() ?? []
        return "keys=\(keys) apsKeys=\(apsKeys) metadataKeys=\(metadataKeys)"
    }
}

extension Notification.Name {
    static let raverSessionExpired = Notification.Name("raver.session.expired")
    static let raverCommunityUnreadDidChange = Notification.Name("raver.community.unreadDidChange")
}
