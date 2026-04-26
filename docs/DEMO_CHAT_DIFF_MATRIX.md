# `openim-ios-demo` Chat Diff Matrix

> 用途：逐项记录 Raver 当前实现与 `openim-ios-demo` 的差异，并用它驱动 1:1 收口。

## Status Legend

- `open`: 差异已确认，尚未解决
- `in_progress`: 正在处理
- `resolved`: 已对齐到 demo 基线
- `accepted`: 明知存在差异，明确选择保留

## Rules

- 每个差异项必须能落到具体页面、具体交互、具体文件
- 不允许写“感觉差不多”
- 只要不是 demo 原行为，就先记为差异
- 目标是把 `accepted` 压到接近 0

## Matrix

| ID | Area | Demo Baseline | Current Raver | Gap Type | Target File / Module | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C001 | Conversation List | 待补 | 待补 | structure | `OpenIMDemoBaseline/Conversation` | in_progress | baseline 目录与源码清单已建立，但 demo 原列表页尚未接线 |
| C002 | Chat Container | 待补 | `DemoAlignedChatViewController` | structure | `OpenIMDemoBaseline/Chat` | in_progress | baseline 占位入口、seed、chat context 已建立，demo 原容器尚未替换主路径 |
| C003 | Input Bar | 待补 | 当前 UIKit 复刻版输入区 | interaction | `OpenIMDemoBaseline/Chat` | open | 要对齐 demo 原输入区组织 |
| C004 | Text Message Cell | 待补 | 当前文本 cell | visual | `OpenIMDemoBaseline/Chat` | open | 需与 demo 原 cell 比对 |
| C005 | Media Message Cell | 待补 | 当前媒体 cell | visual/interaction | `OpenIMDemoBaseline/Chat` | open | 图片/视频/语音/文件分开核对 |
| C006 | Message Lifecycle | demo local echo / ack replace / resend | 当前 RaverChatController 链路 | state_machine | `OpenIMDemoBaseline/Chat` | in_progress | baseline `MessageInfo` / `ConversationInfo` 桥已落地，但 demo 原 controller/provider 未接入 |
| C007 | Pagination | demo top pagination behavior | 当前已稳定，但未证实同源 | interaction/state_machine | `OpenIMDemoBaseline/Chat` | in_progress | 当前功能已稳定，后续要通过 demo 原 `DefaultDataProvider` / controller 同源化收口 |
| C008 | Jump To Bottom | 待补 | 当前复刻版 | visual/interaction | `OpenIMDemoBaseline/Chat` | open | 需要和 demo UI/显隐时机逐项比 |
| C009 | Chat Setting | 待补 | 当前 Raver 设置流 | structure/navigation | `OpenIMDemoBaseline/ChatSetting` | in_progress | baseline 目录与导入清单已建立，尚未开始页面接线 |
| C010 | Search | 待补 | 当前会话内搜索实现 | structure/interaction | `OpenIMDemoBaseline/Chat` | open | 后续补 demo 搜索路径 |

## Recommended Fill Order

1. Conversation list
2. Chat container
3. Input bar
4. Message cells
5. Pagination / auto-scroll / jump-to-bottom
6. Message menu / preview
7. Settings
8. Search

## Completion Standard

一个条目只有在以下条件全部满足时才能从 `open` 变成 `resolved`：

- 页面或机制已切到 baseline 版本
- 视觉与交互已对齐 demo
- 代码职责不再依赖旧 `DemoAligned*` 主路径
