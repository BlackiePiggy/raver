import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { Prisma, PrismaClient } from '@prisma/client';
import { toOpenIMGroupID, toOpenIMUserID } from '../services/openim/openim-id';

type DryRunMode = 'direct' | 'squad' | 'all';

interface IssueSample {
  sourceType: 'direct_message' | 'squad_message';
  sourceId: string;
  conversationKey: string;
  reason: string;
  detail?: string;
}

interface SourceDryRunSummary {
  sourceType: 'direct_message' | 'squad_message';
  scannedConversations: number;
  scannedMessages: number;
  candidateMessages: number;
  unsupportedTypeMessages: number;
  missingSenderContextMessages: number;
  outOfOrderMessages: number;
  futureTimestampMessages: number;
  duplicateConversationKeys: number;
  earliestMessageAt: Date | null;
  latestMessageAt: Date | null;
}

interface ExistingMigrationSummary {
  sourceType: string;
  status: string;
  count: number;
}

interface DryRunConfig {
  mode: DryRunMode;
  conversationBatchSize: number;
  messageBatchSize: number;
  issueSampleLimit: number;
  persistPlanRows: boolean;
  reportPath: string;
}

interface DirectConversationScanRow {
  id: string;
  userAId: string;
  userBId: string;
}

interface DirectMessageScanRow {
  id: string;
  senderId: string;
  type: string;
  createdAt: Date;
}

interface SquadScanRow {
  id: string;
  leaderId: string;
  members: Array<{ userId: string }>;
}

interface SquadMessageScanRow {
  id: string;
  userId: string;
  type: string;
  createdAt: Date;
}

const prisma = new PrismaClient();
const NOW = Date.now();
const FUTURE_DRIFT_TOLERANCE_MS = 5 * 60 * 1000;
const DIRECT_SUPPORTED_TYPES = new Set(['text', 'image', 'system', 'emoji', 'voice', 'video']);
const SQUAD_SUPPORTED_TYPES = new Set(['text', 'image', 'system', 'emoji', 'voice', 'video']);

const parsePositiveInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const normalized = Math.floor(parsed);
  return normalized > 0 ? normalized : fallback;
};

const parseBoolean = (value: string | undefined): boolean => {
  return ['1', 'true', 'yes', 'on'].includes((value || '').trim().toLowerCase());
};

const parseMode = (value: string | undefined): DryRunMode => {
  const normalized = (value || '').trim().toLowerCase();
  if (normalized === 'direct' || normalized === 'squad' || normalized === 'all') {
    return normalized;
  }
  return 'all';
};

const sanitizeType = (value: string | null | undefined): string => {
  if (!value) {
    return 'text';
  }
  return value.trim().toLowerCase() || 'text';
};

const ensureDir = async (targetPath: string): Promise<void> => {
  const dir = path.dirname(targetPath);
  await fs.mkdir(dir, { recursive: true });
};

const dateOrDash = (value: Date | null): string => (value ? value.toISOString() : '-');

const appendIssue = (issues: IssueSample[], next: IssueSample, limit: number): void => {
  if (issues.length >= limit) {
    return;
  }
  issues.push(next);
};

const updateMessageTimeRange = (summary: SourceDryRunSummary, createdAt: Date): void => {
  if (!summary.earliestMessageAt || createdAt.getTime() < summary.earliestMessageAt.getTime()) {
    summary.earliestMessageAt = createdAt;
  }
  if (!summary.latestMessageAt || createdAt.getTime() > summary.latestMessageAt.getTime()) {
    summary.latestMessageAt = createdAt;
  }
};

const buildDefaultReportPath = (): string => {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.resolve(process.cwd(), '..', 'docs', 'reports', `openim-migration-dryrun-${stamp}.md`);
};

const makeConfig = (): DryRunConfig => {
  const reportPath = (process.env.OPENIM_MIGRATION_REPORT_PATH || '').trim() || buildDefaultReportPath();
  return {
    mode: parseMode(process.env.OPENIM_MIGRATION_DRYRUN_MODE),
    conversationBatchSize: parsePositiveInt(process.env.OPENIM_MIGRATION_CONVERSATION_BATCH_SIZE, 100),
    messageBatchSize: parsePositiveInt(process.env.OPENIM_MIGRATION_MESSAGE_BATCH_SIZE, 500),
    issueSampleLimit: parsePositiveInt(process.env.OPENIM_MIGRATION_ISSUE_SAMPLE_LIMIT, 30),
    persistPlanRows: parseBoolean(process.env.OPENIM_MIGRATION_DRYRUN_PERSIST),
    reportPath,
  };
};

const buildSingleConversationKey = (userAId: string, userBId: string): string => {
  const openIMA = toOpenIMUserID(userAId);
  const openIMB = toOpenIMUserID(userBId);
  const [left, right] = [openIMA, openIMB].sort();
  return `single:${left}:${right}`;
};

const buildGroupConversationKey = (squadId: string): string => {
  return `group:${toOpenIMGroupID(squadId)}`;
};

const upsertPlanRowsIfNeeded = async (
  config: DryRunConfig,
  rows: Array<{
    sourceType: 'direct_message' | 'squad_message';
    sourceId: string;
    conversationKey: string;
  }>
): Promise<void> => {
  if (!config.persistPlanRows || rows.length === 0) {
    return;
  }
  const payload: Prisma.OpenIMMessageMigrationCreateManyInput[] = rows.map((row) => ({
    sourceType: row.sourceType,
    sourceId: row.sourceId,
    conversationKey: row.conversationKey,
    status: 'pending',
  }));
  await prisma.openIMMessageMigration.createMany({
    data: payload,
    skipDuplicates: true,
  });
};

const runDirectDryRun = async (
  config: DryRunConfig
): Promise<{ summary: SourceDryRunSummary; issues: IssueSample[] }> => {
  const summary: SourceDryRunSummary = {
    sourceType: 'direct_message',
    scannedConversations: 0,
    scannedMessages: 0,
    candidateMessages: 0,
    unsupportedTypeMessages: 0,
    missingSenderContextMessages: 0,
    outOfOrderMessages: 0,
    futureTimestampMessages: 0,
    duplicateConversationKeys: 0,
    earliestMessageAt: null,
    latestMessageAt: null,
  };

  const issues: IssueSample[] = [];
  const seenConversationKeys = new Set<string>();
  let conversationCursor: string | null = null;

  while (true) {
    const conversations: DirectConversationScanRow[] = await prisma.directConversation.findMany({
      take: config.conversationBatchSize,
      ...(conversationCursor
        ? {
            cursor: { id: conversationCursor },
            skip: 1,
          }
        : {}),
      orderBy: { id: 'asc' },
      select: {
        id: true,
        userAId: true,
        userBId: true,
      },
    });
    if (conversations.length === 0) {
      break;
    }

    for (const conversation of conversations) {
      summary.scannedConversations += 1;
      const conversationKey = buildSingleConversationKey(conversation.userAId, conversation.userBId);
      if (seenConversationKeys.has(conversationKey)) {
        summary.duplicateConversationKeys += 1;
      } else {
        seenConversationKeys.add(conversationKey);
      }

      let messageCursor: string | null = null;
      let previousCreatedAt: number | null = null;

      while (true) {
        const messages: DirectMessageScanRow[] = await prisma.directMessage.findMany({
          where: {
            conversationId: conversation.id,
          },
          take: config.messageBatchSize,
          ...(messageCursor
            ? {
                cursor: { id: messageCursor },
                skip: 1,
              }
            : {}),
          orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true,
            senderId: true,
            type: true,
            createdAt: true,
          },
        });

        if (messages.length === 0) {
          break;
        }

        const planRows: Array<{
          sourceType: 'direct_message';
          sourceId: string;
          conversationKey: string;
        }> = [];

        for (const message of messages) {
          summary.scannedMessages += 1;
          updateMessageTimeRange(summary, message.createdAt);

          const createdAtMs = message.createdAt.getTime();
          if (previousCreatedAt !== null && createdAtMs < previousCreatedAt) {
            summary.outOfOrderMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'direct_message',
                sourceId: message.id,
                conversationKey,
                reason: 'out_of_order_created_at',
                detail: `${new Date(previousCreatedAt).toISOString()} -> ${message.createdAt.toISOString()}`,
              },
              config.issueSampleLimit
            );
          }
          previousCreatedAt = createdAtMs;

          if (createdAtMs > NOW + FUTURE_DRIFT_TOLERANCE_MS) {
            summary.futureTimestampMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'direct_message',
                sourceId: message.id,
                conversationKey,
                reason: 'future_timestamp',
                detail: message.createdAt.toISOString(),
              },
              config.issueSampleLimit
            );
          }

          const type = sanitizeType(message.type);
          if (!DIRECT_SUPPORTED_TYPES.has(type)) {
            summary.unsupportedTypeMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'direct_message',
                sourceId: message.id,
                conversationKey,
                reason: 'unsupported_message_type',
                detail: type,
              },
              config.issueSampleLimit
            );
            continue;
          }

          const senderValid =
            message.senderId === conversation.userAId || message.senderId === conversation.userBId;
          if (!senderValid) {
            summary.missingSenderContextMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'direct_message',
                sourceId: message.id,
                conversationKey,
                reason: 'sender_not_in_conversation',
                detail: `senderId=${message.senderId}`,
              },
              config.issueSampleLimit
            );
            continue;
          }

          summary.candidateMessages += 1;
          planRows.push({
            sourceType: 'direct_message',
            sourceId: message.id,
            conversationKey,
          });
        }

        await upsertPlanRowsIfNeeded(config, planRows);
        messageCursor = messages[messages.length - 1].id;
      }
    }

    conversationCursor = conversations[conversations.length - 1].id;
  }

  return { summary, issues };
};

const runSquadDryRun = async (
  config: DryRunConfig
): Promise<{ summary: SourceDryRunSummary; issues: IssueSample[] }> => {
  const summary: SourceDryRunSummary = {
    sourceType: 'squad_message',
    scannedConversations: 0,
    scannedMessages: 0,
    candidateMessages: 0,
    unsupportedTypeMessages: 0,
    missingSenderContextMessages: 0,
    outOfOrderMessages: 0,
    futureTimestampMessages: 0,
    duplicateConversationKeys: 0,
    earliestMessageAt: null,
    latestMessageAt: null,
  };

  const issues: IssueSample[] = [];
  const seenConversationKeys = new Set<string>();
  let squadCursor: string | null = null;

  while (true) {
    const squads: SquadScanRow[] = await prisma.squad.findMany({
      where: {
        messages: {
          some: {},
        },
      },
      take: config.conversationBatchSize,
      ...(squadCursor
        ? {
            cursor: { id: squadCursor },
            skip: 1,
          }
        : {}),
      orderBy: { id: 'asc' },
      select: {
        id: true,
        leaderId: true,
        members: {
          select: {
            userId: true,
          },
        },
      },
    });
    if (squads.length === 0) {
      break;
    }

    for (const squad of squads) {
      summary.scannedConversations += 1;
      const conversationKey = buildGroupConversationKey(squad.id);
      if (seenConversationKeys.has(conversationKey)) {
        summary.duplicateConversationKeys += 1;
      } else {
        seenConversationKeys.add(conversationKey);
      }

      const validSenders = new Set<string>([squad.leaderId, ...squad.members.map((member: { userId: string }) => member.userId)]);
      let messageCursor: string | null = null;
      let previousCreatedAt: number | null = null;

      while (true) {
        const messages: SquadMessageScanRow[] = await prisma.squadMessage.findMany({
          where: {
            squadId: squad.id,
          },
          take: config.messageBatchSize,
          ...(messageCursor
            ? {
                cursor: { id: messageCursor },
                skip: 1,
              }
            : {}),
          orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
          select: {
            id: true,
            userId: true,
            type: true,
            createdAt: true,
          },
        });

        if (messages.length === 0) {
          break;
        }

        const planRows: Array<{
          sourceType: 'squad_message';
          sourceId: string;
          conversationKey: string;
        }> = [];

        for (const message of messages) {
          summary.scannedMessages += 1;
          updateMessageTimeRange(summary, message.createdAt);

          const createdAtMs = message.createdAt.getTime();
          if (previousCreatedAt !== null && createdAtMs < previousCreatedAt) {
            summary.outOfOrderMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'squad_message',
                sourceId: message.id,
                conversationKey,
                reason: 'out_of_order_created_at',
                detail: `${new Date(previousCreatedAt).toISOString()} -> ${message.createdAt.toISOString()}`,
              },
              config.issueSampleLimit
            );
          }
          previousCreatedAt = createdAtMs;

          if (createdAtMs > NOW + FUTURE_DRIFT_TOLERANCE_MS) {
            summary.futureTimestampMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'squad_message',
                sourceId: message.id,
                conversationKey,
                reason: 'future_timestamp',
                detail: message.createdAt.toISOString(),
              },
              config.issueSampleLimit
            );
          }

          const type = sanitizeType(message.type);
          if (!SQUAD_SUPPORTED_TYPES.has(type)) {
            summary.unsupportedTypeMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'squad_message',
                sourceId: message.id,
                conversationKey,
                reason: 'unsupported_message_type',
                detail: type,
              },
              config.issueSampleLimit
            );
            continue;
          }

          if (!validSenders.has(message.userId)) {
            summary.missingSenderContextMessages += 1;
            appendIssue(
              issues,
              {
                sourceType: 'squad_message',
                sourceId: message.id,
                conversationKey,
                reason: 'sender_not_in_group_members',
                detail: `senderId=${message.userId}`,
              },
              config.issueSampleLimit
            );
            continue;
          }

          summary.candidateMessages += 1;
          planRows.push({
            sourceType: 'squad_message',
            sourceId: message.id,
            conversationKey,
          });
        }

        await upsertPlanRowsIfNeeded(config, planRows);
        messageCursor = messages[messages.length - 1].id;
      }
    }

    squadCursor = squads[squads.length - 1].id;
  }

  return { summary, issues };
};

const fetchExistingMigrationStats = async (): Promise<ExistingMigrationSummary[]> => {
  const grouped = await prisma.openIMMessageMigration.groupBy({
    by: ['sourceType', 'status'],
    _count: {
      _all: true,
    },
    orderBy: [{ sourceType: 'asc' }, { status: 'asc' }],
  });
  return grouped.map((row) => ({
    sourceType: row.sourceType,
    status: row.status,
    count: row._count._all,
  }));
};

const toSummaryTable = (rows: SourceDryRunSummary[]): string => {
  const header = [
    '| sourceType | conversations | messages | candidates | unsupportedType | senderContextIssues | outOfOrder | futureTimestamp | earliest | latest |',
    '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |',
  ];
  const body = rows.map((item) =>
    [
      item.sourceType,
      item.scannedConversations,
      item.scannedMessages,
      item.candidateMessages,
      item.unsupportedTypeMessages,
      item.missingSenderContextMessages,
      item.outOfOrderMessages,
      item.futureTimestampMessages,
      dateOrDash(item.earliestMessageAt),
      dateOrDash(item.latestMessageAt),
    ].join(' | ')
  );
  return [...header, ...body.map((line) => `| ${line} |`)].join('\n');
};

const toExistingStatsTable = (rows: ExistingMigrationSummary[]): string => {
  if (rows.length === 0) {
    return '_暂无历史迁移状态记录_';
  }
  const header = [
    '| sourceType | status | count |',
    '| --- | --- | ---: |',
  ];
  const body = rows.map((item) => `| ${item.sourceType} | ${item.status} | ${item.count} |`);
  return [...header, ...body].join('\n');
};

const toIssueTable = (issues: IssueSample[]): string => {
  if (issues.length === 0) {
    return '_未发现异常样本_';
  }
  const header = [
    '| sourceType | sourceId | conversationKey | reason | detail |',
    '| --- | --- | --- | --- | --- |',
  ];
  const body = issues.map((issue) => {
    const detail = (issue.detail || '-').replace(/\|/g, '\\|');
    return `| ${issue.sourceType} | ${issue.sourceId} | ${issue.conversationKey} | ${issue.reason} | ${detail} |`;
  });
  return [...header, ...body].join('\n');
};

const buildReportMarkdown = (params: {
  config: DryRunConfig;
  startedAt: Date;
  endedAt: Date;
  summaries: SourceDryRunSummary[];
  issues: IssueSample[];
  existingMigrationStats: ExistingMigrationSummary[];
}): string => {
  const { config, startedAt, endedAt, summaries, issues, existingMigrationStats } = params;
  const durationMs = endedAt.getTime() - startedAt.getTime();
  const totalMessages = summaries.reduce((acc, item) => acc + item.scannedMessages, 0);
  const totalCandidates = summaries.reduce((acc, item) => acc + item.candidateMessages, 0);

  return [
    '# OpenIM 历史消息迁移 Dry-Run 报告',
    '',
    `- 运行时间：${startedAt.toISOString()} ~ ${endedAt.toISOString()}`,
    `- 耗时：${durationMs} ms`,
    `- 模式：${config.mode}`,
    `- 扫描消息总数：${totalMessages}`,
    `- 候选迁移消息总数：${totalCandidates}`,
    `- 是否写入 openim_message_migrations：${config.persistPlanRows ? '是' : '否（仅 dry-run）'}`,
    '',
    '## 1. 扫描配置',
    '',
    `- conversation batch size: ${config.conversationBatchSize}`,
    `- message batch size: ${config.messageBatchSize}`,
    `- issue sample limit: ${config.issueSampleLimit}`,
    '',
    '## 2. 数据摘要',
    '',
    toSummaryTable(summaries),
    '',
    '## 3. 历史迁移状态表统计',
    '',
    toExistingStatsTable(existingMigrationStats),
    '',
    '## 4. 异常样本（截断）',
    '',
    toIssueTable(issues),
    '',
    '## 5. sendTime 策略结论',
    '',
    '- 建议迁移时直接使用旧消息 `createdAt` 毫秒时间戳作为 `sendTime`。',
    '- 若发现未来时间戳消息，请在正式迁移前先清理异常数据，避免 OpenIM 历史顺序异常。',
    '- 正式迁移阶段按会话 `createdAt asc, id asc` 串行发送，保证稳定顺序。',
    '',
    '## 6. 下一步建议',
    '',
    '1. 先以 `OPENIM_MIGRATION_DRYRUN_PERSIST=true` 再跑一轮，固化 `openim_message_migrations` 待迁移基线。',
    '2. 新增真实迁移执行器：读取 `openim_message_migrations(status=pending)`，调用 OpenIM send message，成功后回写 targetMessageId/migratedAt。',
    '3. 跑首轮沙箱迁移后，按会话抽样校验消息顺序与时间。',
    '',
  ].join('\n');
};

const main = async (): Promise<void> => {
  const config = makeConfig();
  const startedAt = new Date();
  console.log('[openim-migration-dryrun] start', {
    mode: config.mode,
    persistPlanRows: config.persistPlanRows,
    conversationBatchSize: config.conversationBatchSize,
    messageBatchSize: config.messageBatchSize,
    issueSampleLimit: config.issueSampleLimit,
  });

  const summaries: SourceDryRunSummary[] = [];
  const issues: IssueSample[] = [];

  if (config.mode === 'all' || config.mode === 'direct') {
    const direct = await runDirectDryRun(config);
    summaries.push(direct.summary);
    issues.push(...direct.issues);
  }

  if (config.mode === 'all' || config.mode === 'squad') {
    const squad = await runSquadDryRun(config);
    summaries.push(squad.summary);
    issues.push(...squad.issues);
  }

  const existingMigrationStats = await fetchExistingMigrationStats();
  const endedAt = new Date();

  const report = buildReportMarkdown({
    config,
    startedAt,
    endedAt,
    summaries,
    issues: issues.slice(0, config.issueSampleLimit),
    existingMigrationStats,
  });

  await ensureDir(config.reportPath);
  await fs.writeFile(config.reportPath, report, 'utf8');

  console.log('[openim-migration-dryrun] summary', summaries);
  console.log('[openim-migration-dryrun] report', config.reportPath);
};

main()
  .catch((error) => {
    console.error('[openim-migration-dryrun] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
