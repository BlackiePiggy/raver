# Raver iOS App 设计规范

## 技术栈
- **语言**: Swift 5.9+ / SwiftUI
- **最低支持**: iOS 16.0+
- **架构**: MVVM + Combine
- **网络**: URLSession / Alamofire
- **图片加载**: Kingfisher
- **本地存储**: Core Data / Realm
- **认证**: Keychain

## 设计原则

### 1. 遵循iOS设计规范
- 使用原生组件和交互模式
- 支持Dark Mode
- 适配Safe Area
- 支持动态字体大小
- 无障碍访问(VoiceOver)

### 2. 性能优化
- 图片懒加载和缓存
- 列表虚拟化
- 后台任务管理
- 内存管理

### 3. 离线支持
- 缓存关键数据
- 离线浏览已加载内容
- 网络状态提示

## 屏幕尺寸适配

### 支持设备
- iPhone SE (3rd gen): 375 x 667 pt
- iPhone 14/15: 390 x 844 pt
- iPhone 14/15 Pro: 393 x 852 pt
- iPhone 14/15 Plus: 428 x 926 pt
- iPhone 14/15 Pro Max: 430 x 932 pt

### 布局策略
- 使用Auto Layout / SwiftUI自适应布局
- 关键内容在安全区域内
- 底部Tab Bar高度: 49pt (不含Safe Area)
- 顶部Navigation Bar高度: 44pt

## 导航结构

### Tab Bar (底部导航)
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    主要内容区域                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
│  首页      活动      发现      我的      更多             │
│  [Home]  [Events]  [Explore]  [Profile]  [More]       │
└─────────────────────────────────────────────────────────┘
```

### Tab配置
```swift
enum TabItem: String, CaseIterable {
    case home = "首页"
    case events = "活动"
    case explore = "发现"
    case profile = "我的"
    case more = "更多"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .events: return "calendar"
        case .explore: return "safari"
        case .profile: return "person.fill"
        case .more: return "ellipsis"
        }
    }
}
```

## 页面设计

### 1. 首页 (Home)

```swift
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索栏
                    SearchBar()
                        .padding(.horizontal)

                    // 即将到来的活动
                    UpcomingEventsSection()

                    // 本周新歌
                    NewReleasesSection()

                    // 热门DJ
                    TrendingDJsSection()

                    // 风格探索
                    GenresSection()
                }
                .padding(.vertical)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Raver")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
```

#### 组件设计

**搜索栏**
```swift
struct SearchBar: View {
    @State private var searchText = ""

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textTertiary)

            TextField("搜索活动、DJ、风格...", text: $searchText)
                .foregroundColor(.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Color.bgSecondary)
        .cornerRadius(12)
    }
}
```

**活动卡片 (横向滚动)**
```swift
struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面图
            AsyncImage(url: URL(string: event.coverImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.bgTertiary)
                    .overlay(ProgressView())
            }
            .frame(width: 280, height: 157)
            .cornerRadius(12)
            .clipped()

            // 活动信息
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(event.city)
                        .font(.caption)
                }
                .foregroundColor(.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(event.startDate.formatted())
                        .font(.caption)
                }
                .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 280)
    }
}
```

### 2. 活动页面 (Events)

```swift
struct EventsView: View {
    @State private var selectedFilter: EventFilter = .all
    @State private var showFilterSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选栏
                FilterBar(selectedFilter: $selectedFilter, showSheet: $showFilterSheet)

                // 活动列表
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredEvents) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                EventListCard(event: event)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("活动")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet()
            }
        }
    }
}
```

**活动列表卡片**
```swift
struct EventListCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // 封面图
            AsyncImage(url: URL(string: event.coverImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.bgTertiary)
            }
            .frame(width: 100, height: 100)
            .cornerRadius(8)
            .clipped()

            // 活动信息
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                Label(event.city, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Label(event.startDate.formatted(), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                // 风格标签
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(event.genres, id: \.self) { genre in
                            GenreTag(genre: genre)
                        }
                    }
                }

                Spacer()
            }

            Spacer()

            // 操作按钮
            VStack {
                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color.bgSecondary)
        .cornerRadius(12)
    }
}
```

### 3. 活动详情页

```swift
struct EventDetailView: View {
    let event: Event
    @State private var showCheckInSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 封面图
                AsyncImage(url: URL(string: event.coverImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.bgTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .clipped()

                VStack(alignment: .leading, spacing: 16) {
                    // 标题和评分
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        HStack {
                            RatingStars(rating: event.rating)
                            Text("\(event.rating, specifier: "%.1f")")
                                .foregroundColor(.textSecondary)
                            Text("(\(event.checkInCount) 打卡)")
                                .foregroundColor(.textTertiary)
                        }
                    }

                    // 基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "calendar", text: event.dateRange)
                        InfoRow(icon: "location.fill", text: event.fullAddress)
                        InfoRow(icon: "music.note", text: event.genresText)
                    }

                    // 操作按钮
                    HStack(spacing: 12) {
                        Button(action: { showCheckInSheet = true }) {
                            Label("打卡", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryPurple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: {}) {
                            Image(systemName: "calendar.badge.plus")
                                .padding()
                                .background(Color.bgTertiary)
                                .foregroundColor(.textPrimary)
                                .cornerRadius(12)
                        }

                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .padding()
                                .background(Color.bgTertiary)
                                .foregroundColor(.textPrimary)
                                .cornerRadius(12)
                        }
                    }

                    Divider()

                    // 演出阵容
                    LineupSection(djs: event.djs)

                    Divider()

                    // 活动介绍
                    VStack(alignment: .leading, spacing: 8) {
                        Text("活动介绍")
                            .font(.headline)
                            .foregroundColor(.textPrimary)

                        Text(event.description)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                    }

                    Divider()

                    // 用户打卡
                    CheckInsSection(checkIns: event.recentCheckIns)
                }
                .padding()
            }
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckInSheet) {
            CheckInSheet(event: event)
        }
    }
}
```

### 4. DJ页面

```swift
struct DJDetailView: View {
    let dj: DJ
    @State private var isFollowing = false
    @State private var showFanBadgeSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: dj.bannerUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.bgTertiary)
                    }
                    .frame(height: 200)
                    .clipped()

                    // 渐变遮罩
                    LinearGradient(
                        colors: [.clear, Color.bgPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                }

                // DJ信息
                VStack(spacing: 16) {
                    // 头像
                    AsyncImage(url: URL(string: dj.avatarUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.bgTertiary)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.bgPrimary, lineWidth: 4))
                    .offset(y: -60)
                    .padding(.bottom, -60)

                    // 名称和风格
                    VStack(spacing: 8) {
                        Text(dj.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(dj.genres, id: \.self) { genre in
                                    GenreTag(genre: genre)
                                }
                            }
                        }

                        HStack(spacing: 16) {
                            Label("\(dj.followerCount.formatted()) 粉丝", systemImage: "person.2.fill")
                            Label(dj.country, systemImage: "location.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    }

                    // 操作按钮
                    HStack(spacing: 12) {
                        Button(action: { isFollowing.toggle() }) {
                            Label(isFollowing ? "已关注" : "关注", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFollowing ? Color.bgTertiary : Color.primaryPurple)
                                .foregroundColor(isFollowing ? .textPrimary : .white)
                                .cornerRadius(12)
                        }

                        Button(action: { showFanBadgeSheet = true }) {
                            Label("挂粉丝牌", systemImage: "star.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.primaryPurple, Color.primaryBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Tab切换
                    DJContentTabs(dj: dj)
                }
                .padding()
            }
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFanBadgeSheet) {
            FanBadgeSheet(dj: dj)
        }
    }
}
```

### 5. 我的页面 (Profile)

```swift
struct ProfileView: View {
    @State private var user: User?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息
                    VStack(spacing: 16) {
                        // 头像
                        AsyncImage(url: URL(string: user?.avatarUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.bgTertiary)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                        // 用户名
                        VStack(spacing: 4) {
                            Text(user?.displayName ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)

                            Text("@\(user?.username ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)

                            if let location = user?.location {
                                Label(location, systemImage: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        // 粉丝牌
                        if let badges = user?.fanBadges, !badges.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(badges) { badge in
                                        FanBadgeView(badge: badge)
                                    }
                                }
                            }
                        }

                        // 编辑资料按钮
                        NavigationLink(destination: EditProfileView()) {
                            Text("编辑资料")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.bgTertiary)
                                .foregroundColor(.textPrimary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.bgSecondary)
                    .cornerRadius(16)

                    // 统计数据
                    HStack(spacing: 0) {
                        StatItem(value: user?.eventCount ?? 0, label: "活动")
                        Divider().frame(height: 40)
                        StatItem(value: user?.djCount ?? 0, label: "DJ")
                        Divider().frame(height: 40)
                        StatItem(value: user?.followingCount ?? 0, label: "关注")
                    }
                    .padding()
                    .background(Color.bgSecondary)
                    .cornerRadius(16)

                    // 功能列表
                    VStack(spacing: 0) {
                        NavigationLink(destination: MyCheckInsView()) {
                            MenuRow(icon: "checkmark.circle.fill", title: "我的打卡", color: .accentGreen)
                        }
                        Divider().padding(.leading, 56)

                        NavigationLink(destination: MySavesView()) {
                            MenuRow(icon: "bookmark.fill", title: "我的收藏", color: .accentPink)
                        }
                        Divider().padding(.leading, 56)

                        NavigationLink(destination: MyBadgesView()) {
                            MenuRow(icon: "star.fill", title: "成就徽章", color: .accentCyan)
                        }
                        Divider().padding(.leading, 56)

                        NavigationLink(destination: SettingsView()) {
                            MenuRow(icon: "gearshape.fill", title: "设置", color: .textSecondary)
                        }
                    }
                    .background(Color.bgSecondary)
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
```

## 组件库

### 1. 按钮样式

```swift
// Primary Button
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primaryPurple)
                .cornerRadius(12)
        }
    }
}

// Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.bgTertiary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderPrimary, lineWidth: 1)
                )
        }
    }
}
```

### 2. 标签组件

```swift
struct GenreTag: View {
    let genre: String

    var body: some View {
        Text(genre)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.accentCyan)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.bgTertiary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentCyan.opacity(0.3), lineWidth: 1)
            )
    }
}

struct FanBadgeView: View {
    let badge: FanBadge

    var body: some View {
        HStack(spacing: 4) {
            Text(badge.name)
            Text("Lv.\(badge.level)")
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.primaryPurple, Color.primaryBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
}
```

### 3. 加载状态

```swift
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.primaryPurple)

            Text("加载中...")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
```

### 4. 空状态

```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.textTertiary)

            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primaryPurple)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
```

## 动画效果

### 1. 页面转场
```swift
.transition(.asymmetric(
    insertion: .move(edge: .trailing),
    removal: .move(edge: .leading)
))
```

### 2. 按钮点击
```swift
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
```

### 3. 加载动画
```swift
.opacity(isLoading ? 0.5 : 1.0)
.overlay(
    isLoading ? ProgressView() : nil
)
```

## 颜色定义

```swift
extension Color {
    // 主色调
    static let primaryPurple = Color(hex: "8B5CF6")
    static let primaryBlue = Color(hex: "3B82F6")
    static let accentGreen = Color(hex: "10B981")
    static let accentPink = Color(hex: "EC4899")
    static let accentCyan = Color(hex: "06B6D4")

    // 背景色
    static let bgPrimary = Color(hex: "0F0F0F")
    static let bgSecondary = Color(hex: "1A1A1A")
    static let bgTertiary = Color(hex: "262626")
    static let bgElevated = Color(hex: "2D2D2D")

    // 文字色
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "E5E5E5")
    static let textTertiary = Color(hex: "A3A3A3")
    static let textDisabled = Color(hex: "525252")

    // 边框色
    static let borderPrimary = Color(hex: "404040")
    static let borderSecondary = Color(hex: "2D2D2D")

    // Hex初始化
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

## 网络层设计

```swift
class APIService {
    static let shared = APIService()
    private let baseURL = "https://api.raver.app/v1"

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        // 实现网络请求
    }
}

enum APIEndpoint {
    case events
    case eventDetail(id: String)
    case djs
    case djDetail(id: String)
    case checkIn
    // ...
}
```

## 本地存储

```swift
class CacheManager {
    static let shared = CacheManager()

    func saveEvents(_ events: [Event]) {
        // Core Data / Realm 存储
    }

    func loadEvents() -> [Event] {
        // 从本地加载
    }
}
```

## 推送通知

```swift
class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() {
        // 请求通知权限
    }

    func scheduleEventReminder(for event: Event) {
        // 设置活动提醒
    }
}
```

## 性能监控

- 使用Instruments进行性能分析
- 监控内存使用
- 优化图片加载
- 减少不必要的重绘

## 测试策略

- Unit Tests: 业务逻辑测试
- UI Tests: 关键流程测试
- Snapshot Tests: UI一致性测试
