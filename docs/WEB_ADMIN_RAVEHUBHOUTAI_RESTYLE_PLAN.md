# Web 后台改造方案：对齐 `thirdparty/ravehubhoutai`

## 1. 目标

本次改造目标已经明确收敛为：

- 只改 `web` 后台的视觉排版与页面样式
- 尽量完整对齐 `thirdparty/ravehubhoutai` 的视觉语言、布局骨架和界面层次
- 不改后台业务逻辑
- 不改接口调用方式
- 不改鉴权模型
- 不改当前 Next 路由体系

也就是说，这一轮是“纯前端表现层改造”，不是后台技术栈迁移。

## 2. 已确认现状

### 2.1 当前项目后台现状

- 主项目后台位于 `web/src/app/admin/**`
- 当前主站技术栈是 `Next 15 + React 18 + Tailwind 3`
- 当前后台并没有统一的 `admin/layout.tsx` 壳层
- `/admin` 工作台和 `/admin/content/**` 已有两套不同风格
- 现有全局样式偏深色、Apple 风格，和 `ravehubhoutai` 的浅色玻璃拟态风格明显不同
- 现有基础 UI 组件较轻，只包含少量 `Button / Card / Input / Toast`
- 当前后台已有较多业务页面，不能简单推倒重写为纯静态模板

### 2.2 `thirdparty/ravehubhoutai` 现状

- 参考项目是独立前端，不是 Next，而是 `Vite + React`
- 使用了 `Tailwind 4`
- 组件体系偏 `shadcn/Radix` 风格
- 依赖中包含：
  - `lucide-react`
  - `class-variance-authority`
  - `clsx`
  - `tailwind-merge`
  - 多个 `@radix-ui/*`
  - `sonner`
  - `motion`
  - `recharts`
- 视觉上是明显的浅底、玻璃卡片、圆角大、阴影柔和、侧边栏与主内容分区明确的 Admin Shell

## 3. 关键技术判断

### 3.1 本轮不做框架迁移

既然目标已经明确为“只改视觉排版”，那本轮不需要做下面这些事：

- 不迁移到独立 Vite 应用
- 不重构为 React Router
- 不因为参考项目使用 `Tailwind 4` 就强制升级当前 `web`
- 不为了对齐样式而重写后台业务组件的数据层

### 3.2 本轮采用的落地原则

- 保留 `web/src/app/admin/**` 现有页面与路由
- 保留当前 `Next 15 App Router`
- 保留现有 API client、鉴权逻辑、角色逻辑和页面职责
- 只替换视觉壳层、页面编排、样式 tokens、基础外观组件和布局结构

### 3.3 我的建议

按“视觉层完全对齐、技术底座尽量不动”的方式推进：

- 先做统一后台 Shell
- 再把 `/admin` 和 `/admin/content` 等核心页面排版改成 `ravehubhoutai` 风格
- 最后逐页收口表格、按钮、卡片、表单和筛选区样式

## 4. 改造目标架构

建议将后台改造成下面这套结构：

```text
web/src/
  app/
    admin/
      layout.tsx                 # 新增统一后台壳层
      page.tsx                   # 工作台首页，改成 ravehubhoutai 风格
      ...
  components/
    admin-v2/
      shell/
        AdminShell.tsx
        AdminSidebar.tsx
        AdminTopbar.tsx
        AdminRightRail.tsx
      cards/
        StatCard.tsx
        ActionCard.tsx
        SectionCard.tsx
      tables/
      forms/
      charts/
    ui/
      button.tsx
      card.tsx
      input.tsx
      badge.tsx
      dialog.tsx
      tabs.tsx
      table.tsx
      ...
  lib/
    admin/
      navigation.ts
      theme.ts
      role-policy.ts
  styles/
    admin-ravehub.css
    admin-theme-tokens.css
```

## 5. 样式改造所需依赖

如果只做视觉层改造，`web` 需要的是“最小依赖补齐”，而不是整套参考项目全量搬运。

### 5.1 必需依赖

- `lucide-react`
- `clsx`
- `tailwind-merge`
- `class-variance-authority`

### 5.2 可能需要引入的轻量组件依赖

优先级按后台页面复用度排序：

- `@radix-ui/react-dialog`
- `@radix-ui/react-dropdown-menu`
- `@radix-ui/react-select`
- `@radix-ui/react-tabs`
- `@radix-ui/react-tooltip`
- `@radix-ui/react-separator`
- `@radix-ui/react-scroll-area`
- `@radix-ui/react-avatar`
- `@radix-ui/react-slot`

### 5.3 可选依赖

- `sonner`
- `motion`
- `recharts`

说明：

- 本轮目标是外观对齐，不是依赖对齐
- 不是所有 `ravehubhoutai` 依赖都要原封不动搬进来
- 我们只引入为了实现视觉和交互外壳真正需要的子集

## 6. 样式系统迁移要求

### 6.1 必须迁移的设计语言

- 浅色背景主基调
- 玻璃拟态卡片
- 更大的圆角体系
- 统一柔和阴影
- 左侧固定导航 + 顶部搜索工具栏
- 高识别度的数据卡与工作区入口卡
- 更强的模块分区和页面层次

### 6.2 不建议直接照抄的部分

- 参考项目里的英文文案
- 与房地产业务强绑定的卡片结构
- 演示性质的头像、统计和营销式占位数据
- 与当前 Raver 后台信息架构不符的分组命名

### 6.3 我们要保留的业务现实

- 当前 `/admin` 不是单一 dashboard，而是多个运营模块入口
- `/admin/content/**` 已经有较深的业务页面链路
- 用户、会话、通知、预登记、举报、处罚等页面都有自己的表单和数据表

所以最终做法应该是：

- 视觉和交互语言尽量像 `ravehubhoutai`
- 信息结构和模块命名仍然遵循 Raver 的业务后台

## 7. 页面改造路线

建议分 4 个阶段推进。

### Phase 1：打后台统一壳层

目标：

- 新增 `web/src/app/admin/layout.tsx`
- 新建统一后台 Shell
- 统一侧边栏、顶部栏、内容容器、右侧辅助栏
- 引入新的后台 theme tokens

本阶段产出：

- 所有 `/admin/**` 页面先进入同一个外壳
- 即便内部页面暂时还是旧内容，也先统一“框架感”

### Phase 2：先改 `/admin` 工作台首页

目标：

- 把当前 `/admin/page.tsx` 改造成最接近 `ravehubhoutai` 的首页
- 左侧导航映射为 Raver 的真实模块
- 中间主区域展示后台主入口和关键状态
- 右侧辅助区承载当前用户、快捷入口、最近任务或系统提示

本阶段产出：

- 用户一进入后台，整体观感已经完成切换
- 后续页面能以同一风格继续铺开

### Phase 3：改造高频模块页面

优先顺序建议：

1. `/admin/content`
2. `/admin/users`
3. `/admin/pre-registrations`
4. `/admin/notification-center`
5. `/admin/auth-sessions`

目标：

- 统一标题区
- 统一筛选区
- 统一数据卡
- 统一表格和表单样式
- 统一空态、加载态、错误态

### Phase 4：清理旧组件和风格分叉

目标：

- 逐步淘汰旧的后台专用零散样式
- 合并重复的 `Button / Card / Input / Table / Filter Bar`
- 将后台 UI 收束为一套稳定组件体系

## 8. 导航重构建议

建议新的左侧导航以当前后台真实模块为主，而不是照抄参考项目菜单。

建议一级导航：

- 工作台
- 内容管理
- 用户与账号
- 审核与治理
- 运营工具
- 系统与会话

建议二级映射：

- 工作台
  - 后台总览
- 内容管理
  - 内容控制台
  - 活动
  - 主办方
  - DJ
- 审核与治理
  - 内容贡献审核
  - DJ 绑定审核
  - 举报审核
  - 账号处罚
- 用户与账号
  - 用户管理
  - 账号删除
  - 登录会话
- 运营工具
  - 预登记
  - 通知中心
- 系统与会话
  - 系统状态
  - 审计与登录态

## 9. 目录与实现建议

### 9.1 不建议做的事

- 不建议直接把 `thirdparty/ravehubhoutai/src/app/components/**` 原样复制进 `web`
- 不建议一口气把全部页面重写
- 不建议本轮同时做“独立后台拆分 + 样式重构 + 权限重构”

### 9.2 建议做的事

- 先抽取其设计 tokens 和 Shell 结构
- 再做 Next 兼容版本组件
- 先覆盖后台首页和壳层
- 再逐页替换

## 10. 风险与注意事项

### 10.1 版本风险

- `ravehubhoutai` 用 `Tailwind 4`
- 当前 `web` 用 `Tailwind 3`

这意味着：

- 不能直接无脑搬它的全部样式文件
- 需要做一次 Tailwind 3 兼容改写，或者单独升级 `web` 到 Tailwind 4

### 10.2 运行时风险

- `ravehubhoutai` 使用的是 Vite 约定
- 当前 `web` 是 Next App Router

这意味着：

- 路由、入口文件、全局注入方式都不能直接照搬

### 10.3 业务连续性风险

- 后台页数不少
- 某些页面已经有复杂表单和审核流

这意味着：

- 我们应该优先做“壳层统一 + 高频页面优先”
- 不应该先追求所有页面一次性百分百像参考模板

## 11. 我建议的实施顺序

1. 先由你拍板本轮采用 `方案 A` 还是 `方案 B`
2. 我在 `web` 内搭一套 `admin-v2` 基础框架
3. 我先改 `/admin` 首页和 `/admin/content` 总入口
4. 你确认方向后，再批量推进其余后台页面

## 12. 需要你拍板的点

既然本轮只做视觉层，真正还需要你拍板的点已经缩小了。

### 已确认决策

- 视觉忠实度：尽量完全保持和 `thirdparty/ravehubhoutai` 一致
- 主题方向：尽量完全保持和 `thirdparty/ravehubhoutai` 一致
- 右侧辅助栏：允许按页面职责不同而变化
- 左侧菜单：采用参考站的分组表达，但重新映射为 Raver 自己的后台模块
- 改造范围：`/admin/**` 可见页面全部迁移视觉壳层

### A. 视觉忠实度

请你确认以下二选一：

- `B1` 高度还原参考站布局与玻璃风格，但文案和业务模块换成 Raver
- `B2` 只借用它的框架和风格语言，不追求 1:1 版式

我的推荐：`B1`

### B. 后台主题方向

请你确认以下二选一：

- `B1` 全后台切到参考站的浅色玻璃主题
- `B2` 保留部分当前深色后台页面，仅首页和壳层改浅色

我的推荐：`B1`

### C. 右侧辅助栏内容

参考项目右侧区域更偏展示型，我们需要决定它在 Raver 后台里放什么。

建议候选：

- `C1` 当前管理员信息 + 快捷入口 + 最近操作
- `C2` 当前管理员信息 + 系统健康摘要 + 待处理任务
- `C3` 当前管理员信息 + 审核队列摘要 + 通知/预登记快捷入口

我的推荐：`C2`

### D. 左侧菜单编排

请你确认以下二选一：

- `D1` 保持现在的业务路由结构，只重做样式和分组
- `D2` 借这次机会顺手重排后台信息架构

我的推荐：`D1`

### E. 本轮范围

请你确认以下二选一：

- `E1` 本轮先做壳层 + 首页 + 内容控制台 + 用户管理几个高频页
- `E2` 直接把 `/admin/**` 可见页面一轮全改

我的推荐：`E1`

## 13. 结论

这次改造完全可做，而且在你已经明确“只改视觉层”之后，路线会简单很多：

- 保留当前 `Next` 后台运行方式
- 保留全部业务逻辑与路由
- 只在 `web` 里落一套 `ravehubhoutai` 风格的 Admin Shell、排版和外观组件
- 先统一壳层和首页
- 再分阶段把各业务模块视觉收口

只要你把上面的 A-E 五个点拍板，我就可以直接开始第一阶段改造。
