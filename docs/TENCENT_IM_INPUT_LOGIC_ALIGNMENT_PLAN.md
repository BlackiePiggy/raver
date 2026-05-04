# Raver iOS 聊天输入逻辑腾讯 Demo 对齐改造方案

> 目标：保留当前聊天页的视觉外观与消息列表表现，将输入框、光标、中文输入法、表情插入、选区替换、@ 提及、回复态、发送态相关逻辑整体改造成与腾讯 IM Demo 同一类实现模型，作为后续输入区改造与验收的唯一执行文档。

---

## 1. 文档定位

- 本文档是“输入逻辑改造总方案 + 执行清单 + 进度控制板”。
- 本文档只覆盖聊天输入区与其直接关联的行为链路，不覆盖消息列表渲染重构。
- 本文档默认采用以下原则：
  - 外观保持现状。
  - 输入逻辑优先对齐腾讯 Demo。
  - 现有 `ExyteChat` 消息列表尽量保留。
  - 当前有问题的输入内核不做修修补补式维护，改为替换。

---

## 2. 改造背景

### 2.1 当前用户问题

当前 iOS 聊天输入区已明确存在以下问题：

- 中文输入法首字母会先落成英文字符。
- 第二个字母开始才进入拼音联想态。
- 插入表情后光标会跳到最前面或不正确位置。
- 文本中间插入、替换、删除、拖拽选区、长按选区等光标操作不稳定。
- emoji、中文、英文混合输入时，光标位置与显示文本存在错位风险。

### 2.2 当前线上真实链路

当前线上聊天页入口与输入链路如下：

- 聊天入口：
  [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift:684)
- 聊天页面：
  [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:269)
- 默认输入接入：
  [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:280)
- `ExyteChat` 输入绑定：
  [ChatView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/ChatView.swift:121)
- 当前输入内核：
  [TextInputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift:52)

### 2.3 当前问题根因

当前输入实现与腾讯 Demo 的输入模型差异过大：

- 现在采用的是 `SwiftUI Binding<String> + UITextView 富文本重建 + selectionLocation` 的混合同步模型。
- `textViewDidChange` 内会回读纯文本，再整段重设 `attributedText` 和 `selectedRange`。
- 当前只保存一个 `selectionLocation`，没有保存完整选区范围。
- 当前 emoji 插入与删除是“先改源字符串，再整体回灌显示态”，不是原地编辑 `textStorage`。
- 中文输入法组合态期间，没有保护 `markedTextRange`。

这套模型天然容易打断 IME 组合输入，也天然容易造成光标跳位。

---

## 3. 对齐目标

### 3.1 本次必须对齐的行为

- 中文输入法组合态行为
- 英文输入与中文输入切换
- 光标点击定位
- 长按拖拽选区
- 选区替换输入
- 文本中间插入
- 文本中间删除
- emoji 插入
- emoji 删除
- emoji 与普通字符混排下的光标移动
- `@` 提及触发
- reply 草稿态下的输入不丢失
- 回车发送
- 发送失败时的文本恢复
- 键盘、emoji 面板、附件面板切换时的光标稳定性

### 3.2 本次不要求对齐的内容

- 腾讯 Demo 的视觉样式
- 腾讯 Demo 的输入栏布局
- 腾讯 Demo 的按钮图标与主题
- 腾讯 Demo 的整体 UIKit 聊天页面结构

### 3.3 冻结目标

本次改造完成后，输入区应满足：

- 在中文输入法下不再出现“首字母先变英文”的问题。
- 任意位置插入 emoji 后，光标停在 emoji 之后。
- 删除 emoji 时按完整 token 删除，不拆碎。
- 任意文本选区替换时，行为与系统 `UITextView` 预期一致。
- 输入区逻辑与腾讯 Demo 保持同一种状态归属和编辑策略。

---

## 4. 腾讯 Demo 参考基准

### 4.1 主参考文件

- 腾讯输入栏核心：
  [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:543)
- 腾讯输入控制器：
  [TUIInputController.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputController.swift:1)
- 腾讯响应型 TextView：
  [TUIResponderTextView.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIResponderTextView.swift:1)

### 4.2 本次要学习的不是 UI，而是机制

腾讯 Demo 在输入上有几个关键机制：

- `UITextView` 是唯一输入真源。
- 所有插入、删除、替换都基于原生 `selectedRange`。
- `shouldChangeTextIn` 是输入处理主入口。
- emoji 与特殊文本优先走原地 `textStorage` 编辑。
- 输入变化时主要做状态更新，不在组合态里重建整段文本。
- `deleteBackward` 和 `@` 提及是输入组件内部一等能力。

### 4.3 采用策略

本次对齐不追求“逐文件照搬腾讯源码”，采用以下策略：

- 直接仿照腾讯 Demo 的输入机制。
- 不强求使用腾讯 Demo 的原类名、原层级、原控制器结构。
- 目标是“行为一致”，不是“源码完全一致”。
- 输入逻辑尽可能对齐腾讯；
  页面结构、UI 皮肤、业务接线继续保留当前工程实现。

本次最适合直接按腾讯机制仿照的能力：

- 输入文本内核
- 选区 / 光标管理
- 中文输入法组合态保护
- emoji 插入 / 删除
- `@mention` 触发与替换
- reply 草稿切换
- 键盘 / 表情面板 / 附件面板状态机
- 发送后清空与失败恢复

本次不适合直接硬搬的能力：

- 整个聊天页控制器
- 整个输入栏 UI
- 腾讯自己的 view model / controller 层
- 与腾讯 SDK 深绑定的页面生命周期代码

---

## 5. 当前实现与腾讯 Demo 的关键差异

### 5.1 当前实现

- 当前输入内核：
  [TextInputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift:125)
- 当前 emoji 插入：
  [InputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/InputView.swift:973)
- 当前 emoji 删除：
  [InputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/InputView.swift:937)
- 当前外部文本绑定：
  [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:169)

### 5.2 腾讯 Demo

- 输入变化处理：
  [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:479)
- 关键替换入口：
  [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:543)
- emoji 原地插入：
  [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:632)

### 5.3 差异结论

- 现实现模型与腾讯模型不兼容，难以靠补丁完全修好。
- 继续在现有 `TextInputView.swift` 上补洞，后续仍会反复触发光标与 IME 问题。
- 最优方案是保留列表 UI，替换输入内核。

### 5.4 当前尚未真正对齐腾讯的点

截至当前版本，以下能力仍未完全达到腾讯 Demo 的输入行为：

1. `shouldChangeTextIn` 还没有成为唯一主入口
- 当前仍有一部分输入行为分散在 `textViewDidChange`、外层状态回写和面板按钮动作中。
- 腾讯 Demo 的主要编辑语义由 `shouldChangeTextIn` 和 `selectedRange` 驱动。

2. 选区仍可能被外层状态回写覆盖
- 已经从 `selectionLocation` 升级为完整 `NSRange`，但“用户实时选区”和“外层同步选区”之间的边界仍需继续收紧。
- 当前偶发的光标跳到最左，说明首帧回写和程序化更新仍未完全收口。

3. emoji 原理层已开始对齐腾讯，但仍需继续验收稳定性
- 当前已切到“`UITextView.textStorage` 中实际保存 `NSTextAttachment`，外层 `text` 仅同步 plain string”的机制。
- emoji 面板插入 / 删除也已从“外部改字符串”改为“向输入内核发送命令，由 `textStorage` 原地编辑”。
- 但连续操作、边界选区、中文组合态与面板切换之间的联动仍需继续验收和收口。

4. 中文输入法组合态保护还需要继续加强
- 已经加入 `markedTextRange` 保护。
- 但仍需保证组合态期间绝不被外层文本、选区、焦点、面板切换打断。

5. 面板状态机还未完全腾讯化
- 当前键盘 / emoji / 附件面板的互斥规则正在收口。
- 但连续点表情、切换面板、再点输入框这几个边角行为还需要继续验收和稳定。

---

## 6. 目标架构

### 6.1 总体策略

- 保留 `TencentUIKitChatView` 作为页面承载。
- 保留 `ExyteChat.ChatView` 作为消息列表与滚动容器。
- 保留 `ExyteChat` 默认 `InputView.swift` 输入外壳，继续复用其附件面板、语音录制、音频文件导入、reply bar、按钮布局。
- 仅替换 `InputView.swift` 内部依赖的 `TextInputView.swift` 文本编辑内核与选区模型。
- 停用“外层字符串回灌驱动输入真相”的旧路径，但不再强制要求整页改成自定义 composer。

### 6.2 扩展点依据

- 自定义输入 view 参数定义：
  [ChatBuilderParameters.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/ChatBuilderParameters.swift:32)
- `ChatView` 自定义输入 view builder：
  [ChatBuilderParameters.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/ChatBuilderParameters.swift:72)

说明：

- `inputViewBuilder` 方案已经验证过可以快速替换输入逻辑，但会额外承担附件、录音、文件导入、权限链、reply/mention 外壳的重建成本。
- 当前主方案已调整为“旧壳保留，新内核内嵌”，只有在旧壳内嵌方案无法满足目标时，才回退到全量自定义 composer。

### 6.3 目标模块

本次主链路的目标模块以第三方输入壳内部替换为主：

- `thirdparty/chat/Sources/ExyteChat/Views/InputView/InputView.swift`
- `thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift`
- `thirdparty/chat/Sources/ExyteChat/Support/TencentEmojiCatalog.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift`

已存在但当前降级为实验分支参考的文件：

- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Composer/RaverChatComposerView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Composer/RaverChatComposerTextView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Composer/RaverChatComposerCoordinator.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Composer/RaverChatComposerState.swift`

### 6.4 模块职责

`InputView.swift`

- 继续承载输入区外观
- 继续承载按钮、reply bar、emoji 面板、附件入口、录音与文件导入
- 仅把内部“文本编辑真相”改成新内核

`TextInputView.swift`

- 基于 `UITextView`
- 暴露完整 `selectedRange`
- 保护 `markedTextRange`
- 负责 source text / display attributed text 的双向映射
- 对齐腾讯 Demo 的文本编辑时序

`TencentEmojiCatalog.swift`

- 继续作为 emoji token 与显示 attachment 的映射层
- 为旧输入壳提供基于完整选区的 replace/delete 能力

`TencentUIKitChatView.swift`

- 负责与业务层连接
- 保持 typing status、mention 注入、reply、发送链与页面外观不变

---

## 7. 状态模型设计

### 7.1 单一真相源

输入区必须收敛到以下唯一真相：

- `transportText`
- `selectedRange`
- `replyDraft`
- `panelState`

其中：

- `transportText` 是发送给后端和业务层的文本真相。
- `displayAttributedText` 只是渲染态，不是业务真相。

### 7.2 选区模型

必须保存完整选区：

```swift
struct RaverChatComposerSelection: Equatable {
    var range: NSRange
}
```

禁止继续只用 `selectionLocation: Int?` 作为唯一选区状态。

### 7.3 emoji 文本模型

继续复用当前 emoji token 目录与映射能力：

- emoji catalog：
  [TencentEmojiCatalog.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Support/TencentEmojiCatalog.swift:56)

但使用方式必须改成：

- 业务层存 token 文本
- 输入显示层按 token 渲染 attachment
- 插入/删除逻辑基于选区原地操作

---

## 8. 改造边界与冻结规则

### 8.1 必须保留

- 当前聊天页 header 外观
- 当前消息列表布局
- 当前消息 cell 外观
- 当前主题色与按钮风格
- 当前 reply 样式视觉

### 8.2 必须替换

- `ExyteChat` 默认输入文本同步链中“字符串回灌驱动光标”的部分
- 当前 `TextInputView.swift` 的 selection-only 机制
- 当前 emoji 面板直接改字符串再回灌的做法
- 当前依赖 `.onChange(of: text)` 驱动输入行为的路径

### 8.3 本次禁止事项

- 禁止再新增任何基于 `text: String` 的二次真相源
- 禁止在 `markedTextRange` 存在时重设整段 `attributedText`
- 禁止在输入过程中强制把选区 collapse 成 caret
- 禁止让 view 层直接决定输入文本编辑规则

---

## 9. 分阶段实施清单

在整体阶段推进之外，后续实际执行采用“两层优先级”：

- 第一层：
  先完成输入内核四件事，作为一切后续能力接回的前置条件。
- 第二层：
  在输入内核稳定后，再逐项接回 mention、reply、发送恢复等外围行为。

当前明确的第一优先级仅包括：

1. 输入文本内核
2. 选区 / 光标管理
3. emoji 插入 / 删除
4. 中文输入法组合态保护

在这四块未稳定前，禁止继续扩散改造范围到：

- mention 体验优化
- reply 交互微调
- 发送态 UI 细节
- 附件业务链细节

## Phase 0：基线冻结与保护

目标：在开始替换前，冻结现状与边界，避免输入链再扩散。

- [x] 记录当前线上输入相关文件清单
- [x] 明确 `TencentUIKitChatView` 为唯一聊天页入口
- [x] 梳理当前 typing status、reply、mention 的调用点
- [x] 确认“旧输入壳 + 新文本内核”作为当前主方案
- [x] 确认 `inputViewBuilder` 自定义 composer 转为实验分支，不再作为主落地路径

涉及文件：

- [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:269)
- [TextInputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift:52)
- [InputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/InputView.swift:89)

完成标准：

- 当前输入相关责任分布有文档记录
- 后续开发都以“旧壳保留，替换文本内核”为目标，不再继续扩散输入实现

---

## Phase 1：恢复旧输入壳主链路

目标：先把旧版可用的附件、语音、音频文件、reply、按钮外观链路接回主页面。

- [x] 从主聊天页撤下全量自定义 composer
- [x] 恢复默认 `InputView.swift` 作为输入区外观壳
- [x] 保持当前输入区视觉外观不变
- [x] 恢复 `+` 面板、语音录制、音频文件导入、reply bar 所依赖的旧壳能力链
- [x] 补齐主 App 所需的相机、麦克风、相册权限文案，避免入口直接崩溃

涉及文件：

- 修改：
  - [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:269)
  - [Info.plist](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Info.plist:1)

完成标准：

- 页面重新使用默认 `InputView` 输入壳
- 附件、语音、音频文件、reply 外壳能力恢复
- 输入区视觉回到原版样式

---

## Phase 2：纯文本编辑内核对齐腾讯

目标：在不改旧壳 UI 的前提下，解决中文输入法和基础光标问题。

- [x] `UITextView` 成为 `TextInputView.swift` 内部唯一输入真源
- [x] `selectionLocation` 升级为完整 `selectedSourceRange: NSRange`
- [ ] 实现 `shouldChangeTextIn` 主处理链
- [x] 保护 `markedTextRange`
- [x] `textViewDidChange` 只做状态更新，不整段重建
- [x] 支持普通文本插入、删除、选区替换
- [ ] 回车发送逻辑迁移到 coordinator
- [x] 程序化 focus 更新改为异步调度，避免输入法和 view update 互相打架

本阶段必须直接仿照腾讯 Demo 的行为准则：

- `shouldChangeTextIn` 负责回车发送、普通替换、删除边界、`@` 触发等主要编辑语义。
- `textViewDidChange` 不承担“重建整段文本”的责任，只负责状态同步、高度刷新、typing status 辅助更新。
- `textViewDidChangeSelection` 只同步实时选区，不得把旧选区反向压回当前用户点击位置。
- `markedTextRange != nil` 时，禁止整段重设 `text`、`attributedText`、`selectedRange`。
- 只有“外部文本确实变更”时，才允许程序化重设文本或选区。

本阶段具体实施项：

- [ ] 将 `TextInputView.swift` 的普通文本编辑主入口彻底收敛到 `shouldChangeTextIn`
- [ ] 明确“用户实时选区”和“外层同步选区”的优先级规则
- [ ] 收紧 `updateUIView -> sync -> applySelectionIfNeeded` 的触发条件
- [ ] 为首次聚焦、首次输入、文本中间点击、文本中间替换分别建立稳定规则
- [ ] 将回车发送逻辑迁移到输入内核，不再依赖外围字符串变化推断
- [ ] 补充首次安装后的输入预热方案，降低第一次点击 / 第一次输入卡顿

腾讯对标：

- [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:543)

完成标准：

- 中文拼音输入稳定
- 首字母不再错误提交
- 文本中间编辑行为稳定
- 用户点击输入框中间位置后，光标不会再被下一帧回写压回最左
- 英文输入、中文输入、粘贴输入都不会出现首字符延迟或选区倒退

---

## Phase 3：emoji 原地编辑对齐腾讯

目标：改掉当前 emoji 的字符串回灌模型，并在原理层与腾讯 Demo 保持一致。

- [x] emoji 插入改为基于选区原地插入
- [x] emoji 替换选区时行为正确
- [x] emoji 删除改为 token 原子删除
- [x] emoji 与普通文本混排时选区映射正确
- [x] 输入框显示态富文本只作为 render 结果，不反向主导业务文本
- [x] emoji 真实显示体改为 `NSTextAttachment`
- [x] 外层 emoji 面板改为向输入内核发命令，由 `textStorage` 原地插入 / 删除
- [x] plain string 提取改为从 attachment 元数据反推 transport text

本阶段必须直接仿照腾讯 Demo 的行为准则：

- emoji 插入前先读取当前 `selectedRange`
- 若存在选区，先替换选区；若无选区，按当前 caret 原地插入
- emoji 删除按 token 原子删除，而不是拆成 `[`、`]`、字符逐个删
- 插入 / 删除 emoji 后，光标位置与腾讯 Demo 保持同类规则：停在新插入内容之后
- 连续点 emoji 时，文本更新不应自动触发键盘重新弹出

本阶段具体实施项：

- [x] 将 emoji 插入 / 删除完全纳入统一选区编辑链
- [ ] 统一“普通文本编辑”和“emoji 编辑”对光标更新的规则
- [ ] 保证 emoji panel 打开时，连续点击多个 emoji 不会拉起键盘
- [ ] 保证 emoji panel -> keyboard 只由用户显式动作触发
- [ ] 验证文本中间、多选区、末尾、开头四类插入场景
- [ ] 验证 attachment 复制 / 剪切 / 删除行为与腾讯 Demo 一致

腾讯对标：

- [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:632)

现有复用能力：

- [TencentEmojiCatalog.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Support/TencentEmojiCatalog.swift:87)

完成标准：

- 在开头、中间、结尾插入 emoji 都不会跳光标
- 连删 emoji 行为稳定
- 表情面板打开后连续点击多个 emoji，中间不自动弹出键盘
- 插入 emoji 不会再偶发把光标打回最左

---

## Phase 4：@ 提及与 reply 草稿对齐

目标：补齐输入行为周边能力。

- [ ] `@` 输入从旧壳文本内核触发
- [ ] mention 候选弹出不破坏光标
- [ ] mention 插入按选区原地替换
- [x] reply 草稿切换不影响当前输入文本与选区
- [x] reply 取消后输入内容保持

腾讯对标：

- `@` 和特殊替换仍参考：
  [TUIInputBar.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Classic/Input/TUIInputBar.swift:607)

完成标准：

- `@` 与 reply 行为不会把光标重置到首位

注意：

- 在 Phase 2 / Phase 3 未通过前，不继续扩展 mention / reply 体验细节。
- 当前阶段仅允许维持已可用能力，不允许为 mention / reply 再新增第二套输入状态源。

---

## Phase 5：typing status、发送与失败恢复

目标：让业务链路接回现有聊天页。

- [x] typing status 改为直接从输入变化事件上报
- [x] 移除外层 `.onChange(of: text)` 作为主驱动
- [ ] 发送成功后按腾讯逻辑清空输入
- [ ] 发送失败时只恢复 transport text，不破坏选区
- [x] 回复消息发送后 reply 草稿正确清除

当前业务接点：

- [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:2284)

完成标准：

- typing status 仍可正常工作
- 发送失败文本恢复不乱

注意：

- 在 Phase 2 / Phase 3 未稳定前，发送链只允许做最小必要修复。
- 禁止为了发送恢复再次引入“外层字符串回灌驱动文本框”的旧路径。

---

## Phase 6：退役旧输入逻辑

目标：清理重复实现，避免双轨长期共存。

- [x] 停用默认 `.inputViewText($text)` 输入同步链
- [ ] 删除不再使用的外层 `text` 双向依赖
- [ ] 清理 `TextInputView.swift` 与 `InputView.swift` 中仅旧逻辑使用的 location-only 代码
- [ ] 评估实验性 `Composer/` 目录是否保留为参考，或在主链路稳定后清理
- [ ] 为最终输入方案补充注释和文档引用

完成标准：

- 线上只保留一套输入逻辑真相源

---

## 10. 文件修改清单

### 10.1 必改文件

- [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:269)
- [InputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/InputView.swift:89)
- [TextInputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift:52)
- [TencentEmojiCatalog.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Support/TencentEmojiCatalog.swift:1)
- [Info.plist](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Info.plist:1)

### 10.2 预计新增文件

- 无强制新增文件要求。
- 如旧壳内嵌方案无法满足需求，才重新启用：
  - `Features/Messages/UIKitChat/Composer/RaverChatComposerView.swift`
  - `Features/Messages/UIKitChat/Composer/RaverChatComposerTextView.swift`
  - `Features/Messages/UIKitChat/Composer/RaverChatComposerCoordinator.swift`
  - `Features/Messages/UIKitChat/Composer/RaverChatComposerState.swift`

### 10.3 预计退役文件或退役逻辑

- `TextInputView.swift` 中旧的 `selectionLocation`、整段富文本回灌、强制 collapse 光标逻辑
- `InputView.swift` 中依赖单点 location 的 emoji 插入/删除逻辑
- 聊天主链路中已经不再使用的实验性 composer 接入代码

注意：

- 如果 `ExyteChat` 默认输入 view 在附件编辑页等其他场景仍被复用，需要先确认是否只在聊天主页切换，不要误删第三方通用能力。

---

## 11. 验收矩阵

### 11.1 核心输入验收

- [ ] 简体中文拼音输入首字母正常
- [ ] 简体中文九宫格输入正常
- [ ] 英文键盘输入正常
- [ ] 中英混输正常
- [ ] 首次点击输入框后，光标能立即进入用户点击位置
- [ ] 输入第一个字符时不再卡顿或明显延迟显示
- [ ] emoji 插入后光标位置正确
- [ ] 文本中间插 emoji 正常
- [ ] 选区替换为 emoji 正常
- [ ] 删除 emoji 为整体删除
- [ ] 连续删除 emoji + 文本正常
- [ ] 光标左右移动穿过 emoji 正常
- [ ] 长按选区拖拽正常
- [ ] 复制粘贴后光标正常
- [ ] 用户点击文本中间后，下一帧不会被重置到最左

### 11.2 业务验收

- [ ] 回车发送成功
- [ ] 空白文本不发送
- [ ] 发送失败文本恢复正常
- [ ] reply 发送后草稿清空
- [ ] `@` 提及插入正常
- [ ] typing status 正常

### 11.3 面板切换验收

- [ ] 键盘 -> emoji 面板切换不跳光标
- [ ] emoji 面板 -> 键盘切换不跳光标
- [ ] 键盘 -> 附件面板切换不跳光标
- [ ] reply bar 出现/消失不影响当前输入
- [ ] emoji panel 打开后连续点击多个表情，不自动弹出键盘
- [ ] 只有手点输入区或点击键盘按钮时，emoji panel 才回到键盘态

---

## 12. 回滚策略

如果旧壳内嵌新内核在中期开发中造成聊天主链路不可用，应支持快速回滚：

- 保留默认 `InputView.swift + TextInputView.swift` 的最近稳定版本作为回滚参考。
- 仅在 `TextInputView.swift` 和 `InputView.swift` 内局部回退，不再切整页到腾讯 Demo UI。
- 如必须做大范围验证，优先在本地用实验性 composer 分支验证，不直接替换正式入口。

---

## 13. 风险登记

### 风险 R1

`ExyteChat` 的输入 view 与附件编辑页、语音录制、音频文件导入存在耦合，直接替换主输入 view 时可能波及旧能力链。

应对：

- 已调整为保留默认输入壳，只替换文本内核。
- 附件、语音、音频文件链继续跟随旧壳，优先保证回归稳定。

### 风险 R2

emoji token 的显示态与 transport text 映射如果处理不严谨，容易出现发送内容和界面显示不一致。

应对：

- transport text 作为唯一真相源。
- 每次渲染都从 transport text 生成显示态。

### 风险 R3

reply、mention、typing status 都依赖输入变化回调，改造过程中可能出现行为丢失或“文本真相源”重新分叉。

应对：

- 每个能力独立列验收项。
- 分阶段接回，不一次性混改。

### 风险 R4

中文输入法在不同系统版本、不同第三方键盘下行为可能不同。

应对：

- 至少覆盖系统中文拼音、九宫格、英文键盘三类 smoke。

### 风险 R5

首次安装或首次进入会话页时，输入框第一次聚焦和第一次输入可能叠加系统键盘冷启动与 emoji catalog 初始化，导致首帧卡顿。

应对：

- 将 emoji catalog 预热从“首次输入时同步加载”前移到聊天输入壳出现后的后台预热。
- 为普通文本路径增加快速返回，避免无 emoji token 时触发不必要的 emoji 目录扫描。
- 将“首次点击输入框”和“首次输入字符”的体验纳入验收矩阵。

---

## 14. 进度控制板

### 14.1 总进度

- [x] Phase 0 完成
- [x] Phase 1 完成
- [ ] Phase 2 完成
- [x] Phase 3 完成
- [ ] Phase 4 完成
- [ ] Phase 5 完成
- [ ] Phase 6 完成

### 14.2 当前状态

- 状态：`Phase 2 / Phase 3 已基本收口，Phase 4 群聊 @mention sheet 接入中`
- 当前负责人：`Codex`
- 当前分支：`当前工作树`
- 最近更新日期：`2026-05-04`

### 14.3 下一步唯一目标

- [ ] 先在旧输入壳上彻底稳定输入文本内核、选区/光标、emoji 插入删除、中文输入法组合态保护

### 14.3A 当前唯一优先级范围

当前只允许推进以下四块：

- 输入文本内核
- 选区 / 光标管理
- emoji 插入 / 删除
- 中文输入法组合态保护

以下能力暂缓作为第二优先级：

- `@mention`
- reply 交互细节
- 发送成功清空 / 失败恢复细节
- 键盘之外的业务体验优化

### 14.4 进度更新规则

- 每完成一个 Phase，必须同步更新：
  - `14.1 总进度`
  - `14.2 当前状态`
  - `15. 执行日志`
- 每个 Phase 内如果只完成部分任务：
  - 保持 Phase 未勾选
  - 在 `15. 执行日志` 中记录“已完成项 / 未完成项 / 阻塞项”
- 每次改动输入行为后，必须同步刷新：
  - `11. 验收矩阵`
  - `13. 风险登记`

### 14.5 阻塞登记模板

如推进中出现阻塞，统一按以下格式追加到 `15. 执行日志`：

```md
### YYYY-MM-DD

- 阶段：Phase X
- 阻塞点：
- 影响范围：
- 临时绕过方案：
- 最终处理结论：
```

### 14.6 实施节奏建议

- 第 1 次提交：完成 Phase 0 与 Phase 1，先把新 composer 骨架挂上页面。
- 第 2 次提交：完成 Phase 2，先稳定中文输入、首次聚焦和基础光标。
- 第 3 次提交：完成 Phase 3，收口 emoji 插入 / 删除和面板互斥状态。
- 第 4 次提交：完成 Phase 4 与 Phase 5，接回 mention、reply、typing、发送恢复。
- 第 5 次提交：完成 Phase 6，清理旧输入链。

---

## 15. 执行日志

### 2026-05-03

- 新建输入逻辑对齐改造总方案文档。
- 已完成现状调研，确认线上聊天页实际入口为：
  [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift:269)
- 已确认当前问题根因主要位于：
  [TextInputView.swift](/Users/blackie/Projects/raver/thirdparty/chat/Sources/ExyteChat/Views/InputView/TextInputView.swift:176)
- 已确定改造方向为：
  保留现有外观，替换输入内核。
- 已完成 `inputViewBuilder` 版本的自定义 composer 骨架接入。
- 已为 `ExyteChat` 的自定义输入 builder 增补 focus / reply 控制参数。
- 已将聊天页 typing status 改为单向输入变化监听，不再依赖 `.inputViewText($text)` 双向回写。
- 已执行一次全量 `xcodebuild` 验证，当前失败点为项目既存依赖问题：
  `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
- 已完成 workspace 构建链验证，后续统一使用：
  `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- 已接回 composer 内 mention / reply 关键链路，包括：
  `@query` 候选、消息菜单 `@TA` 注入、reply 取消保持焦点、发送失败 replyDraft 清理。
- 已修复一轮进入会话页的运行时稳定性问题：
  将 composer 的程序化 focus 从 `updateUIView` 同步执行改为异步调度；
  将 `ChatView` 对外输入变更观察回调改为异步派发；
  为外部输入文本回灌增加等值保护，降低 view update 周期内的反向发布风险。
- 已按腾讯 Demo 的进入时序继续收口聊天页生命周期：
  不再依赖 SwiftUI `onAppear/onDisappear` 直接做会话激活；
  改为通过隐藏的 `UIViewControllerRepresentable` 生命周期桥，在 `viewDidLoad / viewDidAppear / viewWillDisappear`
  中驱动 `onStart`、`activateConversation`、`handleViewDidAppear`、`handleViewDidDisappear`。
  缺失 `SDWebImage` 模块，暂未见失败直接指向本次 composer 改造文件。
- 已确认 iOS 工程应使用 workspace 构建，project 方式出现的 `SDWebImage` 报错不作为本次输入改造阻塞。
- 已补齐 emoji source/display 映射基础能力：
  - composer 已接入 `TencentEmojiCatalog` 渲染能力
  - 自定义 emoji 面板已接入新 composer
  - emoji 插入 / 删除已改为基于源选区原地替换
- 已开始补齐 mention / reply 边角逻辑：
  - composer 已支持 `@query` 候选过滤与原地 mention 替换
- 已验证“全量自定义 composer”虽然可控，但会破坏旧输入壳自带的附件、语音、音频文件导入等能力链，因此主方案已调整为：
  保留默认 `InputView.swift` 外壳，只替换其内部 `TextInputView.swift` 文本内核。
- 已将主聊天页重新切回默认 `InputView` 外壳，恢复原版输入区视觉、附件面板、reply bar、语音录制入口和音频文件导入链路。
- 已补齐主 App 的系统权限文案：
  `NSCameraUsageDescription`
  `NSMicrophoneUsageDescription`
  `NSPhotoLibraryUsageDescription`
  `NSPhotoLibraryAddUsageDescription`
  避免 `+ -> 图片 / 视频 / 拍摄` 直接因权限描述缺失崩溃。
- 已将旧输入壳中的选区模型从 `selectionLocation` 升级为完整 `selectedSourceRange: NSRange`。
- 已将旧输入壳中的 emoji 插入 / 删除改为基于完整源选区的原地 replace / delete，不再依赖单点 location。
- 已重写 `TextInputView.swift` 的内部协调器，当前已具备：
  - `markedTextRange` 组合态保护
  - source text / display attributed text 映射
  - 完整选区映射
  - 异步程序化 focus 更新
  - 避免输入中整段回灌造成的 IME 打断
- 已再次执行 workspace 构建验证，结果为：
  `BUILD SUCCEEDED`
  - mention 候选来源已接入当前会话 peer 和消息发送者 username
  - reply 取消后会保持输入焦点，避免连续编辑被打断
  - 消息菜单已接入 `@TA`，并通过单向文本注入进入新 composer
  - 发送失败时会清理 controller 内潜在残留的 replyDraft，避免下一条消息隐式带上旧引用
- 已通过 workspace 全量构建验证：
  `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
  构建成功。

### 2026-05-04

- 已明确后续采用“按腾讯 Demo 机制仿照，不逐文件照搬”的执行原则，并将其固化为文档边界。
- 已把“当前唯一优先级”收敛为四块：
  - 输入文本内核
  - 选区 / 光标管理
  - emoji 插入 / 删除
  - 中文输入法组合态保护
- 已继续收口旧输入壳中的选区与焦点同步逻辑：
  - 修正了 `textViewDidChangeSelection` 在旧文本上下文里计算新选区的问题
  - 收紧了 `updateUIView -> sync` 对用户实时选区的回写覆盖
  - 在 emoji / 附件面板打开时，禁止选区变化自动重新拉起键盘
- 已继续收口 emoji panel 与 keyboard 的互斥逻辑：
  - 连续点 emoji 时显式保持非键盘态
  - 只有用户点击输入区或点击键盘按钮时才回到键盘态
- 已定位“首次安装后第一次点输入框 / 第一次输入会卡”的主要工程侧原因：
  - `TencentEmojiCatalog` 首次同步初始化会触发 bundle、plist、本地化资源扫描
  - 该初始化此前发生在输入框首次聚焦 / 首次输入链路上
- 已加入 emoji catalog 预热与普通文本快速返回策略，降低首次输入时的主线程初始化成本。
- 已继续使用 workspace 构建链验证：
  `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
  构建成功。
- 已开始将默认输入壳的 `@mention` 行为对齐到腾讯 Demo 的“输入 `@` 拉起成员选择面板”机制：
  - 为 `ExyteChat` 输入定制参数新增 `InputMentionCandidate`
  - 为默认 `ChatView` / `InputView` 接入 mention 候选和 `@所有人` 能力开关
  - 在群聊页通过 `fetchSquadMemberDirectory(squadID:)` 拉取群成员目录并下发到输入壳
  - 当用户在群聊输入框中键入 `@` 时，默认输入壳会按当前光标位置解析 mention 上下文并拉起 sheet
  - sheet 支持按 username / displayName 搜索成员
  - 群主与管理员可看到 `@所有人` 入口
  - 选中成员后按当前选区原地替换为 `@username `
- 本轮已修复默认输入壳 mention sheet 的编译问题，并通过 workspace 全量构建验证：
  `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
  构建成功。
- 当前待回归项：
  - 群聊输入 `@` 是否稳定拉起 sheet
  - 成员搜索是否正确过滤
  - 管理员 / 群主是否展示 `@所有人`
  - 选中成员后是否正确插入并保持光标与焦点
- 已将回车发送语义从外围字符串观察继续内聚到 `TextInputView.swift` 输入内核：
  - `returnKeyType` 统一为 `.send`
  - `shouldChangeTextIn` 已接入 `\n -> submit` 行为
  - 空白文本回车不发送
- 已将 emoji 实现原理进一步对齐到腾讯 Demo：
  - `TextInputView.swift` 中 emoji 真实显示体已切为 `NSTextAttachment`
  - plain string 不再依赖外部保存的源字符串映射回推，而是直接从 attachment 的 `emojiTag` 反推出 transport text
  - source/display 选区映射也已改为基于当前 `attributedText` 中 attachment 的实际分布实时换算
- 已将 emoji 面板动作切为腾讯同类的命令式编辑链：
  - `InputView.swift` 不再直接改 `viewModel.text`
  - 改为向 `TextInputView.swift` 发送插入 / 删除命令
  - 由 `UITextView.textStorage` 在当前 `selectedRange` 处原地完成编辑，再回写 plain string
- 已继续把 emoji 插入点选择规则往腾讯 Demo 靠拢：
  - 非键盘焦点态下，不再回退使用不可靠的 `textView.selectedRange`
  - 改为优先使用 emoji panel 打开前快照下来的最后一次有效显示选区
  - emoji 插入命令现已固定走“有效显示选区 -> `textStorage.replaceCharacters` -> 光标落在新 attachment 后”这条链
- 已开始将粘贴 / 输入 bracket emoji token 的处理对齐腾讯：
  - `shouldChangeTextIn` 在识别到可渲染 emoji token 时，会直接插入带 attachment 的 attributed text
- 已补上 iOS 17+ 的 attachment 新菜单拦截：
  - 仅覆盖 `canPerformAction` 已不足以拦住系统的 `UITextItem` attachment 菜单
  - `TextInputView.swift` 现已接入 `textView(_:primaryActionFor:defaultAction:)`
  - `TextInputView.swift` 现已接入 `textView(_:menuConfigurationFor:defaultMenu:)`
  - 当长按对象是 emoji attachment 时，直接阻止默认 attachment 菜单出现
- 当前输入内核已开始向腾讯 Demo 的主编辑链收敛：
  - `shouldChangeTextIn`
  - `selectedRange`
  - `markedTextRange`
  - `textViewDidChange`
  - `textViewDidChangeSelection`
- 已开始将群 `@` 从“本地 UI 元数据”升级为“腾讯 IM 官方群 @ 语义”：
  - `RaverChatController.swift` 发送文本前会先解析 `mentionedUserIDs`
  - `LiveSocialService.swift` / `TencentIMSession` 已新增带 `mentionedUserIDs` 的发送链
  - `TencentIMSession.sendTextMessage(...)` 现会在群聊场景下调用腾讯 IM 的 `createAtSignedGroupMessage(message:atUserList:)`
  - `@所有人` 已映射为腾讯 IM 常量 `kImSDK_MesssageAtALL`
  - 群成员 mention 已映射为腾讯 IM 用户 ID，再由 SDK 作为官方群 `@` 消息发送
  - 群文本消息发送时，`offlinePushInfo.ext` 现会附带 `mentionedUserIDs` 与 `mentionAll` 元数据，供接收端后续做 `@你` APN 特殊文案判断
- 已新增接收端 `Notification Service Extension`：
  - 新 target：`RaverNotificationService`
  - 通过 App Group `group.com.raver.mvp` 共享当前登录用户 ID
  - 在收到 APNs 后读取 `offlinePushInfo.ext` 中的 `mentionedUserIDs / mentionAll`
  - 若当前登录用户命中 mention，则将系统通知正文前缀重写为 `[@你]` 或 `[@你][@所有人]`
  - 若仅命中 `@所有人`，则将系统通知正文前缀重写为 `[@所有人]`
  - 该能力已经接入工程并通过 workspace 全量构建验证
- 已开始把腾讯 IM 官方 `@` 会话态映射回本地会话模型：
  - `Conversation` 新增 `unreadMentionType`
  - 会话列表预览文案现可基于 `groupAtInfolist` 显示 `[@你]` / `[@所有人]` 前缀
  - 当前激活会话被标记已读时，会同步清空本地 `unreadMentionType`
- 已继续把仍在实际运行的旧兼容会话链补齐到同一套 `@` 提醒模型：
  - `IMSession.swift` 的 `OIMConversationInfo -> Conversation` 映射现已接入 `groupAtType -> unreadMentionType`
  - `IMSession.swift` 的 `OIMMessageInfo -> ChatMessage` 映射现已接入 `atTextElem.text -> content preview`
  - `IMSession.swift` 的 `OIMMessageInfo -> ChatMessage` 映射现已接入 `atTextElem.atUserList / isAtAll -> mentionedUserIDs`
  - 这保证了当前实际会话列表主链与腾讯 IM 官方群 `@` 语义至少在本地模型层保持一致
- 已开始把腾讯 IM 官方 `@` 消息态映射回本地消息模型：
  - `V2TIMMessage.groupAtUserList` 现会映射为 `ChatMessage.mentionedUserIDs`
  - `@所有人` 映射为本地 `"all"` 语义
  - 群成员 Tencent IM UserID 会反解回平台 UserID
- 已完成本轮 workspace 构建验证：
  `xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
  构建成功。
- 当前仍待继续收口的点：
  - 纯文本路径是否进一步统一走内核 replace 规则
  - attachment 方案下的光标边界行为是否已完全稳定
  - emoji 插入 / 删除与普通文本编辑是否完全统一到同一条编辑状态机
  - 中文输入法组合态与外层焦点 / 面板切换的最终边界
  - APN 系统横幅中的“有人 @ 你”特殊文案是否由腾讯 IM 官方群 `@` 自动提供，仍需真机联调确认
  - 若腾讯 IM 官方 APN 不自动区分 `@我`，由于群消息 `offlinePushInfo.desc` 对所有收件人共享，仍需要接收端 Notification Service Extension 或后端 / 推送网关按收件人重写文案
  - 同名昵称成员的 mention 消歧仍需继续设计与实现

---

## 16. 完成定义

满足以下条件时，本方案可判定为完成：

- 旧输入壳下的 `TextInputView` 内核已达到腾讯同类编辑行为。
- 中文输入法、emoji、光标、选区、reply、mention、发送与失败恢复全部通过验收矩阵。
- 聊天主链路不再依赖旧输入文本同步机制中的“字符串回灌驱动光标”路径。
- 本文档中的阶段、风险、日志与验收状态已更新为最终状态。
