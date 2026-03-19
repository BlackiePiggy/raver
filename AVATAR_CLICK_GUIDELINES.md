# 头像和昵称点击跳转开发规范

## 原则
所有显示用户头像和昵称的地方都应该支持点击跳转到对应用户的个人主页。

## 实现方式

### 1. 使用可复用组件
创建一个可复用的 `UserAvatarButton` 组件：

```swift
struct UserAvatarButton: View {
    let user: UserSummary
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 头像
                if let avatar = AppConfig.resolvedURLString(user.avatarURL), !avatar.isEmpty {
                    AsyncImage(url: URL(string: avatar)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(RaverTheme.card)
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(RaverTheme.accent.opacity(0.2))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(String(user.displayName.prefix(1)))
                                .font(.caption.bold())
                        )
                }

                // 昵称和用户名
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(RaverTheme.primaryText)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

### 2. 在父视图中管理导航

每个包含用户信息的视图都应该：

1. 添加状态变量：
```swift
@State private var selectedUserForProfile: UserSummary?
```

2. 添加导航目标：
```swift
.navigationDestination(item: $selectedUserForProfile) { user in
    UserProfileView(userID: user.id)
}
```

3. 在点击时设置状态：
```swift
UserAvatarButton(user: someUser, size: 34) {
    selectedUserForProfile = someUser
}
```

### 3. 已实现的地方

✅ **PostCardView** - 动态卡片的作者信息
- 通过 `onAuthorTap` 回调实现

✅ **PostDetailView** - 动态详情页
- 作者信息可点击
- 评论者信息可点击

✅ **ProfileView** - 个人主页
- 粉丝/关注列表可点击

### 4. 需要检查的地方

以下位置需要确保实现了点击跳转：

- [ ] **FeedView** - 动态流
- [ ] **MessagesHomeView** - 消息列表中的用户
- [ ] **ChatView** - 聊天界面的对方用户
- [ ] **NotificationsView** - 通知中的用户
- [ ] **SearchView** - 搜索结果中的用户
- [ ] **SquadProfileView** - 小队成员列表
- [ ] **FollowListView** - 关注/粉丝列表
- [ ] **WebModulesView** - DJ列表和详情页

### 5. DJ头像和名称

对于DJ信息，应该跳转到DJ详情页：

```swift
@State private var selectedDJForDetail: WebDJ?

.navigationDestination(item: $selectedDJForDetail) { dj in
    DJDetailView(djID: dj.id)
}
```

### 6. 开发检查清单

在添加任何显示用户信息的UI时，请检查：

- [ ] 头像是否可点击？
- [ ] 昵称是否可点击？
- [ ] 是否添加了 `selectedUserForProfile` 状态？
- [ ] 是否添加了 `.navigationDestination`？
- [ ] 点击后是否正确设置状态？
- [ ] 是否使用了 `.buttonStyle(.plain)` 避免默认按钮样式？

### 7. 代码审查要点

在代码审查时，如果看到以下代码模式，请确认是否支持点击：

```swift
// ❌ 不可点击 - 需要修复
Text(user.displayName)

// ✅ 可点击 - 正确实现
Button {
    selectedUserForProfile = user
} label: {
    Text(user.displayName)
}
.buttonStyle(.plain)
```

## 总结

遵循这些规范可以确保用户体验的一致性，让用户在任何地方看到头像和昵称时都能自然地点击查看详情。
