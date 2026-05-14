# Raver React Native Deferred Backlog

> Purpose: 记录合理但非当前核心路线的需求，避免开发过程中因为新增外扩需求导致路线漂移。

## 使用规则

新增需求先进入本文件，再决定是否进入当前 Phase。

分类：

| Category | 含义 |
|---|---|
| Core | 当前阶段必须做 |
| Support | 支撑当前阶段，可做 |
| Deferred | 合理但延后 |
| Hold | 暂停，直到重新确认 |
| Reject | 不进入 RN 复现路线 |

记录格式：

```text
- Date:
- Request:
- Source:
- Category:
- Decision:
- Revisit phase:
- Notes:
```

## Backlog

### Full Tencent IM Chat Parity

- Date: 2026-05-14
- Request: RN 首期是否完整复刻 Tencent IM 聊天、媒体、搜索、设置、自定义卡片。
- Source: Architecture risk from current iOS `Features/Messages` and `Infrastructure/TencentIM`.
- Category: Deferred by default
- Decision: 默认不进入 P0/P1，先在 Phase 7 做 bootstrap 和 basic conversation，除非用户明确要求首期完整 IM。
- Revisit phase: Phase 7
- Notes: Tencent IM SDK/RN bridge 是高风险能力，必须先 spike。

### Squad Realtime Location

- Date: 2026-05-14
- Request: 小队线下活动实时定位和后台位置共享。
- Source: iOS `Features/Squads`.
- Category: Deferred by default
- Decision: 默认首期只做 Squad Profile read-only，实时定位进入后续 native integration。
- Revisit phase: Phase 7
- Notes: 涉及隐私、权限、电量、后台策略。

### Widget Extension

- Date: 2026-05-14
- Request: 活动倒计时 Widget。
- Source: iOS `Core/Widget`.
- Category: Deferred by default
- Decision: 默认不进入 RN 首期，后续用原生 target + shared storage 复刻。
- Revisit phase: Phase 8
- Notes: RN 不直接承载 widget UI。

### Video Compose

- Date: 2026-05-14
- Request: 发帖首期支持视频。
- Source: Community Feed roadmap.
- Category: Deferred by default
- Decision: 默认首期只支持文字和图片；视频发布等媒体链路稳定后再加。
- Revisit phase: Phase 4 close / Phase 8
- Notes: 涉及压缩、上传、封面、播放和审核。

### Advanced Tracklist Editor

- Date: 2026-05-14
- Request: Set / Tracklist 编辑器。
- Source: Discover music feature.
- Category: Deferred by default
- Decision: 默认首期只做 Set detail 和 Tracklist read-only。
- Revisit phase: Phase 3 close / Phase 8
- Notes: 编辑器复杂度高，不阻塞内容浏览主线。

