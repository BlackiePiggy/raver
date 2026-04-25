# OpenIM iOS 聊天 UIKit 灰度与回滚 Runbook

## 1. 目的

为 `DemoAlignedChatView`（UIKit 聊天页）提供可执行的灰度发布与一键回滚手册，确保线上问题可在分钟级止损。

适用范围：
- iOS 客户端聊天会话页路由（`ConversationLoaderView`）
- OpenIM 聊天主链路（不含 BFF 聊天兜底）

---

## 2. 开关总览

代码入口：
- [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift)

路由策略（A7 第二轮后）：
1. 默认  
   - 会话入口统一走新 UIKit 聊天页（`DemoAlignedChatView`）
2. 运行时开关  
   - 已移除旧页运行时回滚开关（防止双实现长期并存）

---

## 3. 推荐发布节奏

A7 后默认已全量新页，建议按“发布窗口”观察：
- 15~30 分钟实时消息稳定性；
- 是否出现会话卡 `Loading conversation...`；
- 是否出现 `10102 User has logged in repeatedly` 异常增长；
- 双机日志是否以 `realtime message received` 为主。

---

## 4. 发布前检查

1. 服务端运行正常：`OPENIM_ENABLED=true`，OpenIM 容器 healthy。
2. iOS 可编译运行：
```bash
xcodegen generate --spec /Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build -quiet
```
3. 双机 probe 可运行：
```bash
OPENIM_PROBE_TRANSPORT=snapshot bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
```

---

## 5. 发布/回滚操作（Xcode / Scheme）

在 `Run -> Arguments -> Environment Variables` 配置：

### 5.1 默认发布（新页）
不设置任何聊天路由环境变量即可。

### 5.2 紧急回滚（代码级）
当线上异常需要紧急止损时，采用代码级回滚：
1. 切回保留旧路由分支的已知稳定提交；
2. 重新打包发布；
3. 用双机 probe 验证恢复情况。

---

## 6. 紧急回滚（分钟级）

触发任一条件即执行回滚：
- 会话大量卡在 `Loading conversation...`；
- 实时监听明显失效（大量依赖 catchup）；
- `10102` 异常短时间激增；
- 关键用户无法收发消息。

回滚步骤：
1. 切换到保留旧页路由分支的回滚提交并重新构建发布。
2. 重新启动 App（双端都要重启）。
3. 执行双机 probe 验证已恢复可用性。

---

## 7. 回滚后验证清单

1. A 发消息给 B：B 会话列表和会话内可实时更新。
2. 日志无异常高频 `10102`。
3. `openim_probe_digest.sh` 报告有效，且关键链路恢复。

命令：
```bash
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh
```

---

## 8. 诊断与日志定位

建议组合：
```bash
OPENIM_PROBE_TRANSPORT=snapshot OPENIM_PROBE_AUTO_STOP_SECONDS=120 bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_dual_sim_probe.sh
bash /Users/blackie/Projects/raver/mobile/ios/RaverMVP/scripts/openim_probe_digest.sh
```

说明：
- 探针脚本默认不主动打开 Simulator UI（更稳定）；如需自动打开窗口，可加：
```bash
OPENIM_PROBE_OPEN_SIM_WINDOWS=1
```

关键检索：
```bash
rg "realtime message received|catchup messages changed|10102|Loading conversation" /Users/blackie/Projects/raver/docs/reports/openim-dual-sim-*/sim*.log
```

常见故障补充：
- 若出现 `cannot find '<new-file-symbol>' in scope`，通常是新增 Swift 文件未被工程 target 收录，先执行：
```bash
xcodegen generate --spec /Users/blackie/Projects/raver/mobile/ios/RaverMVP/project.yml
```
再重跑 `xcodebuild` 验证。

---

## 9. 当前策略（2026-04-23）

- 默认：新 UIKit 聊天页全量开启（单实现默认路径）
- 运行时回滚开关：已移除
- 紧急回滚方式：代码级回滚（切回旧路由提交）
