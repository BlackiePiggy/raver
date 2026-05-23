import { Prisma } from '@prisma/client';

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const countOps = (value: unknown): Record<string, number> => {
  const counts: Record<string, number> = {};
  if (!Array.isArray(value)) return counts;
  for (const item of value) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    const op = cleanText((item as Record<string, unknown>).op) || 'unknown';
    counts[op] = (counts[op] || 0) + 1;
  }
  return counts;
};

const pushCount = (
  parts: string[],
  count: number,
  label: string
): void => {
  if (count > 0) parts.push(`${label} ${count} 个`);
};

export const buildContentSubmissionChangeSummary = (
  entityType: string,
  payload: Prisma.InputJsonObject | Prisma.JsonObject
): Prisma.InputJsonObject | null => {
  if (entityType !== 'event' || cleanText(payload.editMode) !== 'patch') {
    return null;
  }

  const lineup = countOps(payload.lineupChanges);
  const timetable = countOps(payload.timetableChanges);
  const stage = countOps(payload.stageChanges);
  const parts: string[] = [];

  pushCount(parts, lineup.add || 0, '新增艺人');
  pushCount(parts, lineup.update || 0, '修改艺人');
  pushCount(parts, lineup.delete || 0, '删除艺人');
  pushCount(parts, lineup.reorder || 0, '调整艺人排序');
  pushCount(parts, timetable.add || 0, '新增 time slot');
  pushCount(parts, timetable.update || 0, '修改 time slot');
  pushCount(parts, timetable.delete || 0, '删除 time slot');
  pushCount(parts, timetable.reorder || 0, '调整 time slot 排序');
  pushCount(parts, stage.rename || 0, '重命名舞台');
  pushCount(parts, stage.delete || 0, '删除舞台');

  const total = Object.values({ ...lineup, ...timetable, ...stage }).reduce((sum, count) => sum + count, 0);
  return {
    mode: 'patch',
    zh: parts.length ? parts.join('，') : '未检测到阵容或时间表变更',
    en: parts.length ? parts.join(', ') : 'No lineup or timetable changes detected',
    totalChanges: total,
    lineup,
    timetable,
    stage,
  };
};

export const attachContentSubmissionChangeSummary = (
  entityType: string,
  payload: Prisma.InputJsonObject
): Prisma.InputJsonObject => {
  const summary = buildContentSubmissionChangeSummary(entityType, payload);
  if (!summary) return payload;
  return {
    ...payload,
    changeSummary: summary as Prisma.InputJsonValue,
  };
};

export const changeSummaryTextFromPayload = (
  payload: unknown
): string | null => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return null;
  const row = payload as Record<string, unknown>;
  const summary = row.changeSummary;
  if (!summary || typeof summary !== 'object' || Array.isArray(summary)) return null;
  return cleanText((summary as Record<string, unknown>).zh) || null;
};
