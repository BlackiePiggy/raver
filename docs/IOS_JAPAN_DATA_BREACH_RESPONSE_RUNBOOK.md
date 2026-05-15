# Japan Personal Data Breach Response Runbook（Raver）

> 适用项目：`/Users/blackie/Projects/raver`
>
> 目标：当日本用户个人数据发生或疑似发生漏えい、滅失、毀損、不正アクセス等事件时，给工程、运营、客服、管理后台和法务一个可执行的响应流程。
>
> 最后更新：2026-05-15（Asia/Shanghai）
>
> 注意：本文是产品与工程执行手册，不构成法律意见。是否向日本个人情報保護委員会（PPC）报告、是否通知本人、通知范围与措辞，必须由隐私负责人和日本法务最终确认。

---

## 1. 官方依据与适用范围

优先参考：

- PPC 漏えい等対応资料：<https://www.ppc.go.jp/personalinfo/legal/leakAction/>
- PPC 漏えい等报告・本人通知义务化说明：<https://www.ppc.go.jp/news/kaiseihou_feature/roueitouhoukoku_gimuka/>
- PPC 通则指南：<https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/>
- PPC 公开 FAQ：<https://www.ppc.go.jp/all_faq_index/faq5-q17-30>

本 Runbook 覆盖 Raver 处理的日本用户个人数据，包括：

- 账号资料：用户 ID、昵称、头像、简介、性别、生日、手机号、邮箱、三方登录绑定。
- 内容与互动：UGC、评论、举报、处罚记录、消息元数据、活动/Squad/Check-in 数据。
- 设备与安全：APNs token、device id、IP、登录日志、风控日志、管理后台审计日志。
- 位置与偏好：发帖/活动/Squad/附近内容使用的位置、城市、兴趣标签。
- 第三方处理：OpenIM、对象存储、推送服务、分析/崩溃 SDK、云数据库和日志平台。

---

## 2. 角色与联系方式

| 角色 | 职责 | 负责人 |
| --- | --- | --- |
| Incident Commander | 统一调度、冻结发布、决策升级 | `TBD` |
| Privacy Owner | 判断个人数据范围、PPC/本人通知触发条件 | `TBD` |
| Japan Legal Reviewer | 日本 APPI、PPC 报告和日文通知复核 | `TBD` |
| Security/Backend Lead | 隔离漏洞、保全证据、修复服务端问题 | `TBD` |
| iOS/Web Lead | 下线风险入口、发版/热修、客户端通知入口 | `TBD` |
| Support Lead | 用户问询、身份核验、工单记录 | `support@raver.app` |
| PR/Comms | 对外公告、FAQ、社媒回应 | `TBD` |

事件期间建立单独 war room，命名格式：

```text
incident-jp-privacy-YYYYMMDD-<short-id>
```

所有决策、证据链接、外部沟通草稿、审批记录必须写入该频道和事件记录。

---

## 3. 分级标准

| 级别 | 条件 | 响应目标 |
| --- | --- | --- |
| SEV-1 | 明确外泄敏感/要配慮信息、认证凭据、私信内容、大规模日本用户数据，或存在持续不正访问 | 立即冻结相关入口，1 小时内成立 war room，24 小时内完成初步影响面 |
| SEV-2 | 可能影响个人权益的数据泄露、误公开、越权访问、第三方处理方事故，影响面尚不明确 | 4 小时内 triage，24 小时内完成是否升级判断 |
| SEV-3 | 内部可控的日志误采集、短时配置错误、无外部访问证据的小范围事件 | 1 个工作日内完成事实确认和修复 |
| Near Miss | 未造成个人数据外泄，但暴露安全控制缺口 | 进入 postmortem 和整改跟踪 |

满足以下任一条件时，默认按 SEV-1/SEV-2 升级并启动 PPC/本人通知判断：

- 要配慮个人情報或类似高敏数据泄露风险。
- 财产损害风险，如支付、票券、身份冒用相关数据。
- 不正访问、内部不当导出、恶意目的或疑似恶意目的。
- 影响人数较多，或影响范围无法快速排除。
- 用户能被第三方识别，或泄露数据组合后可造成实际权益损害。

---

## 4. 前 24 小时检查表

### 4.1 0-1 小时：发现与止血

- [ ] 记录发现时间、发现人、来源、原始告警/工单/用户反馈。
- [ ] 指派 Incident Commander 和 Privacy Owner。
- [ ] 建立 war room，冻结无关部署，停止自动清理可能覆盖证据的任务。
- [ ] 对疑似入口做最小化隔离：关闭 feature flag、撤销密钥、暂停后台任务、限制管理后台账号。
- [ ] 保全证据：请求日志、数据库审计、对象存储访问日志、OpenIM/第三方平台日志、CI/CD 发布记录。
- [ ] 标注当前已知影响：数据类型、时间窗口、用户范围、日本用户占比、是否仍在发生。

### 4.2 1-4 小时：影响面确认

- [ ] 明确事件类型：漏えい、滅失、毀損、不正访问、误发送、越权查看、第三方处理方事故。
- [ ] 查询受影响用户清单，优先区分日本用户、未成年人、被处罚/冻结账号、已删除账号。
- [ ] 判断数据类别：账号、联系方式、位置、UGC、消息、设备 token、日志、管理后台数据。
- [ ] 判断是否包含认证凭据、session、refresh token、APNs token、三方登录 token。
- [ ] 判断是否需要强制登出、撤销 token、轮换密钥、禁用第三方集成。
- [ ] 给 Support Lead 准备“暂不确认细节”的 holding statement。

### 4.3 4-24 小时：报告与通知准备

- [ ] Privacy Owner 填写 PPC 报告判断表。
- [ ] Japan Legal Reviewer 复核是否属于报告对象事态。
- [ ] 准备 PPC 速報材料：概要、发生/发现时间、数据类别、人数、原因、二次损害风险、已采取措施。
- [ ] 准备本人通知草稿（日文优先），避免披露会扩大攻击面的技术细节。
- [ ] 准备客服 FAQ、身份核验流程和升级路径。
- [ ] 建立整改任务：代码修复、配置修复、权限收敛、日志脱敏、监控告警。

---

## 5. PPC 报告判断与时间线

PPC 官方资料说明，若个人数据泄露等可能损害个人权益，可能需要向 PPC 报告并通知本人。实务上按两阶段准备：

- 速報：在知道报告对象事态后尽快提交，目标内部 SLA 为 `3-5 日以内` 完成。
- 確報：原则上在知道报告对象事态后 `30 日以内`；涉及不正目的等情形时按 `60 日以内` 准备。

内部判断表：

| 判断项 | 是/否 | 证据链接 |
| --- | --- | --- |
| 是否涉及日本用户个人数据 |  |  |
| 是否包含要配慮或高敏数据 |  |  |
| 是否可能造成财产损害、身份冒用、骚扰或其他权益损害 |  |  |
| 是否由不正访问、恶意导出、内部不当行为或第三方攻击造成 |  |  |
| 是否影响大量用户，或影响人数无法快速确认 |  |  |
| 是否已经或需要通知本人 |  |  |
| 是否需要公开公告替代或补充本人通知 |  |  |
| 是否涉及委托处理方，需要共同调查或代行报告 |  |  |

即使最终判断“不报告”，也必须保留：

- 事实调查记录。
- 不报告理由。
- 法务/隐私负责人审批。
- 防止复发措施。

---

## 6. 用户通知原则

通知目标：

- 让本人理解发生了什么、可能影响什么、Raver 已做什么、用户应该做什么、如何联系支持。
- 日文为日本用户默认通知语言；必要时附中文和英文。
- 不在通知中披露可被攻击者复用的漏洞细节、密钥、内部系统路径、完整日志。

通知渠道优先级：

1. App 内重要通知或强制弹窗。
2. 账号邮箱。
3. Web 法务/公告页。
4. 客服工单定向回复。
5. 若无法逐一通知，按法务意见使用公开公告作为替代或补充。

通知前必须完成：

- [ ] Privacy Owner 审核影响范围。
- [ ] Japan Legal Reviewer 审核日文措辞。
- [ ] Incident Commander 批准发送。
- [ ] Support Lead 已准备 FAQ。
- [ ] 已设置用户回复收敛渠道：`support@raver.app`。

---

## 7. 日文用户通知模板

### 7.1 個別通知

```text
件名：【重要】Raverにおける個人データに関するお知らせ

Raverをご利用いただきありがとうございます。

このたび、Raverが管理する一部の個人データについて、漏えい等が発生した可能性があることを確認しました。現時点で確認している概要は以下のとおりです。

1. 発生または判明した事象
【例：不正アクセス／設定不備／誤送信／委託先での事故】により、下記の情報が外部から閲覧された、または閲覧された可能性があります。

2. 対象となる可能性がある情報
【例：ユーザーID、ニックネーム、プロフィール画像、メールアドレス、投稿情報、位置情報の一部、端末情報、ログ情報】
※パスワード、決済情報、本人確認書類等が対象に含まれるかどうかは、現時点で【確認中／含まれていないことを確認済み】です。

3. 対象となる可能性がある期間
【YYYY年MM月DD日 HH:mm】から【YYYY年MM月DD日 HH:mm】まで

4. 当社の対応
当社は、判明後ただちに原因調査、影響範囲の確認、関連機能の制限、アクセス権限の見直し、再発防止策の実施を開始しました。必要に応じて、個人情報保護委員会への報告および追加のご連絡を行います。

5. お客様へのお願い
不審な連絡、ログイン通知、心当たりのない操作を確認した場合は、以下の窓口までご連絡ください。Raverを装ったメールやメッセージに記載されたリンクを開く際は、送信元をご確認ください。

6. お問い合わせ窓口
Raver Support
support@raver.app

お客様にご心配とご迷惑をおかけしますことを、深くお詫び申し上げます。今後の調査により新たにお知らせすべき事項が判明した場合は、速やかにご案内いたします。
```

### 7.2 公開公告

```text
件名：Raverにおける個人データに関するお知らせ

Raverは、【YYYY年MM月DD日】、当社が管理する一部の個人データについて、漏えい等が発生した可能性を確認しました。

現在、原因調査、影響範囲の確認、再発防止策を進めています。対象となる可能性がある情報は、【情報種別】です。現時点で、【パスワード／決済情報／本人確認書類】については【対象外であることを確認済み／確認中】です。

対象となる可能性があるお客様には、確認でき次第、個別にご連絡いたします。不審な連絡や心当たりのない操作を確認した場合は、support@raver.app までお問い合わせください。

お客様ならびに関係者の皆様にご心配とご迷惑をおかけしますことを、深くお詫び申し上げます。
```

---

## 8. 中文与英文模板

### 8.1 中文

```text
主题：【重要】关于 Raver 个人数据事件的通知

感谢你使用 Raver。

我们确认 Raver 管理的部分个人数据发生或可能发生泄露/不当访问。当前已知信息如下：

- 事件类型：【不正访问/配置错误/误发送/第三方处理方事故】
- 可能涉及的信息：【用户 ID、昵称、头像、邮箱、投稿信息、部分位置信息、设备信息、日志信息】
- 可能影响的时间：【YYYY-MM-DD HH:mm】至【YYYY-MM-DD HH:mm】
- 我们已经采取的措施：【限制相关功能、撤销访问权限、轮换密钥、修复配置、扩大日志审计】

如你发现可疑登录、异常通知或冒充 Raver 的消息，请联系 support@raver.app。

我们会在调查有进一步进展时继续通知你。给你带来的担心和不便，我们深表歉意。
```

### 8.2 English

```text
Subject: Important notice about a Raver personal data incident

Thank you for using Raver.

We have identified an incident where some personal data managed by Raver was, or may have been, exposed or accessed improperly. What we know so far:

- Incident type: [unauthorized access / configuration issue / misdelivery / processor incident]
- Data that may be affected: [user ID, nickname, profile image, email address, user content, partial location data, device information, logs]
- Potential time window: [YYYY-MM-DD HH:mm] to [YYYY-MM-DD HH:mm]
- Actions taken: [restricted affected features, revoked access, rotated keys, fixed configuration, expanded log review]

If you notice suspicious login activity, unusual messages, or communications pretending to be from Raver, contact support@raver.app.

We will provide additional updates if the investigation identifies further information that should be shared. We sincerely apologize for the concern and inconvenience.
```

---

## 9. 取证与审计记录

必须收集并保留：

- 事件时间线：发现、升级、止血、修复、报告、通知、复盘。
- 代码/配置变更：commit、PR、部署记录、feature flag、环境变量变更。
- 数据查询：受影响用户导出 SQL、查询人、查询时间、结果 hash、导出文件位置。
- 权限记录：管理员账号、第三方服务账号、临时权限授予与撤销。
- 外部处理方沟通：OpenIM、云服务、推送、分析 SDK、对象存储的工单和答复。
- 用户沟通：通知模板、发送批次、失败重试、客服工单。
- 法务判断：PPC 报告/不报告理由、本人通知/公开公告判断。

导出文件必须加密保存，仅授权成员可访问；事件结束后按数据保留策略删除临时导出。

---

## 10. 工程处置清单

后端：

- [ ] 撤销受影响 refresh token、session、API key。
- [ ] 禁用或轮换泄露的密钥、webhook secret、对象存储凭据。
- [ ] 检查 `authenticate`、BFF optional auth、管理后台 auth 是否存在绕过。
- [ ] 对受影响 API 增加速率限制、审计日志、权限校验测试。
- [ ] 对相关数据库字段做最小化导出和脱敏。

iOS/Web：

- [ ] 关闭或隐藏风险入口。
- [ ] 若需强制升级，准备 App Store 说明和兼容处理。
- [ ] 在 App 内通知中心或设置页提供事件通知入口。
- [ ] 确认法务页面、数据请求页面、客服邮箱可访问。

第三方与数据处理方：

- [ ] 确认 OpenIM 账号、消息、附件是否受影响。
- [ ] 确认 OSS 头像/媒体访问日志和权限策略。
- [ ] 确认 APNs token、分析 SDK、崩溃 SDK 是否涉及个人数据。
- [ ] 请求第三方提供事件说明、日志、修复证明。

---

## 11. 复盘与整改

事件关闭条件：

- [ ] 根因已确认，相关漏洞或流程缺口已修复。
- [ ] PPC 报告/不报告判断已归档。
- [ ] 本人通知/不通知判断已归档。
- [ ] 用户问询已有 FAQ 和客服处理闭环。
- [ ] 所有临时权限已撤销，临时导出已删除或归档。
- [ ] 已新增或更新自动化测试、监控、告警、Runbook。
- [ ] 已完成 5 Whys / RCA，并指定 owner 与 due date。

Postmortem 模板：

```text
# Incident Postmortem: jp-privacy-YYYYMMDD-<short-id>

## Summary

## Impact
- Affected users:
- Affected Japanese users:
- Data categories:
- Duration:

## Timeline

## Root Cause

## What Went Well

## What Did Not Go Well

## PPC / Legal Decision

## User Notification Decision

## Corrective Actions
| Action | Owner | Due date | Status |
| --- | --- | --- | --- |

## Evidence Links
```
