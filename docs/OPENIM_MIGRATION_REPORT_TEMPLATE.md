# OpenIM 历史消息迁移报告模板

> 用途：记录某一次迁移（dry-run 或真实迁移）的执行输入、结果和风险结论。

## 1. 基础信息

- 执行日期：
- 执行人：
- 环境（dev/staging/prod）：
- 执行模式（dry-run / migration）：
- 代码版本（git commit）：

## 2. 输入配置

- sourceType：direct_message / squad_message / all
- conversationBatchSize：
- messageBatchSize：
- 是否写入 `openim_message_migrations`：
- 是否启用真实 OpenIM 发送：

## 3. 迁移范围

- DirectConversation 数量：
- Squad（含历史消息）数量：
- 扫描消息总数：
- 候选消息总数：

## 4. 执行结果

| sourceType | scannedMessages | candidateMessages | migrated | failed | skipped |
| --- | ---: | ---: | ---: | ---: | ---: |
| direct_message | 0 | 0 | 0 | 0 | 0 |
| squad_message | 0 | 0 | 0 | 0 | 0 |

## 5. 异常统计

- unsupported message type：
- sender context issue：
- out-of-order createdAt：
- future timestamp：
- OpenIM API failed：

## 6. 抽样校验

- 会话抽样数：
- 抽样校验结论：
- 代表样本：
  - conversationKey:
  - sourceMessageCount:
  - openIMMessageCount:
  - 顺序是否一致：
  - 时间是否一致：

## 7. 风险与处置

1. 风险：
   - 处置：
2. 风险：
   - 处置：

## 8. 是否可推进下一步

- [ ] 可以进入下一阶段
- [ ] 需要修复后重跑

说明：

