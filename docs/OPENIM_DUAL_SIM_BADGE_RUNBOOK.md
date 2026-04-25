# OpenIM 双模拟器红点验收 Runbook

## 1. 目标

验证消息 Tab 的统一红色未读 badge 在以下场景实时更新：

- 聊天消息触发（OpenIM 实时链路）
- 社区通知已读触发（社区未读事件链路）
- UIKit 聊天页媒体消息体验（缩略图/预览/进度/失败重发）

并区分“实时更新”与“catch-up 补偿更新”。

## 2. 前置条件

- 服务端已启动，OpenIM 可用
- iOS 工程可运行（`xcworkspace`）
- 两个测试账号均可登录（A、B）
- 设备：两个 iOS 模拟器

脚本已内置启动前保底校验：

- OpenIM：检查 `10001/10002`，必要时自动执行 `docker compose up -d`；
- OpenIM 健康：默认要求 `openim-server/openim-chat` 为 `healthy` 才会继续；
- BFF：默认要求 `localhost:3901` 已监听。

关键环境变量：

- `OPENIM_PROBE_ENSURE_OPENIM=1|0`（默认 `1`）
- `OPENIM_DOCKER_DIR=~/Projects/vendor/openim-docker`
- `OPENIM_PROBE_REQUIRE_HEALTH=1|0`（默认 `1`）
- `OPENIM_PROBE_HEALTH_TARGETS="openim-server openim-chat"`
- `OPENIM_PROBE_ENSURE_BFF=1|0`（默认 `1`）
- `OPENIM_PROBE_BFF_PORT=3901`

## 3. 启动日志探针

脚本路径：

- [`mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh)
- [`mobile/ios/RaverMVP/scripts/openim_probe_digest.sh`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh)
- [`mobile/ios/RaverMVP/scripts/openim_a4_weaknet_replay.sh`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_a4_weaknet_replay.sh)

执行：

```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

可选参数：

```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh "iPhone 17 Pro" "iPhone 17" "com.raver.mvp"
```

推荐模式（默认）：

- `OPENIM_PROBE_LIVE_MODE=summary`（低噪声，每 5 秒输出一行状态）
- 结束时自动执行 digest，直接给出“实时链路/主要 catchup/10102 冲突”结论。
- 若某侧实时流偶发空采集，脚本会自动回填最近窗口日志（默认 180 秒）。
- 另外默认会启用 App 内文件日志合并（`openim-probe.log`），即使 `simctl log stream` 不稳定也能保留关键业务事件。

当你遇到“某一侧经常空采集”时，建议改用快照传输模式（更稳定）：

```bash
OPENIM_PROBE_TRANSPORT=snapshot bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

重要说明（snapshot 模式）：

- 运行中看到 `conn=0 rt=0 catchup=0 ...` 是常见现象；
- `snapshot` 只在 **Ctrl+C / 进程退出** 时执行 `log show` 抓取；
- 不结束探针就去看 `sim*.log`，通常会是 0 行空文件。

可切换模式：

```bash
# 看实时关键行（噪声更高）
OPENIM_PROBE_LIVE_MODE=stream bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh

# 看完整原始日志
OPENIM_PROBE_RAW_MODE=1 OPENIM_PROBE_LIVE_MODE=stream bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh

# 调整空采集自动回填窗口（秒）
OPENIM_PROBE_BACKFILL_SECONDS=300 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh

# 采集传输模式：stream | snapshot
OPENIM_PROBE_TRANSPORT=snapshot bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh

# 可选：90 秒后自动结束（触发快照采集）
OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

日志输出目录：

- `docs/reports/openim-dual-sim-<timestamp>/sim1.log`
- `docs/reports/openim-dual-sim-<timestamp>/sim2.log`
- `docs/reports/openim-dual-sim-<timestamp>/sim1.focus.log`
- `docs/reports/openim-dual-sim-<timestamp>/sim2.focus.log`
- `docs/reports/openim-dual-sim-<timestamp>/sim1.err.log`
- `docs/reports/openim-dual-sim-<timestamp>/sim2.err.log`

模拟器 App 内部日志（由脚本自动打印路径并在退出时合并）：

- `<sim-data-container>/Library/Caches/openim-probe.log`

相关开关：

```bash
# 默认开启：在 probe 退出时把 App 内文件日志合并到 sim1.log/sim2.log
OPENIM_PROBE_USE_APP_LOG=1
```

## 3.1 用脚本自动注入消息（推荐）

当你不想手动在两个模拟器来回点时，可以在服务端直接往 OpenIM 注入文本消息（不走 BFF 聊天兜底链路）：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_PROBE_SESSION_TYPE=single \
OPENIM_PROBE_SENDER_IDENTIFIER=<发送方用户名或ID> \
OPENIM_PROBE_RECEIVER_IDENTIFIER=<接收方用户名或ID> \
OPENIM_PROBE_MESSAGE_COUNT=5 \
OPENIM_PROBE_INTERVAL_MS=600 \
npm run openim:probe:send
```

群聊注入：

```bash
cd /Users/blackie/Projects/raver/server
OPENIM_PROBE_SESSION_TYPE=group \
OPENIM_PROBE_SENDER_IDENTIFIER=<发送方用户名或ID> \
OPENIM_PROBE_GROUP_ID=<squadID> \
OPENIM_PROBE_MESSAGE_COUNT=5 \
npm run openim:probe:send
```

建议流程：先启动 `openim_dual_sim_probe.sh`，再执行一次 `openim:probe:send`，最后 Ctrl+C 结束探针并读取 digest。

## 3.2 A6 新旧聊天页对照验收（必做）

新页（UIKit）验收：

```bash
RAVER_CHAT_FORCE_UIKIT_CHAT_VIEW=1 \
OPENIM_PROBE_TRANSPORT=snapshot \
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

旧页（SwiftUI）回滚验收：

```bash
RAVER_CHAT_FORCE_LEGACY_CHAT_VIEW=1 \
OPENIM_PROBE_TRANSPORT=snapshot \
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

判定：
- 两条链路都应完成“发消息实时更新 + 会话可进入 + badge 更新”；
- 若新页失败而旧页通过，可按回滚 runbook 先切旧页止血。

## 3.3 A4 弱网/抖动回归（建议每次发布前执行）

目标：验证“发送失败反馈 + 点按重试 + 恢复后实时链路回稳”。

一键自动回放（推荐，少手测）：

```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_a4_weaknet_replay.sh
```

自动回放覆盖：

- 自动启动 120s snapshot probe（含 app-probe 合并）；
- 自动注入恢复前后消息（`openim:probe:send`）；
- 自动 `stop openim-chat/openim-server` 短暂停机并恢复；
- 自动跑 digest 并打印关键失败/不可用关键词。

自动回放默认参数（可用环境变量覆盖）：

- `OPENIM_PROBE_SENDER_IDENTIFIER=blackie`
- `OPENIM_PROBE_RECEIVER_IDENTIFIER=uploadtester`
- `OPENIM_PROBE_OUTAGE_SECONDS=15`
- `OPENIM_PROBE_REPLAY_TRANSPORT=snapshot`
- `OPENIM_PROBE_POST_RECOVERY_CAPTURE_SECONDS=25`
- `OPENIM_PROBE_WAIT_TIMEOUT_SECONDS=900`（给 snapshot 收尾留足时间）

执行（90 秒自动收口）：

```bash
OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=90 OPENIM_PROBE_USE_APP_LOG=1 \
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

探针运行后在两台模拟器手动做：

1. 双端进入同一会话，A 端发送 1 条文本确认实时正常；
2. 临时断开 OpenIM（本机）约 10-20 秒：

```bash
cd ~/Projects/vendor/openim-docker
docker compose stop openim-chat openim-server
```

3. A 端继续发送 1 条文本/1 条图片，确认出现失败反馈（例如“失败·点重试”）；
4. 恢复 OpenIM：

```bash
cd ~/Projects/vendor/openim-docker
docker compose start openim-server openim-chat
```

5. 在会话内点按失败消息重试，确认发送成功；再发 1 条文本确认链路恢复。

说明：

- 自动回放主要覆盖“服务抖动 + 链路恢复 + digest 判定”；
- 若需要严格验收 UI 层“失败提示胶囊可见 + 点按重试成功”，仍建议补一次手动第 3/5 步。

通过标准：

- 失败阶段有明确反馈（发送失败提示可见）；
- 恢复后重试可成功；
- digest 里可看到 `realtime > 0`，且恢复后不持续放大 `10102/unavailable`。

## 4. 验收步骤

1. A、B 登录后，B 停留在消息页会话列表。  
2. A 给 B 发送一条文本消息。  
3. 观察 B 的会话列表与 Tab badge 是否立即变化。  
4. B 打开社区通知列表，点击一条未读通知并标记已读。  
5. 观察消息 Tab 红点是否立即减少。  
6. A 在同一会话发送图片与视频各一条，观察：
   - A 端发送区出现媒体进度条并在完成后自动收起；
   - B 端会话内能看到图片/视频缩略图与视频播放标记。
7. B 点击图片/视频消息，确认可进入全屏预览并关闭返回会话。
8. 制造一次失败重发（例如发送中断网后恢复），确认失败消息文案为“点按重发”，点击可重发成功。

## 5. 判定规则

### 5.1 聊天实时链路生效（通过）

日志中应看到：

- `[OpenIMChatStore] realtime message received ...`
- `[AppState] badge recompute source=openim-realtime ...`

且 UI 基本即时变化（无需等 2-3 秒）。

### 5.2 社区事件链路生效（通过）

日志中应看到：

- `[AppState] badge recompute source=community-event ...`

且点击已读后红点立即减少。

### 5.3 命中 catch-up（说明补偿而非实时）

日志中出现：

- `[OpenIMChatStore] catchup messages changed ...`
- `[OpenIMChatStore] catchup conversations changed ...`

说明当前依赖补偿更新，需继续排查实时 listener。

## 6. 快速检索命令

```bash
rg "realtime message received|badge recompute source=openim-realtime" docs/reports/openim-dual-sim-*/sim*.log
rg "badge recompute source=community-event" docs/reports/openim-dual-sim-*/sim*.log
rg "catchup messages changed|catchup conversations changed" docs/reports/openim-dual-sim-*/sim*.log
rg -i "\[DemoAlignedPagination\]|\[DemoAlignedScroll\]|\[DemoAlignedViewport\]|\[DemoAlignedMessageFlow\]" docs/reports/openim-dual-sim-*/sim*.log
```

生成最新一次的诊断结论（不想手看海量日志时）：

```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh
```

`digest` 末尾会输出 `overall`：

- `overall: 双侧日志有效` 才可据此判断“实时链路/补偿链路/10102”；
- `overall: 部分无效` 说明至少一侧采集为空，或没有任何 `App/OpenIM` 事件，本次报告不能用于最终结论。

`digest` 每侧会输出 `appEvents` 计数：

- `appEvents == 0` 表示该侧仅采集到系统噪音日志，未采到业务事件；
- 需要确认该侧已登录、进入消息页并触发聊天交互后再复测。

从 2026-04-24 起，`digest` 额外输出 A4 交互回归指标：

- `paginationTrigger`：顶部触发历史分页次数；
- `autoScrollYes / autoScrollNo`：自动滚底判定结果分布；
- `jumpShow / jumpHide`：回到底部按钮显隐变化次数。

建议判定（上滑阅读场景）：

- 触发分页后应看到 `paginationTrigger > 0`；
- 用户离底阅读期间通常 `autoScrollNo` 会增长；
- 点击“回到底部”后，`jumpHide` 与 `autoScrollYes` 通常会增长。

指定某次报告目录：

```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh /Users/blackie/Projects/raver/docs/reports/openim-dual-sim-20260422-215855
```

当 `sim2.log` 为空时，先看：

```bash
tail -n 20 /Users/blackie/Projects/raver/docs/reports/openim-dual-sim-<timestamp>/sim2.err.log
```

判定规则补充：

- `sim*.log` 文件不存在或 0 行：本次采集无效，不能用于判断实时链路是否异常。
- 两侧都应至少有启动后状态日志（`OpenIM state -> ...`）；若仅单侧有日志，需要重新发起双机交互后再验收。
- 媒体预览/进度/重发属于 UI 交互验收项，需同时结合手工观察：
  - 进度条是否出现与自动收敛；
  - 缩略图是否正常展示；
  - 失败消息点击后是否触发重发成功。

备注：

- `getpwuid_r did not find a match for uid 501` 常见于 `simctl log stream`，属于采集宿主告警，不代表 OpenIM 业务错误。
- 若 `live summary` 长时间全 0，不代表一定无事件；先完成一次交互并结束 probe，再看 digest（含 app-probe 合并结果）。

## 7. 通过标准

- 聊天触发时，能稳定看到 `source=openim-realtime`；
- 社区已读时，能稳定看到 `source=community-event`；
- UI 红点变化与日志触发一致；
- 不依赖 `catchup` 才出现变化；
- 媒体消息体验通过：
  - 图片/视频缩略图可见；
  - 点击可全屏预览；
  - 发送进度条可见且发送完成后收起；
  - 失败消息点按重发可恢复成功。

## 8. 最近一次手测结论（2026-04-23）

- 结果：通过
- 观测到：
  - `realtime message received`
- 未观测到：
  - `catchup messages changed / catchup conversations changed`
  - `10102 / OpenIM ... unavailable`
