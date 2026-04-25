# OpenIM 本地存储治理与回滚 Runbook

> 适用范围：Raver iOS（`RaverMVP`）本地 OpenIM 数据目录、聊天媒体缓存目录、探针日志文件。

---

## 1. 目标

- 避免本地 OpenIM 数据与媒体缓存长期膨胀导致性能下降。
- 保证探针日志可持续写入，不因单文件过大影响诊断。
- 提供统一的排障与回滚动作，降低线上恢复时间。

---

## 2. 当前策略（S-5 V1）

- 自动审计触发：
  - App 启动时强制审计一次。
  - App 每次回到前台按节流审计（默认 10 分钟一次）。
- 审计对象：
  - `Application Support/OpenIM`（SDK 本地库目录）
  - `Library/Caches/raver-chat-media-cache`（媒体缓存）
  - `Library/Caches/openim-probe.log`（探针日志）
- 阈值：
  - OpenIM 数据目录：`warn >= 1 GiB`，`critical >= 2 GiB`
  - probe 日志：`> 4 MiB` 自动裁剪到 `1 MiB`
- 观测输出：
  - `OpenIMProbeLogger` 与系统日志输出：
    - `trigger` / `level` / `openim` / `media` / `probe` / `total`

---

## 3. 日常巡检

1. 跑一次双机探针（或正常使用 App 一段时间）。
2. 查看 `docs/reports/.../sim*.focus.log` 是否出现：
   - `[OpenIMStorageGovernance] ... level=warn|critical`
3. 若有 `critical`，按第 4 节处理并复测。

---

## 4. 故障处理

### 4.1 OpenIM 本地库过大（`level=warn|critical`）

1. 先确认是否短期压测/回灌导致。
2. 如果是开发环境，可执行“可恢复清理”：
   - 退出 App
   - 删除模拟器沙盒 `Application Support/OpenIM`
   - 重新启动并登录（会从服务端重建会话与消息索引）
3. 清理后重新跑 90 秒双机探针，确认聊天链路正常。

### 4.2 媒体缓存膨胀

1. 先观察 `ChatMediaCache` 的 `evict` 日志是否持续触发。
2. 若需要立即回收：
   - 退出 App
   - 删除 `Library/Caches/raver-chat-media-cache`
   - 重启 App（媒体缩略图按需重建）

### 4.3 probe 日志过大

- 系统会自动裁剪，无需手动处理。
- 若日志仍异常增长，检查是否存在高频无意义 debug 打点。

---

## 5. 回滚策略

- 治理逻辑异常时，可临时回滚到“仅媒体缓存自清理”方案：
  1. 回退 `OpenIMStorageGovernance` 调用点（`AppState` 中两处触发）。
  2. 保留 `ChatMediaTempFileStore` 原有 TTL/容量清理逻辑。
  3. 重新构建并回归消息主链路（发送/接收/分页/重进会话）。

---

## 6. 验收标准

- 90 秒双机探针中无 `unavailable/login10102` 异常。
- 存储审计日志稳定输出且不会引发 UI 卡顿。
- 清理动作后，聊天主链路（加载/发送/重试/分页）正常。
