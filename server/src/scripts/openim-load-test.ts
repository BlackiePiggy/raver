import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { openIMClient } from '../services/openim/openim-client';
import { openIMConfig } from '../services/openim/openim-config';
import { toOpenIMGroupID, toOpenIMUserID } from '../services/openim/openim-id';
import { openIMGroupService } from '../services/openim/openim-group.service';
import { openIMUserService } from '../services/openim/openim-user.service';

interface LoadTestConfig {
  users: number;
  directMessages: number;
  groupMessages: number;
  groupSize: number;
  concurrency: number;
  reportPath: string;
  runId: string;
}

interface TestUser {
  id: string;
  username: string;
  email: string;
}

interface MessageResult {
  ok: boolean;
  latencyMs: number;
  type: 'direct' | 'group';
  error?: string;
}

interface MessageStats {
  attempted: number;
  succeeded: number;
  failed: number;
  minMs: number;
  p50Ms: number;
  p95Ms: number;
  p99Ms: number;
  maxMs: number;
  avgMs: number;
}

const prisma = new PrismaClient();

const OPENIM_CONTENT_TYPE_TEXT = 101;
const OPENIM_SESSION_TYPE_SINGLE = 1;
const OPENIM_SESSION_TYPE_GROUP = 3;

const parsePositiveInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const normalized = Math.floor(parsed);
  return normalized > 0 ? normalized : fallback;
};

const buildDefaultReportPath = (): string => {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.resolve(process.cwd(), '..', 'docs', 'reports', `openim-load-test-${stamp}.md`);
};

const makeConfig = (): LoadTestConfig => {
  const users = parsePositiveInt(process.env.OPENIM_LOAD_TEST_USERS, 20);
  return {
    users,
    directMessages: parsePositiveInt(process.env.OPENIM_LOAD_TEST_DIRECT_MESSAGES, 100),
    groupMessages: parsePositiveInt(process.env.OPENIM_LOAD_TEST_GROUP_MESSAGES, 100),
    groupSize: Math.min(parsePositiveInt(process.env.OPENIM_LOAD_TEST_GROUP_SIZE, Math.min(users, 10)), users),
    concurrency: parsePositiveInt(process.env.OPENIM_LOAD_TEST_CONCURRENCY, 10),
    reportPath: (process.env.OPENIM_LOAD_TEST_REPORT_PATH || '').trim() || buildDefaultReportPath(),
    runId: (process.env.OPENIM_LOAD_TEST_RUN_ID || '').trim() || `local_${Date.now()}`,
  };
};

const ensureDir = async (targetPath: string): Promise<void> => {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
};

const percentile = (values: number[], p: number): number => {
  if (values.length === 0) {
    return 0;
  }
  const index = Math.ceil((p / 100) * values.length) - 1;
  return values[Math.max(0, Math.min(index, values.length - 1))];
};

const round = (value: number): number => Math.round(value * 100) / 100;

const buildStats = (results: MessageResult[]): MessageStats => {
  const succeeded = results.filter((result) => result.ok);
  const latencies = succeeded.map((result) => result.latencyMs).sort((a, b) => a - b);
  const sum = latencies.reduce((acc, value) => acc + value, 0);
  return {
    attempted: results.length,
    succeeded: succeeded.length,
    failed: results.length - succeeded.length,
    minMs: round(latencies[0] || 0),
    p50Ms: round(percentile(latencies, 50)),
    p95Ms: round(percentile(latencies, 95)),
    p99Ms: round(percentile(latencies, 99)),
    maxMs: round(latencies[latencies.length - 1] || 0),
    avgMs: round(latencies.length > 0 ? sum / latencies.length : 0),
  };
};

const createUsers = async (count: number): Promise<TestUser[]> => {
  const passwordHash = bcrypt.hashSync('openim-load-test-only', 4);
  const users: TestUser[] = [];

  for (let index = 0; index < count; index += 1) {
    const suffix = String(index + 1).padStart(4, '0');
    const username = `openim_load_${suffix}`;
    const email = `${username}@load.test`;
    const user = await prisma.user.upsert({
      where: { email },
      update: {
        username,
        displayName: `OpenIM Load ${suffix}`,
        isActive: true,
      },
      create: {
        username,
        email,
        passwordHash,
        displayName: `OpenIM Load ${suffix}`,
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        email: true,
      },
    });
    users.push(user);
  }

  return users;
};

const sendTextMessage = async (input: {
  type: 'direct' | 'group';
  senderUserId: string;
  receiverUserId?: string;
  groupId?: string;
  content: string;
  clientMsgID: string;
}): Promise<void> => {
  const payload: Record<string, unknown> = {
    sendID: toOpenIMUserID(input.senderUserId),
    senderPlatformID: openIMConfig.platformId,
    content: {
      content: input.content,
    },
    contentType: OPENIM_CONTENT_TYPE_TEXT,
    sessionType: input.type === 'group' ? OPENIM_SESSION_TYPE_GROUP : OPENIM_SESSION_TYPE_SINGLE,
    isOnlineOnly: false,
    notOfflinePush: true,
    sendTime: Date.now(),
    clientMsgID: input.clientMsgID,
    ex: JSON.stringify({
      source: 'raver_openim_load_test',
      runId: input.clientMsgID,
    }),
    operationID: openIMClient.createOperationId('load-test-send'),
  };

  if (input.type === 'group') {
    if (!input.groupId) {
      throw new Error('groupId is required for group load test message');
    }
    payload.groupID = toOpenIMGroupID(input.groupId);
  } else {
    if (!input.receiverUserId) {
      throw new Error('receiverUserId is required for direct load test message');
    }
    payload.recvID = toOpenIMUserID(input.receiverUserId);
  }

  await openIMClient.post(openIMConfig.paths.sendMessage, payload);
};

const runWithConcurrency = async <T>(
  items: T[],
  concurrency: number,
  worker: (item: T, index: number) => Promise<MessageResult>
): Promise<MessageResult[]> => {
  const results: MessageResult[] = new Array(items.length);
  let nextIndex = 0;

  const runners = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (nextIndex < items.length) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      results[currentIndex] = await worker(items[currentIndex], currentIndex);
    }
  });

  await Promise.all(runners);
  return results;
};

const timedSend = async (type: 'direct' | 'group', fn: () => Promise<void>): Promise<MessageResult> => {
  const startedAt = performance.now();
  try {
    await fn();
    return {
      ok: true,
      type,
      latencyMs: performance.now() - startedAt,
    };
  } catch (error) {
    return {
      ok: false,
      type,
      latencyMs: performance.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
    };
  }
};

const setupGroup = async (config: LoadTestConfig, users: TestUser[]): Promise<string | null> => {
  if (config.groupMessages <= 0) {
    return null;
  }
  if (config.groupSize < 3) {
    throw new Error('group load test requires at least 3 users');
  }

  const groupId = `openim-load-${config.runId}`;
  const groupUsers = users.slice(0, config.groupSize);
  const owner = groupUsers[0];
  const members = groupUsers.slice(1).map((user) => user.id);

  await openIMGroupService.createSquadGroup({
    squadId: groupId,
    name: `OpenIM Load ${config.runId}`,
    ownerUserId: owner.id,
    memberUserIds: members,
    description: 'Raver OpenIM load test group',
    verified: false,
  });

  return groupId;
};

const statsTable = (label: string, stats: MessageStats): string => {
  return `| ${label} | ${stats.attempted} | ${stats.succeeded} | ${stats.failed} | ${stats.minMs} | ${stats.avgMs} | ${stats.p50Ms} | ${stats.p95Ms} | ${stats.p99Ms} | ${stats.maxMs} |`;
};

const errorTable = (results: MessageResult[]): string => {
  const errors = results.filter((result) => !result.ok).slice(0, 20);
  if (errors.length === 0) {
    return '_无错误样本_';
  }
  const header = ['| type | latencyMs | error |', '| --- | ---: | --- |'];
  const body = errors.map((error) => {
    const text = (error.error || '-').replace(/\|/g, '\\|').slice(0, 300);
    return `| ${error.type} | ${round(error.latencyMs)} | ${text} |`;
  });
  return [...header, ...body].join('\n');
};

const buildReport = (params: {
  config: LoadTestConfig;
  startedAt: Date;
  endedAt: Date;
  setupMs: number;
  directResults: MessageResult[];
  groupResults: MessageResult[];
  groupId: string | null;
}): string => {
  const { config, startedAt, endedAt, setupMs, directResults, groupResults, groupId } = params;
  const durationMs = endedAt.getTime() - startedAt.getTime();
  const allResults = [...directResults, ...groupResults];
  const allStats = buildStats(allResults);
  const directStats = buildStats(directResults);
  const groupStats = buildStats(groupResults);
  const throughput = allStats.succeeded > 0 ? round((allStats.succeeded / durationMs) * 1000) : 0;

  return [
    '# OpenIM 本地压测报告',
    '',
    `- 运行时间：${startedAt.toISOString()} ~ ${endedAt.toISOString()}`,
    `- 总耗时：${durationMs} ms`,
    `- setup 耗时：${round(setupMs)} ms`,
    `- OpenIM enabled：${openIMConfig.enabled}`,
    `- runId：${config.runId}`,
    `- users：${config.users}`,
    `- directMessages：${config.directMessages}`,
    `- groupMessages：${config.groupMessages}`,
    `- groupSize：${config.groupSize}`,
    `- concurrency：${config.concurrency}`,
    `- groupId：${groupId || '-'}`,
    `- succeeded throughput：${throughput} msg/s`,
    '',
    '## 1. 延迟统计',
    '',
    '| scope | attempted | succeeded | failed | minMs | avgMs | p50Ms | p95Ms | p99Ms | maxMs |',
    '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    statsTable('all', allStats),
    statsTable('direct', directStats),
    statsTable('group', groupStats),
    '',
    '## 2. 错误样本',
    '',
    errorTable(allResults),
    '',
    '## 3. 结论',
    '',
    allStats.failed === 0
      ? '- 本轮本地压测全部消息发送成功。'
      : `- 本轮存在 ${allStats.failed} 条失败消息，请先看错误样本和 OpenIM 日志。`,
    '- 这是本机 Docker 小规模压测，不等价于生产 1k 在线保证；生产还需要 WebSocket 在线连接、APNs、监控和长时间 soak test。',
    '',
  ].join('\n');
};

const main = async (): Promise<void> => {
  const config = makeConfig();
  if (!openIMConfig.enabled) {
    throw new Error('OPENIM_ENABLED must be true for load test');
  }

  const startedAt = new Date();
  console.log('[openim-load-test] start', config);

  const setupStart = performance.now();
  const users = await createUsers(config.users);
  await openIMUserService.ensureUsersByIds(users.map((user) => user.id));
  const groupId = await setupGroup(config, users);
  const setupMs = performance.now() - setupStart;

  const directItems = Array.from({ length: config.directMessages }, (_, index) => index);
  const directResults = await runWithConcurrency(directItems, config.concurrency, async (index) => {
    const sender = users[index % users.length];
    const receiver = users[(index + 1) % users.length];
    return timedSend('direct', () =>
      sendTextMessage({
        type: 'direct',
        senderUserId: sender.id,
        receiverUserId: receiver.id,
        content: `load-test direct ${config.runId} #${index}`,
        clientMsgID: `raver_load_direct_${config.runId}_${index}`,
      })
    );
  });

  const groupUsers = users.slice(0, config.groupSize);
  const groupItems = Array.from({ length: config.groupMessages }, (_, index) => index);
  const groupResults = await runWithConcurrency(groupItems, config.concurrency, async (index) => {
    const sender = groupUsers[index % groupUsers.length];
    return timedSend('group', () =>
      sendTextMessage({
        type: 'group',
        senderUserId: sender.id,
        groupId: groupId || undefined,
        content: `load-test group ${config.runId} #${index}`,
        clientMsgID: `raver_load_group_${config.runId}_${index}`,
      })
    );
  });

  const endedAt = new Date();
  const report = buildReport({ config, startedAt, endedAt, setupMs, directResults, groupResults, groupId });
  await ensureDir(config.reportPath);
  await fs.writeFile(config.reportPath, report, 'utf8');

  console.log('[openim-load-test] stats', {
    all: buildStats([...directResults, ...groupResults]),
    direct: buildStats(directResults),
    group: buildStats(groupResults),
  });
  console.log('[openim-load-test] report', config.reportPath);
};

main()
  .catch((error) => {
    console.error('[openim-load-test] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
