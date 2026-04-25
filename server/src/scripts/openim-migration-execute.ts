import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import { openIMConfig } from '../services/openim/openim-config';
import { openIMMessageService } from '../services/openim/openim-message.service';

type SourceTypeFilter = 'all' | 'direct_message' | 'squad_message';

interface MigrationExecutorConfig {
  executeSend: boolean;
  sourceType: SourceTypeFilter;
  batchSize: number;
  maxMessages: number;
  failFast: boolean;
  includeFailed: boolean;
  reportPath: string;
}

interface MigrationRow {
  id: string;
  sourceType: string;
  sourceId: string;
  conversationKey: string;
}

interface DirectMessageDetail {
  id: string;
  senderId: string;
  content: string;
  type: string;
  createdAt: Date;
  conversation: {
    userAId: string;
    userBId: string;
  };
}

interface SquadMessageDetail {
  id: string;
  userId: string;
  squadId: string;
  content: string;
  type: string;
  imageUrl: string | null;
  createdAt: Date;
  squad: {
    members: Array<{ userId: string }>;
  };
}

interface MigrationResultSample {
  sourceType: string;
  sourceId: string;
  conversationKey: string;
  status: 'planned' | 'migrated' | 'failed' | 'skipped';
  targetMessageId?: string | null;
  error?: string | null;
}

interface MigrationExecutorSummary {
  scannedRows: number;
  planned: number;
  migrated: number;
  failed: number;
  skipped: number;
  directRows: number;
  squadRows: number;
}

const prisma = new PrismaClient();

const parseBoolean = (value: string | undefined): boolean => {
  return ['1', 'true', 'yes', 'on'].includes((value || '').trim().toLowerCase());
};

const parsePositiveInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const normalized = Math.floor(parsed);
  return normalized > 0 ? normalized : fallback;
};

const parseSourceType = (value: string | undefined): SourceTypeFilter => {
  const normalized = (value || '').trim().toLowerCase();
  if (normalized === 'direct_message' || normalized === 'squad_message') {
    return normalized;
  }
  return 'all';
};

const buildDefaultReportPath = (): string => {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.resolve(process.cwd(), '..', 'docs', 'reports', `openim-migration-execute-${stamp}.md`);
};

const makeConfig = (): MigrationExecutorConfig => {
  const reportPath = (process.env.OPENIM_MIGRATION_REPORT_PATH || '').trim() || buildDefaultReportPath();
  return {
    executeSend: parseBoolean(process.env.OPENIM_MIGRATION_EXECUTE_SEND),
    sourceType: parseSourceType(process.env.OPENIM_MIGRATION_SOURCE_TYPE),
    batchSize: parsePositiveInt(process.env.OPENIM_MIGRATION_EXECUTE_BATCH_SIZE, 50),
    maxMessages: parsePositiveInt(process.env.OPENIM_MIGRATION_EXECUTE_MAX_MESSAGES, 500),
    failFast: parseBoolean(process.env.OPENIM_MIGRATION_FAIL_FAST),
    includeFailed: parseBoolean(process.env.OPENIM_MIGRATION_INCLUDE_FAILED),
    reportPath,
  };
};

const ensureDir = async (targetPath: string): Promise<void> => {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
};

const shortError = (error: unknown): string => {
  const text = error instanceof Error ? error.message : String(error);
  return text.slice(0, 4000);
};

const fetchPendingRows = async (config: MigrationExecutorConfig): Promise<MigrationRow[]> => {
  return prisma.openIMMessageMigration.findMany({
    where: {
      status: {
        in: config.includeFailed ? ['pending', 'failed'] : ['pending'],
      },
      ...(config.sourceType === 'all' ? {} : { sourceType: config.sourceType }),
    },
    orderBy: [{ conversationKey: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    take: Math.min(config.batchSize, config.maxMessages),
    select: {
      id: true,
      sourceType: true,
      sourceId: true,
      conversationKey: true,
    },
  });
};

const loadDirectMessageDetails = async (sourceIds: string[]): Promise<Map<string, DirectMessageDetail>> => {
  if (sourceIds.length === 0) {
    return new Map();
  }

  const rows: DirectMessageDetail[] = await prisma.directMessage.findMany({
    where: { id: { in: sourceIds } },
    select: {
      id: true,
      senderId: true,
      content: true,
      type: true,
      createdAt: true,
      conversation: {
        select: {
          userAId: true,
          userBId: true,
        },
      },
    },
  });
  return new Map(rows.map((row) => [row.id, row]));
};

const loadSquadMessageDetails = async (sourceIds: string[]): Promise<Map<string, SquadMessageDetail>> => {
  if (sourceIds.length === 0) {
    return new Map();
  }

  const rows: SquadMessageDetail[] = await prisma.squadMessage.findMany({
    where: { id: { in: sourceIds } },
    select: {
      id: true,
      userId: true,
      squadId: true,
      content: true,
      type: true,
      imageUrl: true,
      createdAt: true,
      squad: {
        select: {
          members: {
            select: {
              userId: true,
            },
          },
        },
      },
    },
  });
  return new Map(rows.map((row) => [row.id, row]));
};

const markSkipped = async (row: MigrationRow, reason: string, executeSend: boolean): Promise<void> => {
  if (!executeSend) {
    return;
  }
  await prisma.openIMMessageMigration.update({
    where: { id: row.id },
    data: {
      status: 'skipped',
      error: reason,
      migratedAt: new Date(),
    },
  });
};

const markFailed = async (row: MigrationRow, error: string, executeSend: boolean): Promise<void> => {
  if (!executeSend) {
    return;
  }
  await prisma.openIMMessageMigration.update({
    where: { id: row.id },
    data: {
      status: 'failed',
      error,
    },
  });
};

const markMigrated = async (row: MigrationRow, targetMessageId: string, executeSend: boolean): Promise<void> => {
  if (!executeSend) {
    return;
  }
  await prisma.openIMMessageMigration.update({
    where: { id: row.id },
    data: {
      status: 'migrated',
      targetMessageId,
      error: null,
      migratedAt: new Date(),
    },
  });
};

const processDirectRow = async (
  row: MigrationRow,
  details: Map<string, DirectMessageDetail>,
  config: MigrationExecutorConfig
): Promise<MigrationResultSample> => {
  const detail = details.get(row.sourceId);
  if (!detail) {
    const error = 'source direct message not found';
    await markSkipped(row, error, config.executeSend);
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'skipped', error };
  }

  const peerUserId =
    detail.senderId === detail.conversation.userAId
      ? detail.conversation.userBId
      : detail.senderId === detail.conversation.userBId
        ? detail.conversation.userAId
        : null;

  if (!peerUserId) {
    const error = `sender ${detail.senderId} is not part of direct conversation`;
    await markSkipped(row, error, config.executeSend);
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'skipped', error };
  }

  if (!config.executeSend) {
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'planned' };
  }

  const targetMessageId = await openIMMessageService.sendHistoricalMessage({
    sourceId: row.sourceId,
    sessionType: 'single',
    senderUserId: detail.senderId,
    receiverUserId: peerUserId,
    content: detail.content,
    messageType: detail.type,
    sendTime: detail.createdAt,
  });
  await markMigrated(row, targetMessageId, config.executeSend);
  return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'migrated', targetMessageId };
};

const processSquadRow = async (
  row: MigrationRow,
  details: Map<string, SquadMessageDetail>,
  config: MigrationExecutorConfig
): Promise<MigrationResultSample> => {
  const detail = details.get(row.sourceId);
  if (!detail) {
    const error = 'source squad message not found';
    await markSkipped(row, error, config.executeSend);
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'skipped', error };
  }

  const memberCount = new Set(detail.squad.members.map((member: { userId: string }) => member.userId)).size;
  if (memberCount < 3) {
    const error = `legacy squad has ${memberCount} member(s), below OpenIM group minimum`;
    await markSkipped(row, error, config.executeSend);
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'skipped', error };
  }

  if (!config.executeSend) {
    return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'planned' };
  }

  const targetMessageId = await openIMMessageService.sendHistoricalMessage({
    sourceId: row.sourceId,
    sessionType: 'group',
    senderUserId: detail.userId,
    groupId: detail.squadId,
    content: detail.content,
    messageType: detail.type,
    imageUrl: detail.imageUrl,
    sendTime: detail.createdAt,
  });
  await markMigrated(row, targetMessageId, config.executeSend);
  return { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'migrated', targetMessageId };
};

const runBatch = async (
  rows: MigrationRow[],
  config: MigrationExecutorConfig
): Promise<{ summary: MigrationExecutorSummary; samples: MigrationResultSample[] }> => {
  const summary: MigrationExecutorSummary = {
    scannedRows: rows.length,
    planned: 0,
    migrated: 0,
    failed: 0,
    skipped: 0,
    directRows: rows.filter((row) => row.sourceType === 'direct_message').length,
    squadRows: rows.filter((row) => row.sourceType === 'squad_message').length,
  };

  const directDetails = await loadDirectMessageDetails(
    rows.filter((row) => row.sourceType === 'direct_message').map((row) => row.sourceId)
  );
  const squadDetails = await loadSquadMessageDetails(
    rows.filter((row) => row.sourceType === 'squad_message').map((row) => row.sourceId)
  );

  const samples: MigrationResultSample[] = [];
  const orderedRows = [...rows].sort((left, right) => {
    if (left.conversationKey !== right.conversationKey) {
      return left.conversationKey.localeCompare(right.conversationKey);
    }

    const leftDetail = left.sourceType === 'direct_message'
      ? directDetails.get(left.sourceId)
      : squadDetails.get(left.sourceId);
    const rightDetail = right.sourceType === 'direct_message'
      ? directDetails.get(right.sourceId)
      : squadDetails.get(right.sourceId);

    const leftTime = leftDetail?.createdAt.getTime() ?? 0;
    const rightTime = rightDetail?.createdAt.getTime() ?? 0;
    if (leftTime !== rightTime) {
      return leftTime - rightTime;
    }
    return left.sourceId.localeCompare(right.sourceId);
  });

  for (const row of orderedRows) {
    try {
      let result: MigrationResultSample;
      if (row.sourceType === 'direct_message') {
        result = await processDirectRow(row, directDetails, config);
      } else if (row.sourceType === 'squad_message') {
        result = await processSquadRow(row, squadDetails, config);
      } else {
        const error = `unsupported sourceType ${row.sourceType}`;
        await markSkipped(row, error, config.executeSend);
        result = { sourceType: row.sourceType, sourceId: row.sourceId, conversationKey: row.conversationKey, status: 'skipped', error };
      }

      summary[result.status] += 1;
      if (samples.length < 30) {
        samples.push(result);
      }
    } catch (error) {
      const message = shortError(error);
      await markFailed(row, message, config.executeSend);
      summary.failed += 1;
      if (samples.length < 30) {
        samples.push({
          sourceType: row.sourceType,
          sourceId: row.sourceId,
          conversationKey: row.conversationKey,
          status: 'failed',
          error: message,
        });
      }
      if (config.failFast) {
        break;
      }
    }
  }

  return { summary, samples };
};

const sampleTable = (samples: MigrationResultSample[]): string => {
  if (samples.length === 0) {
    return '_无样本_';
  }
  const header = [
    '| sourceType | sourceId | conversationKey | status | targetMessageId | error |',
    '| --- | --- | --- | --- | --- | --- |',
  ];
  const body = samples.map((sample) => {
    const error = (sample.error || '-').replace(/\|/g, '\\|');
    return `| ${sample.sourceType} | ${sample.sourceId} | ${sample.conversationKey} | ${sample.status} | ${sample.targetMessageId || '-'} | ${error} |`;
  });
  return [...header, ...body].join('\n');
};

const buildReport = (params: {
  config: MigrationExecutorConfig;
  startedAt: Date;
  endedAt: Date;
  summary: MigrationExecutorSummary;
  samples: MigrationResultSample[];
}): string => {
  const { config, startedAt, endedAt, summary, samples } = params;
  return [
    '# OpenIM 历史消息迁移执行报告',
    '',
    `- 运行时间：${startedAt.toISOString()} ~ ${endedAt.toISOString()}`,
    `- 执行发送：${config.executeSend ? '是' : '否（plan only）'}`,
    `- OpenIM enabled：${openIMConfig.enabled}`,
    `- sourceType：${config.sourceType}`,
    `- batchSize：${config.batchSize}`,
    `- maxMessages：${config.maxMessages}`,
    `- failFast：${config.failFast}`,
    `- includeFailed：${config.includeFailed}`,
    '',
    '## 1. 执行摘要',
    '',
    '| scannedRows | directRows | squadRows | planned | migrated | failed | skipped |',
    '| ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    `| ${summary.scannedRows} | ${summary.directRows} | ${summary.squadRows} | ${summary.planned} | ${summary.migrated} | ${summary.failed} | ${summary.skipped} |`,
    '',
    '## 2. 样本',
    '',
    sampleTable(samples),
    '',
    '## 3. 下一步',
    '',
    config.executeSend
      ? '- 检查 failed/skipped 行，修复后重新执行同一脚本。'
      : '- 当前为 plan only。确认样本无误后，使用 `pnpm openim:migration:execute` 执行真实发送。',
    '',
  ].join('\n');
};

const main = async (): Promise<void> => {
  const config = makeConfig();
  const startedAt = new Date();
  console.log('[openim-migration-execute] start', {
    executeSend: config.executeSend,
    sourceType: config.sourceType,
    batchSize: config.batchSize,
    maxMessages: config.maxMessages,
    failFast: config.failFast,
    openIMEnabled: openIMConfig.enabled,
  });

  const rows = await fetchPendingRows(config);
  const { summary, samples } = await runBatch(rows, config);
  const endedAt = new Date();
  const report = buildReport({ config, startedAt, endedAt, summary, samples });

  await ensureDir(config.reportPath);
  await fs.writeFile(config.reportPath, report, 'utf8');

  console.log('[openim-migration-execute] summary', summary);
  console.log('[openim-migration-execute] report', config.reportPath);
};

main()
  .catch((error) => {
    console.error('[openim-migration-execute] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
