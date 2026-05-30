'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  contentSubmissionsApi,
  type ContentSubmission,
  type ContentSubmissionDetail,
  type ContentSubmissionEntityType,
  type ContentSubmissionStatus,
  type ContentSubmissionVersion,
} from '@/lib/api/content-submissions';

const REVIEWABLE_STATUSES: ContentSubmissionStatus[] = ['pending', 'processing', 'reviewing'];

const ENTITY_OPTIONS: Array<{ value: '' | ContentSubmissionEntityType; label: string }> = [
  { value: '', label: '全部类型' },
  { value: 'event', label: '活动' },
  { value: 'brand', label: '主办方' },
  { value: 'dj', label: 'DJ' },
  { value: 'news', label: '资讯' },
  { value: 'set', label: 'Set' },
  { value: 'label', label: '厂牌' },
  { value: 'id', label: 'ID' },
  { value: 'rating', label: '评分' },
];

const STATUS_OPTIONS: Array<{ value: string; label: string }> = [
  { value: 'pending', label: '待审核' },
  { value: 'reviewing', label: '审核中' },
  { value: 'processing', label: '处理中' },
  { value: 'approved', label: '已通过' },
  { value: 'rejected', label: '未通过' },
  { value: 'failed', label: '失败' },
  { value: 'cancelled', label: '已取消' },
];

type ReviewReasonTemplate = {
  code: string;
  label: string;
  suggestion: string;
  group?: string;
};

const REVIEW_REASON_TEMPLATES: Record<
  ContentSubmissionEntityType,
  ReviewReasonTemplate[]
> = {
  event: [
    { code: 'event_schedule_incomplete', label: '排期不完整', suggestion: '活动日期、eventDays 或 timetable 信息还不完整，请补充后重新提交。', group: '排期结构' },
    { code: 'event_lineup_alignment_gap', label: '阵容未对齐', suggestion: '当前活动的 lineup 与 timetable 还没有完全对齐，请补齐缺失艺人或清理多余阵容后重新提交。', group: '阵容对齐' },
    { code: 'event_timetable_overlap', label: '时段冲突', suggestion: '当前活动时刻表存在同舞台重叠时段或明显冲突，请修正后重新提交。', group: '时刻表冲突' },
    { code: 'event_phase_b_failure', label: '同步待修复', suggestion: '当前活动主结构可识别，但时间表同步或后处理出现异常，请先修复后重新提交。', group: '系统同步' },
    { code: 'event_location_unverified', label: '地点待确认', suggestion: '场地、城市或时区信息还不够明确，请补充官方来源。', group: '地点与来源' },
    { code: 'event_source_insufficient', label: '来源不足', suggestion: '当前活动缺少足够的官方来源或证明材料，请补充后重新提交。', group: '地点与来源' },
  ],
  brand: [
    { code: 'brand_links_missing', label: '官方链接不足', suggestion: '主办方缺少足够的官方链接或 proof，请补充后重新提交。', group: '可信度' },
    { code: 'brand_identity_unverified', label: '主体待确认', suggestion: '品牌主体或版权声明还需要进一步确认，请补充证明信息。', group: '可信度' },
    { code: 'brand_media_incomplete', label: '视觉资料不足', suggestion: '主办方缺少稳定可用的头像、背景或主视觉素材，请完善后重新提交。', group: '视觉素材' },
    { code: 'brand_profile_incomplete', label: '资料不完整', suggestion: '主办方名称、简介或视觉资料还不完整，请完善后重新提交。', group: '基础资料' },
  ],
  dj: [
    { code: 'dj_links_missing', label: '平台链接不足', suggestion: 'DJ 缺少足够的平台链接或 proof，请补充后重新提交。', group: '可信度' },
    { code: 'dj_identity_ambiguous', label: '身份有歧义', suggestion: '当前 DJ 资料与已有艺人可能存在混淆，请补充更明确的身份信息。', group: '身份识别' },
    { code: 'dj_media_incomplete', label: '素材不足', suggestion: 'DJ 的头像、横幅或 proof 资料还不完整，请完善后重新提交。', group: '视觉素材' },
    { code: 'dj_profile_incomplete', label: '资料不完整', suggestion: 'DJ 名称、头像或简介信息仍不完整，请完善后重新提交。', group: '基础资料' },
  ],
  news: [
    { code: 'news_source_unverified', label: '来源待确认', suggestion: '资讯来源还不够可靠，请补充原始出处或官方链接。' },
    { code: 'news_content_incomplete', label: '内容不完整', suggestion: '资讯标题、摘要或正文内容不完整，请补齐后重新提交。' },
    { code: 'news_binding_inaccurate', label: '关联有误', suggestion: '资讯与活动、DJ 或主办方的绑定关系需要进一步校正。' },
  ],
  set: [
    { code: 'set_media_invalid', label: '媒体链接异常', suggestion: 'Set 的视频或音频链接暂不可用，请确认后重新提交。' },
    { code: 'set_metadata_incomplete', label: '资料不完整', suggestion: 'Set 标题、艺人或活动信息还不完整，请完善后重新提交。' },
    { code: 'set_rights_unclear', label: '版权待确认', suggestion: '当前 Set 的转载或归属信息不够明确，请补充说明。' },
  ],
  label: [
    { code: 'label_profile_incomplete', label: '厂牌资料不足', suggestion: '厂牌资料、视觉或外部链接不完整，请完善后重新提交。' },
    { code: 'label_identity_unverified', label: '主体待确认', suggestion: '厂牌主体信息还需要更多官方来源支持。' },
    { code: 'label_links_missing', label: '官方链接不足', suggestion: '厂牌缺少足够的官方链接，请补充后重新提交。' },
  ],
  id: [
    { code: 'id_evidence_insufficient', label: '证据不足', suggestion: '当前 ID 缺少足够证据证明曲目归属，请补充更多信息。' },
    { code: 'id_metadata_incomplete', label: '资料不完整', suggestion: 'ID 的标题、艺人或关联信息还不完整，请完善后重新提交。' },
    { code: 'id_binding_inaccurate', label: '关联有误', suggestion: '当前 ID 与相关 DJ / Event 的关联关系需要再核实。' },
  ],
  rating: [
    { code: 'rating_context_missing', label: '评分上下文不足', suggestion: '评分活动、对象或说明信息不足，请补充后重新提交。' },
    { code: 'rating_targets_invalid', label: '评分对象异常', suggestion: '评分对象或绑定 DJ 信息存在异常，请确认后重新提交。' },
    { code: 'rating_payload_incomplete', label: '资料不完整', suggestion: '评分标题或描述信息不完整，请完善后重新提交。' },
  ],
};

const formatDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const formatLabelFromKey = (key: string): string =>
  key
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_.-]+/g, ' ')
    .trim() || 'unknown';

const summarizePrimitive = (value: unknown): string => {
  if (value === null || value === undefined || value === '') return '空';
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed ? trimmed.slice(0, 80) : '空';
  }
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return `${value.length} 项`;
  if (typeof value === 'object') return '对象';
  return String(value);
};

const stableStringify = (value: unknown): string => {
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(',')}]`;
  }
  if (value && typeof value === 'object') {
    const row = value as Record<string, unknown>;
    return `{${Object.keys(row)
      .sort()
      .map((key) => `${key}:${stableStringify(row[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
};

type DiffRow = {
  key: string;
  before: unknown;
  after: unknown;
  kind: 'added' | 'removed' | 'changed';
};

type SemanticDiffSection = {
  title: string;
  rows: string[];
};

type ReviewRecommendation = {
  code: string;
  label: string;
  suggestion: string;
  rationale: string;
};

const buildVersionDiffRows = (
  previous?: ContentSubmissionVersion | null,
  current?: ContentSubmissionVersion | null
): DiffRow[] => {
  const before = previous?.payload || {};
  const after = current?.payload || {};
  const keys = Array.from(
    new Set([
      ...Object.keys(before),
      ...Object.keys(after),
    ])
  ).sort((left, right) => left.localeCompare(right));

  const rows = keys.map((key): DiffRow | null => {
      const beforeValue = before[key];
      const afterValue = after[key];
      const hasBefore = Object.prototype.hasOwnProperty.call(before, key);
      const hasAfter = Object.prototype.hasOwnProperty.call(after, key);
      if (!hasBefore && hasAfter) {
        return {
          key,
          before: undefined,
          after: afterValue,
          kind: 'added' as const,
        };
      }
      if (hasBefore && !hasAfter) {
        return {
          key,
          before: beforeValue,
          after: undefined,
          kind: 'removed' as const,
        };
      }
      if (stableStringify(beforeValue) !== stableStringify(afterValue)) {
        return {
          key,
          before: beforeValue,
          after: afterValue,
          kind: 'changed' as const,
        };
      }
      return null;
    });

  return rows.filter((item): item is DiffRow => item !== null);
};

const buildEventAutoReviewSignals = (
  detail: ContentSubmissionDetail | null,
  latest?: ContentSubmissionVersion | null
): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'event') {
    return { signals: [], recommendations: [] };
  }

  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const reviewNotes =
    detail.reviewNotes && typeof detail.reviewNotes === 'object' && !Array.isArray(detail.reviewNotes)
      ? (detail.reviewNotes as Record<string, unknown>)
      : {};

  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];

  const eventDays = asArray(payload.eventDays);
  const lineupArtists = asArray(payload.lineupArtists);
  const lineupSlots = buildEventSlotSemanticRecords(payload.lineupSlots);
  const eventDayDates = uniqueStrings(
    eventDays
      .map((item) => normalizeText(asObject(item)?.date))
  );
  const slotArtistNames = uniqueStrings(lineupSlots.map((item) => item.djName));
  const lineupArtistNames = uniqueStrings(
    lineupArtists
      .map((item) => normalizeText(asObject(item)?.djName || asObject(item)?.name))
  );
  const missingFromLineup = slotArtistNames.filter((item) => !lineupArtistNames.includes(item));
  const extraInLineup = lineupArtistNames.filter((item) => !slotArtistNames.includes(item));

  if (eventDays.length === 0) {
    signals.push('当前活动 payload 缺少 eventDays。');
  }
  if (lineupSlots.length > 0 && eventDays.length === 0) {
    signals.push('时刻表已有内容，但没有正式活动日结构，审核前需要先补 schedule/eventDays。');
  }
  if (missingFromLineup.length > 0) {
    signals.push(`时刻表中存在 ${missingFromLineup.length} 位未进入正式阵容的艺人：${missingFromLineup.slice(0, 4).join(', ')}`);
    signals.push('这通常意味着 timetable 已经录入，但正式 lineup 还没同步补齐。');
  }
  if (extraInLineup.length > 0) {
    signals.push(`正式阵容中存在 ${extraInLineup.length} 位没有对应时段的艺人：${extraInLineup.slice(0, 4).join(', ')}`);
    signals.push('这类 lineup-only 艺人如果不是刻意保留，通常需要补充时段或从正式阵容中移除。');
  }

  const invalidSlotDates = lineupSlots.filter((slot) => slot.localDate && !eventDayDates.includes(slot.localDate));
  if (invalidSlotDates.length > 0) {
    signals.push(`有 ${invalidSlotDates.length} 个时段的日期不在当前活动日结构内。`);
  }

  const overlapWarnings: string[] = [];
  const groupedSlots = new Map<string, EventSlotSemanticRecord[]>();
  lineupSlots.forEach((slot) => {
    const key = `${slot.localDate}|${slot.stageName || '未设舞台'}`;
    const bucket = groupedSlots.get(key) ?? [];
    bucket.push(slot);
    groupedSlots.set(key, bucket);
  });
  groupedSlots.forEach((slots, key) => {
    const sorted = slots.slice().sort((left, right) => left.startTime.localeCompare(right.startTime));
    for (let index = 1; index < sorted.length; index += 1) {
      const previous = sorted[index - 1];
      const current = sorted[index];
      if (previous.endTime > current.startTime) {
        overlapWarnings.push(`${key}：${previous.djName || '未设艺人'} 与 ${current.djName || '未设艺人'} 时段重叠`);
      }
    }
  });
  if (overlapWarnings.length > 0) {
    signals.push(`检测到 ${overlapWarnings.length} 组同舞台时段重叠。`);
  }

  const phaseBFailure =
    reviewNotes.phaseBFailure && typeof reviewNotes.phaseBFailure === 'object' && !Array.isArray(reviewNotes.phaseBFailure)
      ? (reviewNotes.phaseBFailure as Record<string, unknown>)
      : null;
  if (phaseBFailure) {
    signals.push(`系统后处理失败：${summarizePrimitive(phaseBFailure.message)}`);
  }

  if (missingFromLineup.length > 0 || extraInLineup.length > 0) {
    recommendations.push({
      code: 'event_lineup_alignment_gap',
      label: '建议使用：阵容未对齐',
      suggestion: '当前活动的 lineup 与 timetable 还没有完全对齐，请补齐缺失艺人或清理多余阵容后重新提交。',
      rationale: '系统检测到正式阵容与时刻表名单不一致。',
    });
  }
  if (overlapWarnings.length > 0) {
    recommendations.push({
      code: 'event_timetable_overlap',
      label: '建议使用：时段冲突',
      suggestion: '当前活动时刻表存在同舞台重叠时段或明显冲突，请修正后重新提交。',
      rationale: '系统检测到同一天同舞台的演出时间存在重叠。',
    });
  }
  if (eventDays.length === 0 || invalidSlotDates.length > 0) {
    recommendations.push({
      code: 'event_schedule_incomplete',
      label: '建议使用：排期不完整',
      suggestion: '活动日期、eventDays 或 timetable 信息还不完整，请补充后重新提交。',
      rationale: '系统检测到活动日结构缺失，或时刻表日期未落入合法活动日。',
    });
  }
  if (phaseBFailure) {
    recommendations.push({
      code: 'event_phase_b_failure',
      label: '建议使用：同步待修复',
      suggestion: '当前活动主结构可识别，但时间表同步或后处理出现异常，请先修复后重新提交。',
      rationale: '系统已记录后处理失败信号，说明该稿件即使主结构通过也可能存在入库风险。',
    });
  }

  return {
    signals,
    recommendations,
  };
};

const buildBrandAutoReviewSignals = (
  detail: ContentSubmissionDetail | null,
  latest?: ContentSubmissionVersion | null
): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'brand') {
    return { signals: [], recommendations: [] };
  }

  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const reviewNotes =
    detail.reviewNotes && typeof detail.reviewNotes === 'object' && !Array.isArray(detail.reviewNotes)
      ? (detail.reviewNotes as Record<string, unknown>)
      : {};
  const brandScreening =
    reviewNotes.brandScreening && typeof reviewNotes.brandScreening === 'object' && !Array.isArray(reviewNotes.brandScreening)
      ? (reviewNotes.brandScreening as Record<string, unknown>)
      : null;

  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];

  const hasPrimaryVisual =
    Boolean(normalizeText(payload.avatarUrl)) ||
    Boolean(normalizeText(payload.backgroundUrl)) ||
    asArray(payload.imageAssets).some((item) => {
      const row = asObject(item);
      const type = normalizeText(row?.type).toLowerCase();
      return Boolean(normalizeText(row?.url)) && ['avatar', 'background', 'poster'].includes(type);
    });
  const hasProof = Boolean(normalizeText(payload.proofImageUrl)) || asArray(payload.imageAssets).some((item) => {
    const row = asObject(item);
    return Boolean(normalizeText(row?.url)) && normalizeText(row?.type).toLowerCase() === 'proof';
  });
  const officialLinkCount = [
    payload.officialWebsite,
    payload.facebookUrl,
    payload.instagramUrl,
    payload.twitterUrl,
    payload.youtubeUrl,
    payload.tiktokUrl,
  ].filter((item) => Boolean(normalizeText(item))).length;
  const rightsConfirmed = Boolean(payload.rightsConfirmed);
  const identityConfirmed = Boolean(payload.identityConfirmed);

  if (!hasPrimaryVisual) {
    signals.push('当前主办方缺少稳定可用的主视觉素材。');
  }
  if (!hasProof && officialLinkCount === 0) {
    signals.push('当前主办方既没有官方链接，也没有 proof 图片。');
  } else if (!hasProof) {
    signals.push('当前主办方没有 proof 图片，审核将主要依赖外部官方链接。');
  }
  if (!rightsConfirmed || !identityConfirmed) {
    signals.push('版权确认或主体确认尚未完成。');
  }
  if (brandScreening?.duplicateBrandWarning) {
    const duplicateBrands = asArray(brandScreening.duplicateBrands)
      .map((item) => normalizeText(asObject(item)?.name))
      .filter(Boolean);
    signals.push(`系统检测到可能重复的主办方：${duplicateBrands.slice(0, 3).join(', ') || '请人工核查'}`);
  }
  if (brandScreening?.eventNameConflictWarning) {
    const similarEvents = asArray(brandScreening.similarEvents)
      .map((item) => normalizeText(asObject(item)?.name))
      .filter(Boolean);
    signals.push(`系统检测到名称相近的活动：${similarEvents.slice(0, 3).join(', ') || '请人工核查'}`);
  }

  if (!hasPrimaryVisual) {
    recommendations.push({
      code: 'brand_media_incomplete',
      label: '建议使用：视觉资料不足',
      suggestion: '主办方缺少稳定可用的头像、背景或主视觉素材，请完善后重新提交。',
      rationale: '系统未检测到可作为正式品牌资料使用的主视觉素材。',
    });
  }
  if (!rightsConfirmed || !identityConfirmed || (!hasProof && officialLinkCount === 0)) {
    recommendations.push({
      code: !rightsConfirmed || !identityConfirmed ? 'brand_identity_unverified' : 'brand_links_missing',
      label: !rightsConfirmed || !identityConfirmed ? '建议使用：主体待确认' : '建议使用：官方链接不足',
      suggestion: !rightsConfirmed || !identityConfirmed
        ? '品牌主体或版权声明还需要进一步确认，请补充证明信息。'
        : '主办方缺少足够的官方链接或 proof，请补充后重新提交。',
      rationale: !rightsConfirmed || !identityConfirmed
        ? '系统检测到版权声明或主体确认未完成。'
        : '系统检测到该主办方缺少可支撑审核的官方可信来源。',
    });
  }

  return {
    signals,
    recommendations,
  };
};

const buildDJAutoReviewSignals = (
  detail: ContentSubmissionDetail | null,
  latest?: ContentSubmissionVersion | null
): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'dj') {
    return { signals: [], recommendations: [] };
  }

  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];

  const hasAvatar = Boolean(normalizeText(payload.avatarUrl));
  const hasBanner = Boolean(normalizeText(payload.bannerUrl));
  const hasProof = Boolean(normalizeText(payload.proofImageUrl));
  const platformLinks = [
    payload.spotifyUrl,
    payload.instagramUrl,
    payload.facebookUrl,
    payload.soundcloudUrl,
    payload.youtubeUrl,
    payload.website,
    payload.otherPlatformUrl,
    payload.neteaseUrl,
    payload.qqMusicUrl,
  ].filter((item) => Boolean(normalizeText(item)));
  const aliases = asArray(payload.aliases).map((item) => normalizeText(item)).filter(Boolean);
  const genres = asArray(payload.genres).map((item) => normalizeText(item)).filter(Boolean);
  const spotifyFollowers = typeof payload.spotifyFollowers === 'number' ? payload.spotifyFollowers : null;

  if (!hasAvatar) {
    signals.push('当前 DJ 缺少头像。');
  }
  if (!hasBanner) {
    signals.push('当前 DJ 没有横幅素材，展示面完整度不足。');
  }
  if (!hasProof && platformLinks.length === 0) {
    signals.push('当前 DJ 既没有平台链接，也没有 proof 图片。');
  } else if (!hasProof) {
    signals.push('当前 DJ 没有 proof 图片，审核将主要依赖外部平台链接。');
  }
  if (aliases.length === 0) {
    signals.push('当前 DJ 没有补充别名，跨平台识别能力偏弱。');
  }
  if (genres.length === 0) {
    signals.push('当前 DJ 没有风格标签，资料完整度偏低。');
  }
  if (spotifyFollowers !== null && spotifyFollowers <= 0 && normalizeText(payload.spotifyUrl)) {
    signals.push('已填写 Spotify 链接，但粉丝量数据为空或异常，建议人工复核。');
  }

  if (!hasAvatar || !hasBanner) {
    recommendations.push({
      code: 'dj_media_incomplete',
      label: '建议使用：素材不足',
      suggestion: 'DJ 的头像、横幅或 proof 资料还不完整，请完善后重新提交。',
      rationale: '系统检测到 DJ 缺少核心视觉素材，影响后台展示和资料可信度。',
    });
  }
  if (!hasProof && platformLinks.length === 0) {
    recommendations.push({
      code: 'dj_links_missing',
      label: '建议使用：平台链接不足',
      suggestion: 'DJ 缺少足够的平台链接或 proof，请补充后重新提交。',
      rationale: '系统未检测到可用于核验身份的平台链接或 proof。',
    });
  }
  if (aliases.length === 0 && genres.length === 0) {
    recommendations.push({
      code: 'dj_profile_incomplete',
      label: '建议使用：资料不完整',
      suggestion: 'DJ 名称、头像或简介信息仍不完整，请完善后重新提交。',
      rationale: '系统检测到该 DJ 的识别字段和基础资料都偏少。',
    });
  }

  return {
    signals,
    recommendations,
  };
};

const summarizePayload = (submission: ContentSubmission): string => {
  const payload = submission.payload || {};
  const description = [
    typeof payload.changeSummaryText === 'string' ? payload.changeSummaryText : '',
    typeof payload.description === 'string' ? payload.description : '',
    typeof payload.bio === 'string' ? payload.bio : '',
    typeof payload.summary === 'string' ? payload.summary : '',
  ]
    .map((item) => item.trim())
    .find(Boolean);
  return description || '当前版本先展示提交摘要、payload 预览和版本历史，逐字段 diff 会在下一轮继续补齐。';
};

const buildAdminEditLink = (submission: ContentSubmission | ContentSubmissionDetail): string | null => {
  if (!submission.createdEntityId) return null;
  if (submission.entityType === 'event') return `/admin/content/events/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'brand') return `/admin/content/organizers/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'dj') return `/admin/content/djs/${submission.createdEntityId}/edit`;
  return null;
};

const reviewNotesSummary = (detail: ContentSubmissionDetail | null): string[] => {
  if (!detail?.reviewNotes || typeof detail.reviewNotes !== 'object') return [];
  const reviewNotes = detail.reviewNotes as Record<string, unknown>;
  const lines: string[] = [];
  const i18n = reviewNotes.i18n && typeof reviewNotes.i18n === 'object' && !Array.isArray(reviewNotes.i18n)
    ? (reviewNotes.i18n as Record<string, unknown>)
    : null;
  if (typeof i18n?.status === 'string') {
    lines.push(`i18n 状态：${i18n.status}`);
  }
  if (Array.isArray(i18n?.missingLocales) && i18n.missingLocales.length > 0) {
    lines.push(`缺失语种：${i18n.missingLocales.join(', ')}`);
  }
  const compliance = reviewNotes.compliance;
  if (compliance) {
    lines.push('已附带内容合规检查摘要');
  }
  return lines;
};

const reviewNotesSections = (
  detail: ContentSubmissionDetail | null
): Array<{ title: string; rows: string[] }> => {
  if (!detail?.reviewNotes || typeof detail.reviewNotes !== 'object') return [];
  const reviewNotes = detail.reviewNotes as Record<string, unknown>;
  const sections: Array<{ title: string; rows: string[] }> = [];

  const i18n = reviewNotes.i18n && typeof reviewNotes.i18n === 'object' && !Array.isArray(reviewNotes.i18n)
    ? (reviewNotes.i18n as Record<string, unknown>)
    : null;
  if (i18n) {
    const rows: string[] = [];
    if (typeof i18n.status === 'string') rows.push(`状态：${i18n.status}`);
    if (Array.isArray(i18n.missingLocales) && i18n.missingLocales.length > 0) {
      rows.push(`缺失语种：${i18n.missingLocales.join(', ')}`);
    }
    if (typeof i18n.autoTranslated === 'boolean') {
      rows.push(`机器翻译：${i18n.autoTranslated ? '是' : '否'}`);
    }
    if (typeof i18n.manuallyConfirmed === 'boolean') {
      rows.push(`人工确认：${i18n.manuallyConfirmed ? '已确认' : '未确认'}`);
    }
    if (Array.isArray(i18n.fields) && i18n.fields.length > 0) {
      rows.push(`缺口字段：${i18n.fields.length} 项`);
    }
    if (rows.length > 0) sections.push({ title: 'i18n 检查', rows });
  }

  const compliance = reviewNotes.compliance && typeof reviewNotes.compliance === 'object' && !Array.isArray(reviewNotes.compliance)
    ? (reviewNotes.compliance as Record<string, unknown>)
    : null;
  if (compliance) {
    const rows = Object.entries(compliance)
      .filter(([, value]) => value !== null && value !== undefined && value !== '')
      .slice(0, 6)
      .map(([key, value]) => `${formatLabelFromKey(key)}：${summarizePrimitive(value)}`);
    if (rows.length > 0) sections.push({ title: '合规信号', rows });
  }

  const decision = reviewNotes.reviewDecision && typeof reviewNotes.reviewDecision === 'object' && !Array.isArray(reviewNotes.reviewDecision)
    ? (reviewNotes.reviewDecision as Record<string, unknown>)
    : null;
  if (decision) {
    const rows = Object.entries(decision)
      .filter(([, value]) => value !== null && value !== undefined && value !== '')
      .map(([key, value]) => `${formatLabelFromKey(key)}：${summarizePrimitive(value)}`);
    if (rows.length > 0) sections.push({ title: '审核决策', rows });
  }

  return sections;
};

const asObject = (value: unknown): Record<string, unknown> | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;

const asArray = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);

const normalizeText = (value: unknown): string => String(value ?? '').trim();

const uniqueStrings = (values: string[]): string[] => Array.from(new Set(values.filter(Boolean)));

const diffStringList = (previous: unknown, current: unknown): { added: string[]; removed: string[] } => {
  const prevItems = uniqueStrings(asArray(previous).map((item) => normalizeText(item)));
  const nextItems = uniqueStrings(asArray(current).map((item) => normalizeText(item)));
  return {
    added: nextItems.filter((item) => !prevItems.includes(item)),
    removed: prevItems.filter((item) => !nextItems.includes(item)),
  };
};

const formatSlotClock = (value: unknown): string => {
  const text = normalizeText(value);
  if (!text) return '--:--';
  const match = text.match(/T(\d{2}:\d{2})/);
  if (match?.[1]) return match[1];
  if (/^\d{2}:\d{2}/.test(text)) return text.slice(0, 5);
  return text;
};

type EventDaySemanticRecord = {
  compareKey: string;
  date: string;
  label: string;
  weekday: string;
  summary: string;
};

const buildEventDaySemanticRecords = (value: unknown): EventDaySemanticRecord[] =>
  asArray(value).map((item, index) => {
    const row = asObject(item);
    const date = normalizeText(row?.date);
    const label = normalizeText(row?.label);
    const weekday = normalizeText(row?.weekday);
    const eventDayId = normalizeText(row?.eventDayId);
    const overallDayIndex = normalizeText(row?.overallDayIndex);
    const compareKey = date || eventDayId || `${overallDayIndex || 'day'}-${index}`;
    const summary = [date, label, weekday].filter(Boolean).join(' · ') || `活动日 ${index + 1}`;
    return {
      compareKey,
      date,
      label,
      weekday,
      summary,
    };
  });

type EventSlotSemanticRecord = {
  compareKey: string;
  localDate: string;
  stageName: string;
  djName: string;
  startTime: string;
  endTime: string;
  summary: string;
};

const buildEventSlotSemanticRecords = (value: unknown): EventSlotSemanticRecord[] =>
  asArray(value).map((item, index) => {
    const row = asObject(item);
    const localDate = normalizeText(row?.localDate);
    const stageName = normalizeText(row?.stageName);
    const djName = normalizeText(row?.djName || row?.name);
    const startTime = formatSlotClock(row?.startTime);
    const endTime = formatSlotClock(row?.endTime);
    const canonicalSlotId = normalizeText(row?.id);
    const eventDayId = normalizeText(row?.eventDayId);
    const sortOrder = normalizeText(row?.sortOrder);
    const compareKey =
      canonicalSlotId ||
      `${eventDayId || localDate || 'day'}|${sortOrder || index}|${startTime}|${endTime}`;
    const summary = [
      localDate || '未标日期',
      `${startTime}-${endTime}`,
      stageName || '未设舞台',
      djName || '未设艺人',
    ].join(' · ');
    return {
      compareKey,
      localDate,
      stageName,
      djName,
      startTime,
      endTime,
      summary,
    };
  });

const semanticEventDiffSections = (
  previous: Record<string, unknown>,
  current: Record<string, unknown>
): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsSchedule: string[] = [];
  const prevSchedule = asObject(previous.schedule);
  const nextSchedule = asObject(current.schedule);
  if ((prevSchedule?.mode || '') !== (nextSchedule?.mode || '')) {
    rowsSchedule.push(`排期模式：${summarizePrimitive(prevSchedule?.mode)} -> ${summarizePrimitive(nextSchedule?.mode)}`);
  }
  if ((prevSchedule?.timeZone || '') !== (nextSchedule?.timeZone || '')) {
    rowsSchedule.push(`时区：${summarizePrimitive(prevSchedule?.timeZone)} -> ${summarizePrimitive(nextSchedule?.timeZone)}`);
  }
  const prevWeeks = asArray(previous.weeks);
  const nextWeeks = asArray(current.weeks);
  if (prevWeeks.length !== nextWeeks.length) {
    rowsSchedule.push(`周结构：${prevWeeks.length} 周 -> ${nextWeeks.length} 周`);
  }
  const prevEventDays = buildEventDaySemanticRecords(previous.eventDays);
  const nextEventDays = buildEventDaySemanticRecords(current.eventDays);
  if (prevEventDays.length !== nextEventDays.length) {
    rowsSchedule.push(`活动日：${prevEventDays.length} 天 -> ${nextEventDays.length} 天`);
  }
  const prevEventDayDates = prevEventDays.map((item) => item.date).filter(Boolean).sort();
  const nextEventDayDates = nextEventDays.map((item) => item.date).filter(Boolean).sort();
  const addedDates = nextEventDayDates.filter((item) => !prevEventDayDates.includes(item));
  const removedDates = prevEventDayDates.filter((item) => !nextEventDayDates.includes(item));
  if (addedDates.length > 0) {
    rowsSchedule.push(`新增活动日：${addedDates.slice(0, 4).join(', ')}`);
  }
  if (removedDates.length > 0) {
    rowsSchedule.push(`移除活动日：${removedDates.slice(0, 4).join(', ')}`);
  }
  const prevEventDayMap = new Map(prevEventDays.map((item) => [item.compareKey, item]));
  const nextEventDayMap = new Map(nextEventDays.map((item) => [item.compareKey, item]));
  const changedEventDayRows = Array.from(nextEventDayMap.entries())
    .map(([key, nextDay]) => {
      const prevDay = prevEventDayMap.get(key);
      if (!prevDay) return null;
      const changes: string[] = [];
      if (prevDay.label !== nextDay.label) {
        changes.push(`标签 ${summarizePrimitive(prevDay.label)} -> ${summarizePrimitive(nextDay.label)}`);
      }
      if (prevDay.weekday !== nextDay.weekday) {
        changes.push(`星期 ${summarizePrimitive(prevDay.weekday)} -> ${summarizePrimitive(nextDay.weekday)}`);
      }
      if (prevDay.date !== nextDay.date) {
        changes.push(`日期 ${summarizePrimitive(prevDay.date)} -> ${summarizePrimitive(nextDay.date)}`);
      }
      if (changes.length === 0) return null;
      return `${nextDay.date || prevDay.date || key}：${changes.join('，')}`;
    })
    .filter((item): item is string => Boolean(item));
  changedEventDayRows.slice(0, 4).forEach((row) => rowsSchedule.push(`活动日调整：${row}`));
  if (rowsSchedule.length > 0) sections.push({ title: '活动排期', rows: rowsSchedule });

  const rowsLineup: string[] = [];
  const prevArtists = asArray(previous.lineupArtists);
  const nextArtists = asArray(current.lineupArtists);
  if (prevArtists.length !== nextArtists.length) {
    rowsLineup.push(`阵容艺人：${prevArtists.length} -> ${nextArtists.length}`);
  }
  const prevArtistNames = prevArtists
    .map((item) => {
      const row = asObject(item);
      return String(row?.djName || row?.name || '').trim();
    })
    .filter(Boolean);
  const nextArtistNames = nextArtists
    .map((item) => {
      const row = asObject(item);
      return String(row?.djName || row?.name || '').trim();
    })
    .filter(Boolean);
  const addedArtists = nextArtistNames.filter((item) => !prevArtistNames.includes(item));
  const removedArtists = prevArtistNames.filter((item) => !nextArtistNames.includes(item));
  if (addedArtists.length > 0) {
    rowsLineup.push(`新增艺人：${addedArtists.slice(0, 5).join(', ')}`);
  }
  if (removedArtists.length > 0) {
    rowsLineup.push(`移除艺人：${removedArtists.slice(0, 5).join(', ')}`);
  }
  const prevSlots = buildEventSlotSemanticRecords(previous.lineupSlots);
  const nextSlots = buildEventSlotSemanticRecords(current.lineupSlots);
  if (prevSlots.length !== nextSlots.length) {
    rowsLineup.push(`演出时段：${prevSlots.length} -> ${nextSlots.length}`);
  }
  const prevSlotMap = new Map(prevSlots.map((item) => [item.compareKey, item]));
  const nextSlotMap = new Map(nextSlots.map((item) => [item.compareKey, item]));
  const addedSlots = nextSlots
    .filter((item) => !prevSlotMap.has(item.compareKey))
    .map((item) => item.summary);
  const removedSlots = prevSlots
    .filter((item) => !nextSlotMap.has(item.compareKey))
    .map((item) => item.summary);
  if (addedSlots.length > 0) {
    rowsLineup.push(`新增时段：${addedSlots.slice(0, 3).join('；')}`);
  }
  if (removedSlots.length > 0) {
    rowsLineup.push(`移除时段：${removedSlots.slice(0, 3).join('；')}`);
  }
  const changedSlots = Array.from(nextSlotMap.entries())
    .map(([key, nextSlot]) => {
      const prevSlot = prevSlotMap.get(key);
      if (!prevSlot) return null;
      const changes: string[] = [];
      if (prevSlot.localDate !== nextSlot.localDate) {
        changes.push(`日期 ${summarizePrimitive(prevSlot.localDate)} -> ${summarizePrimitive(nextSlot.localDate)}`);
      }
      if (prevSlot.startTime !== nextSlot.startTime || prevSlot.endTime !== nextSlot.endTime) {
        changes.push(`时间 ${prevSlot.startTime}-${prevSlot.endTime} -> ${nextSlot.startTime}-${nextSlot.endTime}`);
      }
      if (prevSlot.stageName !== nextSlot.stageName) {
        changes.push(`舞台 ${summarizePrimitive(prevSlot.stageName)} -> ${summarizePrimitive(nextSlot.stageName)}`);
      }
      if (prevSlot.djName !== nextSlot.djName) {
        changes.push(`艺人 ${summarizePrimitive(prevSlot.djName)} -> ${summarizePrimitive(nextSlot.djName)}`);
      }
      if (changes.length === 0) return null;
      return `${nextSlot.summary}：${changes.join('，')}`;
    })
    .filter((item): item is string => Boolean(item));
  changedSlots.slice(0, 4).forEach((row) => rowsLineup.push(`时段调整：${row}`));
  const prevStages = asArray(previous.stageOrder);
  const nextStages = asArray(current.stageOrder);
  if (prevStages.length !== nextStages.length || stableStringify(prevStages) !== stableStringify(nextStages)) {
    rowsLineup.push(`舞台顺序：${prevStages.length} 个 -> ${nextStages.length} 个`);
  }
  const prevStageNames = prevStages.map((item) => normalizeText(item)).filter(Boolean);
  const nextStageNames = nextStages.map((item) => normalizeText(item)).filter(Boolean);
  const addedStages = nextStageNames.filter((item) => !prevStageNames.includes(item));
  const removedStages = prevStageNames.filter((item) => !nextStageNames.includes(item));
  if (addedStages.length > 0) {
    rowsLineup.push(`新增舞台：${addedStages.slice(0, 4).join(', ')}`);
  }
  if (removedStages.length > 0) {
    rowsLineup.push(`移除舞台：${removedStages.slice(0, 4).join(', ')}`);
  }
  if (
    addedStages.length === 0 &&
    removedStages.length === 0 &&
    prevStageNames.length > 1 &&
    stableStringify(prevStageNames) !== stableStringify(nextStageNames)
  ) {
    rowsLineup.push(`舞台排序调整：${prevStageNames.join(' > ')} -> ${nextStageNames.join(' > ')}`);
  }
  if (rowsLineup.length > 0) sections.push({ title: '阵容与时刻表', rows: rowsLineup });

  const rowsOrganizer: string[] = [];
  const previousOrganizerName = normalizeText(previous.organizerName);
  const currentOrganizerName = normalizeText(current.organizerName);
  const previousOrganizerId = normalizeText(previous.wikiFestivalId);
  const currentOrganizerId = normalizeText(current.wikiFestivalId);
  if (!previousOrganizerId && currentOrganizerId) {
    rowsOrganizer.push(`主办方绑定：已新增绑定到 ${currentOrganizerName || '未命名主办方'}（${currentOrganizerId}）`);
  } else if (previousOrganizerId && !currentOrganizerId) {
    rowsOrganizer.push(`主办方绑定：已清空原绑定 ${previousOrganizerName || '未命名主办方'}（${previousOrganizerId}）`);
  } else if (previousOrganizerId && currentOrganizerId && previousOrganizerId !== currentOrganizerId) {
    rowsOrganizer.push(
      `主办方绑定：${previousOrganizerName || '未命名主办方'}（${previousOrganizerId}） -> ${currentOrganizerName || '未命名主办方'}（${currentOrganizerId}）`
    );
  } else if (previousOrganizerName !== currentOrganizerName) {
    rowsOrganizer.push(`主办方显示名：${summarizePrimitive(previous.organizerName)} -> ${summarizePrimitive(current.organizerName)}`);
  }
  const organizerSignals = uniqueStrings([
    ...asArray(previous.organizerAliases).map((item) => normalizeText(item)),
    ...asArray(current.organizerAliases).map((item) => normalizeText(item)),
  ]);
  if (organizerSignals.length > 0 && rowsOrganizer.length === 0 && currentOrganizerName) {
    rowsOrganizer.push(`主办方候选别名：${organizerSignals.slice(0, 4).join(', ')}`);
  }
  if (rowsOrganizer.length > 0) sections.push({ title: '主办方绑定', rows: rowsOrganizer });

  return sections;
};

const semanticBrandDiffSections = (
  previous: Record<string, unknown>,
  current: Record<string, unknown>
): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsProfile: string[] = [];
  if ((previous.name || '') !== (current.name || '')) {
    rowsProfile.push(`主名称：${summarizePrimitive(previous.name)} -> ${summarizePrimitive(current.name)}`);
  }
  const prevAliases = asArray(previous.aliases);
  const nextAliases = asArray(current.aliases);
  if (prevAliases.length !== nextAliases.length) {
    rowsProfile.push(`别名数量：${prevAliases.length} -> ${nextAliases.length}`);
  }
  const aliasChanges = diffStringList(previous.aliases, current.aliases);
  if (aliasChanges.added.length > 0) {
    rowsProfile.push(`新增别名：${aliasChanges.added.slice(0, 4).join(', ')}`);
  }
  if (aliasChanges.removed.length > 0) {
    rowsProfile.push(`移除别名：${aliasChanges.removed.slice(0, 4).join(', ')}`);
  }
  if ((previous.country || '') !== (current.country || '') || (previous.city || '') !== (current.city || '')) {
    rowsProfile.push(`地区：${summarizePrimitive(previous.country)} / ${summarizePrimitive(previous.city)} -> ${summarizePrimitive(current.country)} / ${summarizePrimitive(current.city)}`);
  }
  if (rowsProfile.length > 0) sections.push({ title: '主办方资料', rows: rowsProfile });

  const rowsMedia: string[] = [];
  const prevAssets = asArray(previous.imageAssets);
  const nextAssets = asArray(current.imageAssets);
  if (prevAssets.length !== nextAssets.length) {
    rowsMedia.push(`媒体资产：${prevAssets.length} -> ${nextAssets.length}`);
  }
  const prevAssetUrls = uniqueStrings(
    prevAssets
      .map((item) => normalizeText(asObject(item)?.url))
  );
  const nextAssetUrls = uniqueStrings(
    nextAssets
      .map((item) => normalizeText(asObject(item)?.url))
  );
  const addedAssets = nextAssetUrls.filter((item) => !prevAssetUrls.includes(item));
  const removedAssets = prevAssetUrls.filter((item) => !nextAssetUrls.includes(item));
  if (addedAssets.length > 0) {
    rowsMedia.push(`新增素材：${addedAssets.length} 项`);
  }
  if (removedAssets.length > 0) {
    rowsMedia.push(`移除素材：${removedAssets.length} 项`);
  }
  if ((previous.proofImageUrl || '') !== (current.proofImageUrl || '')) {
    rowsMedia.push('Proof 图片已发生变化');
  }
  if ((previous.avatarUrl || '') !== (current.avatarUrl || '')) {
    rowsMedia.push('头像素材已更新');
  }
  if ((previous.backgroundUrl || '') !== (current.backgroundUrl || '')) {
    rowsMedia.push('背景素材已更新');
  }
  if ((previous.officialWebsite || '') !== (current.officialWebsite || '')) {
    rowsMedia.push('官网链接已更新');
  }
  const linkFieldRows = [
    ['Facebook', previous.facebookUrl, current.facebookUrl],
    ['Instagram', previous.instagramUrl, current.instagramUrl],
    ['Twitter', previous.twitterUrl, current.twitterUrl],
    ['YouTube', previous.youtubeUrl, current.youtubeUrl],
    ['TikTok', previous.tiktokUrl, current.tiktokUrl],
  ]
    .filter(([, before, after]) => normalizeText(before) !== normalizeText(after))
    .map(([label, before, after]) => `${label}：${summarizePrimitive(before)} -> ${summarizePrimitive(after)}`);
  rowsMedia.push(...linkFieldRows.slice(0, 5));
  if (rowsMedia.length > 0) sections.push({ title: '媒体与证明', rows: rowsMedia });

  return sections;
};

const semanticDJDiffSections = (
  previous: Record<string, unknown>,
  current: Record<string, unknown>
): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsIdentity: string[] = [];
  if ((previous.name || '') !== (current.name || '')) {
    rowsIdentity.push(`名称：${summarizePrimitive(previous.name)} -> ${summarizePrimitive(current.name)}`);
  }
  const prevAliases = asArray(previous.aliases);
  const nextAliases = asArray(current.aliases);
  if (prevAliases.length !== nextAliases.length) {
    rowsIdentity.push(`别名数量：${prevAliases.length} -> ${nextAliases.length}`);
  }
  const aliasChanges = diffStringList(previous.aliases, current.aliases);
  if (aliasChanges.added.length > 0) {
    rowsIdentity.push(`新增别名：${aliasChanges.added.slice(0, 4).join(', ')}`);
  }
  if (aliasChanges.removed.length > 0) {
    rowsIdentity.push(`移除别名：${aliasChanges.removed.slice(0, 4).join(', ')}`);
  }
  const prevGenres = asArray(previous.genres);
  const nextGenres = asArray(current.genres);
  if (prevGenres.length !== nextGenres.length) {
    rowsIdentity.push(`风格标签：${prevGenres.length} -> ${nextGenres.length}`);
  }
  const genreChanges = diffStringList(previous.genres, current.genres);
  if (genreChanges.added.length > 0) {
    rowsIdentity.push(`新增风格：${genreChanges.added.slice(0, 5).join(', ')}`);
  }
  if (genreChanges.removed.length > 0) {
    rowsIdentity.push(`移除风格：${genreChanges.removed.slice(0, 5).join(', ')}`);
  }
  if ((previous.country || '') !== (current.country || '')) {
    rowsIdentity.push(`地区：${summarizePrimitive(previous.country)} -> ${summarizePrimitive(current.country)}`);
  }
  if (rowsIdentity.length > 0) sections.push({ title: 'DJ 身份资料', rows: rowsIdentity });

  const rowsPlatforms: string[] = [];
  const platformKeys = ['spotifyUrl', 'instagramUrl', 'facebookUrl', 'soundcloudUrl', 'youtubeUrl', 'website', 'otherPlatformUrl'];
  const prevPlatformCount = platformKeys.filter((key) => String(previous[key] || '').trim()).length;
  const nextPlatformCount = platformKeys.filter((key) => String(current[key] || '').trim()).length;
  if (prevPlatformCount !== nextPlatformCount) {
    rowsPlatforms.push(`平台链接：${prevPlatformCount} -> ${nextPlatformCount}`);
  }
  if ((previous.proofImageUrl || '') !== (current.proofImageUrl || '')) {
    rowsPlatforms.push('Proof 图片已变化');
  }
  if ((previous.avatarUrl || '') !== (current.avatarUrl || '')) {
    rowsPlatforms.push('头像已更新');
  }
  if ((previous.bannerUrl || '') !== (current.bannerUrl || '')) {
    rowsPlatforms.push('横幅素材已更新');
  }
  const platformFieldRows = [
    ['Spotify', previous.spotifyUrl, current.spotifyUrl],
    ['Instagram', previous.instagramUrl, current.instagramUrl],
    ['Facebook', previous.facebookUrl, current.facebookUrl],
    ['SoundCloud', previous.soundcloudUrl, current.soundcloudUrl],
    ['YouTube', previous.youtubeUrl, current.youtubeUrl],
    ['官网', previous.website, current.website],
    ['其他平台', previous.otherPlatformUrl, current.otherPlatformUrl],
  ]
    .filter(([, before, after]) => normalizeText(before) !== normalizeText(after))
    .map(([label, before, after]) => `${label}：${summarizePrimitive(before)} -> ${summarizePrimitive(after)}`);
  rowsPlatforms.push(...platformFieldRows.slice(0, 6));
  if (rowsPlatforms.length > 0) sections.push({ title: '平台与素材', rows: rowsPlatforms });

  return sections;
};

const semanticDiffSections = (
  entityType: ContentSubmissionEntityType | undefined,
  previous?: ContentSubmissionVersion | null,
  current?: ContentSubmissionVersion | null
): SemanticDiffSection[] => {
  const prevPayload = asObject(previous?.payload) || {};
  const nextPayload = asObject(current?.payload) || {};
  if (!entityType) return [];
  if (entityType === 'event') return semanticEventDiffSections(prevPayload, nextPayload);
  if (entityType === 'brand') return semanticBrandDiffSections(prevPayload, nextPayload);
  if (entityType === 'dj') return semanticDJDiffSections(prevPayload, nextPayload);
  return [];
};

export default function ReviewSubmissionsPageClient() {
  const [statusFilter, setStatusFilter] = useState('pending');
  const [entityFilter, setEntityFilter] = useState('');
  const [items, setItems] = useState<ContentSubmission[]>([]);
  const [total, setTotal] = useState(0);
  const [selectedId, setSelectedId] = useState('');
  const [selectedDetail, setSelectedDetail] = useState<ContentSubmissionDetail | null>(null);
  const [loadingList, setLoadingList] = useState(true);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [submittingDecision, setSubmittingDecision] = useState(false);
  const [selectedReasonCode, setSelectedReasonCode] = useState('');
  const [decisionReason, setDecisionReason] = useState('');
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const selectedSummary = useMemo(
    () => items.find((item) => item.id === selectedId) ?? null,
    [items, selectedId]
  );

  const loadList = useCallback(async () => {
    try {
      setLoadingList(true);
      setError('');
      setSuccessMessage('');

      if (statusFilter === 'pending') {
        const results = await Promise.all(
          REVIEWABLE_STATUSES.map((status) =>
            contentSubmissionsApi.listAdmin({
              status,
              entityType: entityFilter || undefined,
              limit: 80,
            })
          )
        );

        const merged = new Map<string, ContentSubmission>();
        results.forEach((result) => {
          result.items.forEach((item) => merged.set(item.id, item));
        });
        const nextItems = Array.from(merged.values()).sort(
          (left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime()
        );
        setItems(nextItems);
        setTotal(nextItems.length);
        setSelectedId((current) => (nextItems.some((item) => item.id === current) ? current : nextItems[0]?.id || ''));
        return;
      }

      const result = await contentSubmissionsApi.listAdmin({
        status: statusFilter,
        entityType: entityFilter || undefined,
        limit: 120,
      });
      setItems(result.items);
      setTotal(result.total);
      setSelectedId((current) => (result.items.some((item) => item.id === current) ? current : result.items[0]?.id || ''));
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '审核列表加载失败');
    } finally {
      setLoadingList(false);
    }
  }, [entityFilter, statusFilter]);

  const loadDetail = useCallback(async (submissionId: string) => {
    if (!submissionId) {
      setSelectedDetail(null);
      return;
    }
    try {
      setLoadingDetail(true);
      const result = await contentSubmissionsApi.getAdminDetail(submissionId);
      setSelectedDetail(result.submission);
      setDecisionReason(result.submission.reviewReason || '');
      const reviewDecision =
        result.submission.reviewNotes &&
        typeof result.submission.reviewNotes === 'object' &&
        !Array.isArray(result.submission.reviewNotes) &&
        result.submission.reviewNotes.reviewDecision &&
        typeof result.submission.reviewNotes.reviewDecision === 'object' &&
        !Array.isArray(result.submission.reviewNotes.reviewDecision)
          ? (result.submission.reviewNotes.reviewDecision as Record<string, unknown>)
          : null;
      setSelectedReasonCode(typeof reviewDecision?.reasonCode === 'string' ? reviewDecision.reasonCode : '');
    } catch (nextError) {
      setSelectedDetail(null);
      setError(nextError instanceof Error ? nextError.message : '审核详情加载失败');
    } finally {
      setLoadingDetail(false);
    }
  }, []);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  useEffect(() => {
    void loadDetail(selectedId);
  }, [loadDetail, selectedId]);

  const handleDecision = async (decision: 'approved' | 'rejected') => {
    if (!selectedDetail) return;
    if (decision === 'rejected' && !selectedReasonCode.trim()) {
      setError('拒绝提交时请先选择一个 reason code 模板。');
      return;
    }
    if (decision === 'rejected' && !decisionReason.trim()) {
      setError('拒绝提交时请填写原因，方便内容同学回改。');
      return;
    }

    try {
      setSubmittingDecision(true);
      setError('');
      const mergedReviewNotes =
        selectedDetail.reviewNotes && typeof selectedDetail.reviewNotes === 'object' && !Array.isArray(selectedDetail.reviewNotes)
          ? { ...selectedDetail.reviewNotes }
          : {};

      mergedReviewNotes.reviewDecision = {
        decision,
        reasonCode: selectedReasonCode || null,
        reviewerNote: decisionReason.trim() || null,
        reviewedAt: new Date().toISOString(),
      };

      const result = await contentSubmissionsApi.review(selectedDetail.id, {
        decision,
        reason: decision === 'rejected' ? decisionReason.trim() : undefined,
        reviewNotes: mergedReviewNotes,
      });
      setSuccessMessage(result.message || `已${decision === 'approved' ? '通过' : '拒绝'}当前提交`);
      await loadList();
      await loadDetail(selectedDetail.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '提交审核决策失败');
    } finally {
      setSubmittingDecision(false);
    }
  };

  const detailEditLink = selectedDetail
    ? buildAdminEditLink(selectedDetail)
    : selectedSummary
      ? buildAdminEditLink(selectedSummary)
      : null;
  const canReview = Boolean(selectedDetail && REVIEWABLE_STATUSES.includes(selectedDetail.status));
  const noteLines = reviewNotesSummary(selectedDetail);
  const noteSections = reviewNotesSections(selectedDetail);
  const reasonTemplates = selectedDetail ? REVIEW_REASON_TEMPLATES[selectedDetail.entityType] || [] : [];
  const latestVersion = selectedDetail?.versions?.[0] ?? null;
  const previousVersion = selectedDetail?.versions?.[1] ?? null;
  const autoReviewInsights = useMemo(() => {
    if (!selectedDetail) return { signals: [], recommendations: [] };
    if (selectedDetail.entityType === 'event') {
      return buildEventAutoReviewSignals(selectedDetail, latestVersion);
    }
    if (selectedDetail.entityType === 'brand') {
      return buildBrandAutoReviewSignals(selectedDetail, latestVersion);
    }
    if (selectedDetail.entityType === 'dj') {
      return buildDJAutoReviewSignals(selectedDetail, latestVersion);
    }
    return { signals: [], recommendations: [] };
  }, [latestVersion, selectedDetail]);
  const versionDiffRows = useMemo(
    () => buildVersionDiffRows(previousVersion, latestVersion),
    [latestVersion, previousVersion]
  );
  const diffStats = useMemo(
    () => ({
      added: versionDiffRows.filter((item) => item.kind === 'added').length,
      removed: versionDiffRows.filter((item) => item.kind === 'removed').length,
      changed: versionDiffRows.filter((item) => item.kind === 'changed').length,
    }),
    [versionDiffRows]
  );
  const semanticSections = useMemo(
    () => semanticDiffSections(selectedDetail?.entityType, previousVersion, latestVersion),
    [latestVersion, previousVersion, selectedDetail?.entityType]
  );

  return (
    <AdminContentLayout
      title="内容贡献审核"
      eyebrow="Admin / Content Workspace / Reviews"
      description="统一后台现在已经开始原生承接 content submissions 审核列表、详情预览和基础 approve / reject。当前版本先优先覆盖 Event / Organizer / DJ 主线，其它长尾实体继续渐进迁移。"
      actions={
        <>
          <Link href="/admin/content/reviews" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回审核中心
          </Link>
          <Link href="/admin/festival-viewer.html#review" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            打开旧审核台
          </Link>
        </>
      }
    >
      {error ? (
        <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
          {error}
        </section>
      ) : null}

      {successMessage ? (
        <section className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">
          {successMessage}
        </section>
      ) : null}

      <section className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <div className="space-y-5">
          <section className="admin-reference-card p-6">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Submission Queue</div>
                <h2 className="mt-2 text-2xl font-semibold text-[#071110]">审核队列</h2>
                <p className="mt-2 text-sm leading-6 text-black/52">当前筛选下共有 {total.toLocaleString()} 条提交，先在统一后台完成定位、预览和基础决策。</p>
              </div>
              <button
                type="button"
                onClick={() => void loadList()}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110]"
              >
                刷新列表
              </button>
            </div>

            <div className="mt-5 grid gap-3 md:grid-cols-2">
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.2em] text-black/35">状态</span>
                <select
                  value={statusFilter}
                  onChange={(event) => setStatusFilter(event.target.value)}
                  className="w-full rounded-full px-4 py-3 text-sm"
                >
                  {STATUS_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="space-y-2">
                <span className="text-xs uppercase tracking-[0.2em] text-black/35">实体类型</span>
                <select
                  value={entityFilter}
                  onChange={(event) => setEntityFilter(event.target.value)}
                  className="w-full rounded-full px-4 py-3 text-sm"
                >
                  {ENTITY_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          </section>

          <section className="admin-reference-card p-4">
            {loadingList ? (
              <div className="py-20 text-center text-sm text-black/48">审核队列加载中…</div>
            ) : items.length === 0 ? (
              <div className="py-20 text-center text-sm text-black/48">当前筛选条件下暂无提交。</div>
            ) : (
              <div className="space-y-3">
                {items.map((item) => {
                  const active = item.id === selectedId;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => setSelectedId(item.id)}
                      className={`w-full rounded-[24px] border p-4 text-left transition-colors ${
                        active
                          ? 'border-[#dceabf] bg-[#edf7f2]'
                          : 'border-[#e8eceb] bg-[#f8f9f8]'
                      }`}
                    >
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="admin-reference-chip">
                          {item.entityType}
                        </span>
                        <span className="admin-reference-chip bg-[#f5f5f7] text-black/55">
                          {item.status}
                        </span>
                      </div>
                      <div className="mt-3 text-lg font-semibold text-[#071110]">{item.title}</div>
                      <p className="mt-2 line-clamp-2 text-sm leading-6 text-black/48">{summarizePayload(item)}</p>
                      <div className="mt-3 text-xs text-black/38">
                        提交人：{item.submitter?.displayName || item.submitter?.username || item.submitterId} · 创建于 {formatDateTime(item.createdAt)}
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </section>
        </div>

        <section className="admin-reference-card p-6">
          {loadingDetail ? (
            <div className="py-24 text-center text-sm text-black/48">正在加载提交详情…</div>
          ) : !selectedDetail ? (
            <div className="py-24 text-center text-sm text-black/48">请选择左侧的一条提交查看详情。</div>
          ) : (
            <div className="space-y-6">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-[0.18em] text-black/35">Submission Detail</div>
                  <h2 className="mt-2 text-3xl font-semibold text-[#071110]">{selectedDetail.title}</h2>
                  <div className="mt-3 flex flex-wrap gap-2 text-xs text-black/45">
                    <span className="admin-reference-chip">{selectedDetail.entityType}</span>
                    <span className="admin-reference-chip bg-[#f5f5f7] text-black/55">{selectedDetail.status}</span>
                    <span className="admin-reference-chip bg-[#f5f5f7] text-black/55">版本 {selectedDetail.versions?.[0]?.version || 1}</span>
                  </div>
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  {detailEditLink ? (
                    <Link href={detailEditLink} className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]">
                      打开实体编辑页
                    </Link>
                  ) : null}
                  <button
                    type="button"
                    onClick={() => void loadDetail(selectedDetail.id)}
                    className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-sm font-semibold text-[#071110]"
                  >
                    刷新详情
                  </button>
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                {[
                  ['提交人', selectedDetail.submitter?.displayName || selectedDetail.submitter?.username || selectedDetail.submitterId],
                  ['创建时间', formatDateTime(selectedDetail.createdAt)],
                  ['最近更新', formatDateTime(selectedDetail.updatedAt)],
                  ['审核时间', formatDateTime(selectedDetail.reviewedAt)],
                ].map(([label, value]) => (
                  <div key={label} className="admin-reference-soft-card px-4 py-3 text-sm">
                    <div className="text-black/42">{label}</div>
                    <div className="mt-2 font-semibold text-[#071110]">{value}</div>
                  </div>
                ))}
              </div>

              {noteLines.length > 0 ? (
                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm text-black/42">Review Signals</div>
                  <div className="mt-3 space-y-2 text-sm leading-6 text-[#24312d]">
                    {noteLines.map((line) => (
                      <div key={line}>{line}</div>
                    ))}
                  </div>
                </div>
              ) : null}

              <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
                <div className="admin-reference-dark-card p-5">
                  <div className="text-sm text-white/45">Review Decision</div>
                  <h3 className="mt-2 text-2xl font-semibold text-white">基础审核动作</h3>
                  <p className="mt-2 text-sm leading-6 text-white/65">当前版本已经支持基础 approve / reject，并会把 decision、reason code 和 reviewer note 结构化写回 review notes，方便后续复审和统计。</p>

                  <div className="mt-4">
                    {autoReviewInsights.recommendations.length > 0 ? (
                      <div className="mb-4 rounded-[22px] border border-white/10 bg-white/8 p-4">
                        <div className="text-sm font-semibold text-white">系统建议原因</div>
                        <div className="mt-3 grid gap-3">
                          {autoReviewInsights.recommendations.map((recommendation) => (
                            <button
                              key={recommendation.code}
                              type="button"
                              onClick={() => {
                                setSelectedReasonCode(recommendation.code);
                                setDecisionReason(recommendation.suggestion);
                              }}
                              className="rounded-[20px] border border-white/10 bg-white/6 p-4 text-left transition-colors"
                            >
                              <div className="text-sm font-semibold text-white">{recommendation.label}</div>
                              <div className="mt-2 text-xs uppercase tracking-[0.2em] text-white/35">{recommendation.code}</div>
                              <div className="mt-3 text-sm leading-6 text-white/58">{recommendation.rationale}</div>
                            </button>
                          ))}
                        </div>
                      </div>
                    ) : null}

                    <div className="text-sm text-white/45">拒绝模板</div>
                    <div className="mt-3 grid gap-3">
                      {reasonTemplates.map((template) => {
                        const active = selectedReasonCode === template.code;
                        return (
                          <button
                            key={template.code}
                            type="button"
                            onClick={() => {
                              setSelectedReasonCode(template.code);
                              if (!decisionReason.trim()) {
                                setDecisionReason(template.suggestion);
                              }
                            }}
                            className={`rounded-[20px] border p-4 text-left transition-colors ${
                              active
                                ? 'border-white/20 bg-white/12'
                                : 'border-white/10 bg-white/6'
                            }`}
                          >
                            <div className="text-sm font-semibold text-white">{template.label}</div>
                            {template.group ? (
                              <div className="mt-2 text-[11px] uppercase tracking-[0.2em] text-white/55">{template.group}</div>
                            ) : null}
                            <div className="mt-2 text-xs uppercase tracking-[0.2em] text-white/35">{template.code}</div>
                            <div className="mt-3 text-sm leading-6 text-white/58">{template.suggestion}</div>
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  <label className="mt-4 block space-y-2">
                    <span className="text-sm text-white/45">拒绝原因</span>
                    <textarea
                      value={decisionReason}
                      onChange={(event) => setDecisionReason(event.target.value)}
                      placeholder="如果需要拒绝，请补充具体原因，方便内容同学回改。"
                      className="min-h-28 w-full rounded-[22px] border border-white/10 bg-white/8 px-4 py-3 text-sm text-white placeholder:text-white/35 outline-none"
                    />
                  </label>

                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <button
                      type="button"
                      disabled={!canReview || submittingDecision}
                      onClick={() => void handleDecision('approved')}
                      className="rounded-full bg-white px-4 py-3 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      审核通过
                    </button>
                    <button
                      type="button"
                      disabled={!canReview || submittingDecision}
                      onClick={() => void handleDecision('rejected')}
                      className="rounded-full border border-white/10 bg-white/8 px-4 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      拒绝提交
                    </button>
                  </div>
                </div>

                <div className="admin-reference-soft-card p-4">
                  <div className="text-sm text-black/42">Review Notes</div>
                  <h3 className="mt-2 text-xl font-semibold text-[#071110]">结构化审核信号</h3>
                  <div className="mt-4 space-y-4">
                    {autoReviewInsights.signals.length > 0 ? (
                      <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7efda_0%,#ffffff_100%)] p-4">
                        <div className="text-sm font-semibold text-[#604a1b]">自动审查提示</div>
                        <div className="mt-3 space-y-2 text-sm leading-6 text-[#4f4326]">
                          {autoReviewInsights.signals.map((row) => (
                            <div key={row}>{row}</div>
                          ))}
                        </div>
                      </div>
                    ) : null}
                    {noteSections.length === 0 ? (
                      <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
                        当前 submission 还没有更细的结构化审核 notes，后续会继续补字段级点评与模板化 reason code。
                      </div>
                    ) : (
                      noteSections.map((section) => (
                        <div key={section.title} className="admin-reference-card p-4">
                          <div className="text-sm font-semibold text-[#071110]">{section.title}</div>
                          <div className="mt-3 space-y-2 text-sm leading-6 text-black/48">
                            {section.rows.map((row) => (
                              <div key={row}>{row}</div>
                            ))}
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </div>

              <div className="grid gap-5 xl:grid-cols-[1fr_1fr]">
                <div className="admin-reference-card p-5">
                  <div className="text-sm text-black/42">Semantic Diff</div>
                  <h3 className="mt-2 text-xl font-semibold text-[#071110]">业务语义差异</h3>
                  <div className="mt-4 space-y-4">
                    {semanticSections.length === 0 ? (
                      <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
                        当前实体暂时还没有更细的业务语义 diff，先回退到字段级 diff 摘要。
                      </div>
                    ) : (
                      semanticSections.map((section) => (
                        <div key={section.title} className="admin-reference-soft-card p-4">
                          <div className="text-sm font-semibold text-[#071110]">{section.title}</div>
                          <div className="mt-3 space-y-2 text-sm leading-6 text-black/48">
                            {section.rows.map((row) => (
                              <div key={row}>{row}</div>
                            ))}
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>

                <div className="admin-reference-card p-5">
                  <div className="text-sm text-black/42">Version Diff</div>
                  <h3 className="mt-2 text-xl font-semibold text-[#071110]">版本差异摘要</h3>
                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    {[
                      ['新增字段', diffStats.added],
                      ['移除字段', diffStats.removed],
                      ['变更字段', diffStats.changed],
                    ].map(([label, value]) => (
                      <div key={label} className="admin-reference-soft-card px-4 py-3 text-sm">
                        <div className="text-black/42">{label}</div>
                        <div className="mt-2 text-lg font-semibold text-[#071110]">{value}</div>
                      </div>
                    ))}
                  </div>

                  <div className="mt-4 space-y-3">
                    {!previousVersion ? (
                      <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
                        当前只有首个版本，暂时没有可对比的上一版 payload。
                      </div>
                    ) : versionDiffRows.length === 0 ? (
                      <div className="admin-reference-soft-card px-4 py-3 text-sm leading-6 text-black/48">
                        最近两个版本的 payload 没有检测到字段变化。
                      </div>
                    ) : (
                      versionDiffRows.slice(0, 12).map((row) => (
                        <div key={row.key} className="admin-reference-soft-card p-4">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="text-sm font-semibold text-[#071110]">{formatLabelFromKey(row.key)}</span>
                            <span className="admin-reference-chip bg-[#f5f5f7] text-black/55">
                              {row.kind === 'added' ? '新增' : row.kind === 'removed' ? '移除' : '变更'}
                            </span>
                          </div>
                          <div className="mt-3 grid gap-3 md:grid-cols-2">
                            <div className="rounded-[20px] border border-[#e8eceb] bg-white px-3 py-3 text-xs leading-6 text-black/48">
                              <div className="mb-1 text-[11px] uppercase tracking-[0.2em] text-black/35">Before</div>
                              {summarizePrimitive(row.before)}
                            </div>
                            <div className="rounded-[20px] border border-[#e8eceb] bg-white px-3 py-3 text-xs leading-6 text-black/48">
                              <div className="mb-1 text-[11px] uppercase tracking-[0.2em] text-black/35">After</div>
                              {summarizePrimitive(row.after)}
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </div>

              <div className="admin-reference-card p-5">
                  <div className="text-sm text-black/42">Payload Preview</div>
                  <h3 className="mt-2 text-xl font-semibold text-[#071110]">提交内容预览</h3>
                  <pre className="mt-4 max-h-[420px] overflow-auto rounded-[22px] border border-[#e8eceb] bg-[#f8f9f8] p-4 text-xs leading-6 text-black/52">
                    {JSON.stringify(selectedDetail.payload, null, 2)}
                  </pre>
              </div>

              <div className="admin-reference-card p-5">
                <div className="text-sm text-black/42">Version History</div>
                <h3 className="mt-2 text-xl font-semibold text-[#071110]">版本历史</h3>
                <div className="mt-4 space-y-3">
                  {(selectedDetail.versions || []).map((version) => (
                    <details key={version.id} className="admin-reference-soft-card p-4">
                      <summary className="cursor-pointer list-none text-sm font-semibold text-[#071110]">
                        v{version.version} · {version.changeNote || '未填写变更说明'} · {formatDateTime(version.submittedAt)}
                      </summary>
                      <pre className="mt-4 max-h-64 overflow-auto rounded-[20px] border border-[#e8eceb] bg-white p-4 text-xs leading-6 text-black/52">
                        {JSON.stringify(version.payload, null, 2)}
                      </pre>
                    </details>
                  ))}
                </div>
              </div>
            </div>
          )}
        </section>
      </section>
    </AdminContentLayout>
  );
}
