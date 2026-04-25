import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import { openIMGroupService } from '../services/openim/openim-group.service';
import { openIMConfig } from '../services/openim/openim-config';
import { toOpenIMGroupID } from '../services/openim/openim-id';

interface ReconcileConfig {
  execute: boolean;
  onlyWithMessages: boolean;
  limit: number;
  reportPath: string;
}

interface SquadRow {
  id: string;
  name: string;
  description: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  notice: string | null;
  qrCodeUrl: string | null;
  leaderId: string;
  isPublic: boolean;
  members: Array<{
    userId: string;
    role: string;
  }>;
  _count: {
    messages: number;
    members: number;
  };
}

interface ReconcileResult {
  squadId: string;
  openIMGroupId: string;
  name: string;
  memberCount: number;
  messageCount: number;
  status: 'planned' | 'reconciled' | 'blocked' | 'failed';
  reason: string;
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

const buildDefaultReportPath = (): string => {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.resolve(process.cwd(), '..', 'docs', 'reports', `openim-squad-reconcile-${stamp}.md`);
};

const makeConfig = (): ReconcileConfig => {
  return {
    execute: parseBoolean(process.env.OPENIM_SQUAD_RECONCILE_EXECUTE),
    onlyWithMessages: process.env.OPENIM_SQUAD_RECONCILE_ONLY_WITH_MESSAGES
      ? parseBoolean(process.env.OPENIM_SQUAD_RECONCILE_ONLY_WITH_MESSAGES)
      : true,
    limit: parsePositiveInt(process.env.OPENIM_SQUAD_RECONCILE_LIMIT, 200),
    reportPath: (process.env.OPENIM_SQUAD_RECONCILE_REPORT_PATH || '').trim() || buildDefaultReportPath(),
  };
};

const ensureDir = async (targetPath: string): Promise<void> => {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
};

const isAlreadyExistsError = (error: unknown): boolean => {
  const text = error instanceof Error ? error.message : String(error);
  return /already|exist|duplicate|repeat/i.test(text);
};

const loadSquads = async (config: ReconcileConfig): Promise<SquadRow[]> => {
  return prisma.squad.findMany({
    where: config.onlyWithMessages
      ? {
          messages: {
            some: {},
          },
        }
      : {},
    take: config.limit,
    orderBy: { id: 'asc' },
    select: {
      id: true,
      name: true,
      description: true,
      avatarUrl: true,
      bannerUrl: true,
      notice: true,
      qrCodeUrl: true,
      leaderId: true,
      isPublic: true,
      members: {
        select: {
          userId: true,
          role: true,
        },
      },
      _count: {
        select: {
          members: true,
          messages: true,
        },
      },
    },
  });
};

const reconcileSquad = async (squad: SquadRow, config: ReconcileConfig): Promise<ReconcileResult> => {
  const openIMGroupId = toOpenIMGroupID(squad.id);
  const uniqueMembers = Array.from(new Map(squad.members.map((member) => [member.userId, member])).values());
  const memberCount = uniqueMembers.length;

  if (memberCount < 3) {
    return {
      squadId: squad.id,
      openIMGroupId,
      name: squad.name,
      memberCount,
      messageCount: squad._count.messages,
      status: 'blocked',
      reason: `legacy squad has ${memberCount} member(s), below OpenIM group minimum`,
    };
  }

  const memberUserIds = uniqueMembers
    .map((member) => member.userId)
    .filter((userId) => userId !== squad.leaderId);

  if (!config.execute) {
    return {
      squadId: squad.id,
      openIMGroupId,
      name: squad.name,
      memberCount,
      messageCount: squad._count.messages,
      status: 'planned',
      reason: 'eligible',
    };
  }

  try {
    try {
      await openIMGroupService.createSquadGroup({
        squadId: squad.id,
        name: squad.name,
        ownerUserId: squad.leaderId,
        memberUserIds,
        avatarUrl: squad.avatarUrl,
        description: squad.description,
        notice: squad.notice,
        verified: false,
      });
    } catch (error) {
      if (!isAlreadyExistsError(error)) {
        throw error;
      }
    }

    await openIMGroupService.syncSquadGroupProfile({
      squadId: squad.id,
      name: squad.name,
      avatarUrl: squad.avatarUrl,
      description: squad.description,
      notice: squad.notice,
      bannerUrl: squad.bannerUrl,
      qrCodeUrl: squad.qrCodeUrl,
      isPublic: squad.isPublic,
      verified: false,
    });

    for (const member of uniqueMembers) {
      if (member.userId === squad.leaderId) {
        continue;
      }
      const role = member.role === 'admin' ? 'admin' : 'member';
      await openIMGroupService.updateGroupMemberRole(squad.id, member.userId, role);
    }

    return {
      squadId: squad.id,
      openIMGroupId,
      name: squad.name,
      memberCount,
      messageCount: squad._count.messages,
      status: 'reconciled',
      reason: 'ok',
    };
  } catch (error) {
    return {
      squadId: squad.id,
      openIMGroupId,
      name: squad.name,
      memberCount,
      messageCount: squad._count.messages,
      status: 'failed',
      reason: error instanceof Error ? error.message : String(error),
    };
  }
};

const resultTable = (results: ReconcileResult[]): string => {
  if (results.length === 0) {
    return '_无小队_';
  }
  const header = [
    '| squadId | openIMGroupId | name | members | messages | status | reason |',
    '| --- | --- | --- | ---: | ---: | --- | --- |',
  ];
  const body = results.map((result) => {
    const reason = result.reason.replace(/\|/g, '\\|');
    return `| ${result.squadId} | ${result.openIMGroupId} | ${result.name} | ${result.memberCount} | ${result.messageCount} | ${result.status} | ${reason} |`;
  });
  return [...header, ...body].join('\n');
};

const buildReport = (params: {
  config: ReconcileConfig;
  startedAt: Date;
  endedAt: Date;
  results: ReconcileResult[];
}): string => {
  const { config, startedAt, endedAt, results } = params;
  const countByStatus = results.reduce<Record<string, number>>((acc, result) => {
    acc[result.status] = (acc[result.status] || 0) + 1;
    return acc;
  }, {});

  return [
    '# OpenIM 小队 Group Reconcile 报告',
    '',
    `- 运行时间：${startedAt.toISOString()} ~ ${endedAt.toISOString()}`,
    `- execute：${config.execute}`,
    `- OpenIM enabled：${openIMConfig.enabled}`,
    `- onlyWithMessages：${config.onlyWithMessages}`,
    `- limit：${config.limit}`,
    '',
    '## 1. 摘要',
    '',
    `- planned：${countByStatus.planned || 0}`,
    `- reconciled：${countByStatus.reconciled || 0}`,
    `- blocked：${countByStatus.blocked || 0}`,
    `- failed：${countByStatus.failed || 0}`,
    '',
    '## 2. 明细',
    '',
    resultTable(results),
    '',
  ].join('\n');
};

const main = async (): Promise<void> => {
  const config = makeConfig();
  const startedAt = new Date();
  console.log('[openim-squad-reconcile] start', {
    execute: config.execute,
    onlyWithMessages: config.onlyWithMessages,
    limit: config.limit,
    openIMEnabled: openIMConfig.enabled,
  });

  const squads = await loadSquads(config);
  const results: ReconcileResult[] = [];
  for (const squad of squads) {
    results.push(await reconcileSquad(squad, config));
  }

  const endedAt = new Date();
  await ensureDir(config.reportPath);
  await fs.writeFile(config.reportPath, buildReport({ config, startedAt, endedAt, results }), 'utf8');

  const summary = results.reduce<Record<string, number>>((acc, result) => {
    acc[result.status] = (acc[result.status] || 0) + 1;
    return acc;
  }, {});
  console.log('[openim-squad-reconcile] summary', summary);
  console.log('[openim-squad-reconcile] report', config.reportPath);
};

main()
  .catch((error) => {
    console.error('[openim-squad-reconcile] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
