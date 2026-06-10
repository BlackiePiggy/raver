import Foundation

struct LearnFestival: Identifiable, Hashable {
    var id: String
    var name: String
    var aliases: [String]
    var country: String
    var city: String
    var foundedYear: String
    var frequency: String
    var tagline: String
    var introduction: String
    var genres: [String]
    var avatarUrl: String?
    var backgroundUrl: String?
    var links: [LearnFestivalLink]
    var contributors: [WebUserLite] = defaultContributors
    var isFollowing: Bool? = nil
    var canEdit: Bool? = nil

    static let defaultContributors: [WebUserLite] = [
        WebUserLite(
            id: "uploadtester",
            username: "uploadtester",
            displayName: "Upload Tester",
            avatarUrl: "https://api.dicebear.com/9.x/adventurer-neutral/png?seed=uploadtester&backgroundType=gradientLinear"
        )
    ]

    static let seedData: [LearnFestival] = [
        LearnFestival(
            id: "tomorrowland",
            name: "Tomorrowland",
            aliases: ["明日世界", "TL"],
            country: "比利时",
            city: "Boom",
            foundedYear: "2005",
            frequency: "每年 7 月",
            tagline: "全球最具辨识度的沉浸式 EDM 电音节之一。",
            introduction: "Tomorrowland 以大型主舞台叙事、超高制作和多舞台联动著称，覆盖 Mainstage、Techno、House、Trance 等多类电子音乐。",
            genres: ["EDM", "Progressive House", "Techno", "Trance"],
            avatarUrl: "https://logo.clearbit.com/tomorrowland.com",
            backgroundUrl: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.tomorrowland.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/tomorrowland/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Tomorrowland_(festival)")
            ]
        ),
        LearnFestival(
            id: "edc",
            name: "Electric Daisy Carnival",
            aliases: ["EDC", "EDC Las Vegas"],
            country: "美国",
            city: "Las Vegas",
            foundedYear: "1997",
            frequency: "每年 5 月（拉斯维加斯站）",
            tagline: "Insomniac 旗下头部 IP，视觉与舞美强调霓虹和嘉年华体验。",
            introduction: "EDC 在北美和全球拥有多站点，核心站点为 EDC Las Vegas，包含大量舞台和夜间演出，强调社区文化与沉浸体验。",
            genres: ["EDM", "Bass", "House", "Hardstyle"],
            avatarUrl: "https://logo.clearbit.com/electricdaisycarnival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://lasvegas.electricdaisycarnival.com/"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/edc_lasvegas/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Electric_Daisy_Carnival")
            ]
        ),
        LearnFestival(
            id: "ultra",
            name: "Ultra Music Festival",
            aliases: ["Ultra", "UMF"],
            country: "美国",
            city: "Miami",
            foundedYear: "1999",
            frequency: "每年 3 月",
            tagline: "Miami 春季大秀，Mainstage 与 Resistance 双核心舞台体系。",
            introduction: "Ultra Music Festival 是全球电子音乐节标杆之一，Ultra Worldwide 在多个国家巡回举办，Miami 主站影响力最大。",
            genres: ["EDM", "House", "Techno", "Trance"],
            avatarUrl: "https://logo.clearbit.com/ultramusicfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://ultramusicfestival.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/ultra/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Ultra_Music_Festival")
            ]
        ),
        LearnFestival(
            id: "soundstorm",
            name: "MDLBEAST Soundstorm",
            aliases: ["Soundstorm", "利雅得 Soundstorm"],
            country: "沙特阿拉伯",
            city: "Riyadh",
            foundedYear: "2019",
            frequency: "每年冬季",
            tagline: "中东地区高规格大型电子音乐节 IP。",
            introduction: "Soundstorm 由 MDLBEAST 打造，舞台规模和阵容体量增长迅速，已成为中东地区讨论度极高的电子音乐节。",
            genres: ["EDM", "House", "Techno", "Hip-Hop Crossover"],
            avatarUrl: "https://logo.clearbit.com/mdlbeast.com",
            backgroundUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://mdlbeast.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/soundstorm/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/MDLBEAST")
            ]
        ),
        LearnFestival(
            id: "creamfields",
            name: "Creamfields",
            aliases: ["奶油田"],
            country: "英国",
            city: "Daresbury（主站）",
            foundedYear: "1998",
            frequency: "每年夏季",
            tagline: "英国历史悠久的大型电子音乐节品牌。",
            introduction: "Creamfields 以 UK 大型户外电子音乐节体验著称，除英国主站外也发展出国际系列站点。",
            genres: ["EDM", "Tech House", "Techno", "Drum & Bass"],
            avatarUrl: "https://logo.clearbit.com/creamfields.com",
            backgroundUrl: "https://images.unsplash.com/photo-1571266028243-d220c9c3b5f2?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.creamfields.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/creamfieldsofficial/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Creamfields")
            ]
        ),
        LearnFestival(
            id: "vac-music-festival",
            name: "VAC Music Festival",
            aliases: ["VAC", "VAC 电音节"],
            country: "中国",
            city: "多城市巡回",
            foundedYear: "近年兴起",
            frequency: "年度 / 季度站点",
            tagline: "中国本土电子音乐节 IP，强调国际阵容与本土场景融合。",
            introduction: "VAC Music Festival 聚焦国际电子音乐艺人与本土社群联动，通常包含多舞台与 Day 分场配置。",
            genres: ["EDM", "Bass", "Techno", "Future Rave"],
            avatarUrl: "https://logo.clearbit.com/vacmusicfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.vacmusicfestival.com")
            ]
        ),
        LearnFestival(
            id: "storm-festival",
            name: "STORM Festival",
            aliases: ["Storm 风暴电音节", "风暴电音节"],
            country: "中国",
            city: "上海 / 多城市",
            foundedYear: "2010 年代",
            frequency: "年度站点",
            tagline: "中国大型电子音乐节品牌之一，覆盖多风格舞台。",
            introduction: "STORM Festival 在国内电子音乐场景中有较高认知度，阵容涵盖主流 EDM 与细分舞曲风格。",
            genres: ["EDM", "House", "Bass", "Trance"],
            avatarUrl: "https://logo.clearbit.com/stormfestival.cn",
            backgroundUrl: "https://images.unsplash.com/photo-1487180144351-b8472da7d491?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://stormfestival.cn")
            ]
        ),
        LearnFestival(
            id: "tmc-festival",
            name: "TMC Festival",
            aliases: ["TMC 电音节"],
            country: "中国",
            city: "多城市",
            foundedYear: "近年兴起",
            frequency: "年度站点",
            tagline: "面向年轻受众的本土电音节 IP。",
            introduction: "TMC Festival 以流行电子乐与现场体验为核心，常见多日程排布与跨风格艺人阵容。",
            genres: ["EDM", "Future Bass", "House"],
            avatarUrl: "https://logo.clearbit.com/tmcfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://tmcfestival.com")
            ]
        )
    ]
}

struct LearnFestivalLink: Hashable {
    let title: String
    let icon: String
    let url: String
}

extension LearnFestival {
    init(web: WebLearnFestival) {
        self.id = web.id
        self.name = web.name
        self.aliases = web.aliases
        self.country = web.country
        self.city = web.city
        self.foundedYear = web.foundedYear
        self.frequency = web.frequency
        self.tagline = web.tagline
        self.introduction = web.introduction
        self.genres = []
        self.avatarUrl = web.avatarUrl
        self.backgroundUrl = web.backgroundUrl
        self.links = web.links.map { LearnFestivalLink(title: $0.title, icon: $0.icon, url: $0.url) }
        self.contributors = web.contributors.isEmpty ? LearnFestival.defaultContributors : web.contributors
        self.isFollowing = web.isFollowing
        self.canEdit = web.canEdit
    }
}

struct LearnFestivalRankingBoard: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let year: Int
    let rankedFestivalIDs: [String]

    static let djMagTop100Festival2025 = LearnFestivalRankingBoard(
        id: "djmag-top100-festival-2025",
        title: "DJ MAG TOP 100 Festival 2025",
        subtitle: LT("全球电子音乐节年度热度榜", "Global annual popularity ranking of electronic music festivals", "世界の電子音楽フェス年間人気ランキング"),
        year: 2025,
        rankedFestivalIDs: [
            "tomorrowland",
            "edc",
            "ultra",
            "creamfields",
            "soundstorm",
            "vac-music-festival",
            "storm-festival",
            "tmc-festival"
        ]
    )
}

struct LearnFestivalRankedFestival: Identifiable, Hashable {
    var id: String { "\(rank)-\(festival.id)" }
    let rank: Int
    var festival: LearnFestival
}
