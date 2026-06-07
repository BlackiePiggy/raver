'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  ChevronDown,
  RefreshCw,
  Search,
  Clock,
  Hourglass,
  CheckCircle2,
  ThumbsUp,
  ShieldX,
  Check,
  X,
  MoreHorizontal,
} from 'lucide-react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  contentSubmissionsApi,
  type ContentSubmission,
  type ContentSubmissionDetail,
  type ContentSubmissionEntityType,
  type ContentSubmissionStatus,
  type ContentSubmissionVersion,
} from '@/lib/api/content-submissions';

// ─── Constants ───────────────────────────────────────────────────────────────

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

const PAGE_SIZE = 20;

type ReviewReasonTemplate = {
  code: string;
  label: string;
  suggestion: string;
  group?: string;
};

const REVIEW_REASON_TEMPLATES: Record<ContentSubmissionEntityType, ReviewReasonTemplate[]> = {
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

const QUICK_REJECT_LABELS = ['信息不完整', '数据错误', '重复提交', '不符合规范', '其他'];

// ─── Helpers ─────────────────────────────────────────────────────────────────

const formatDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit',
  }).format(new Date(value));
};

const formatLabelFromKey = (key: string): string =>
  key.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/[_.-]+/g, ' ').trim() || 'unknown';

const summarizePrimitive = (value: unknown): string => {
  if (value === null || value === undefined || value === '') return '空';
  if (typeof value === 'string') { const t = value.trim(); return t ? t.slice(0, 80) : '空'; }
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return `${value.length} 项`;
  if (typeof value === 'object') return '对象';
  return String(value);
};

const stableStringify = (value: unknown): string => {
  if (Array.isArray(value)) return `[${value.map((i) => stableStringify(i)).join(',')}]`;
  if (value && typeof value === 'object') {
    const row = value as Record<string, unknown>;
    return `{${Object.keys(row).sort().map((k) => `${k}:${stableStringify(row[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
};

const asObject = (value: unknown): Record<string, unknown> | null =>
  value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;

const asArray = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const normalizeText = (value: unknown): string => String(value ?? '').trim();
const uniqueStrings = (values: string[]): string[] => Array.from(new Set(values.filter(Boolean)));

const diffStringList = (previous: unknown, current: unknown): { added: string[]; removed: string[] } => {
  const prevItems = uniqueStrings(asArray(previous).map((i) => normalizeText(i)));
  const nextItems = uniqueStrings(asArray(current).map((i) => normalizeText(i)));
  return { added: nextItems.filter((i) => !prevItems.includes(i)), removed: prevItems.filter((i) => !nextItems.includes(i)) };
};

const formatSlotClock = (value: unknown): string => {
  const text = normalizeText(value);
  if (!text) return '--:--';
  const match = text.match(/T(\d{2}:\d{2})/);
  if (match?.[1]) return match[1];
  if (/^\d{2}:\d{2}/.test(text)) return text.slice(0, 5);
  return text;
};

const formatBooleanState = (value: unknown, labels: { truthy: string; falsy: string }): string => {
  if (value === true) return labels.truthy;
  if (value === false) return labels.falsy;
  return '未设置';
};

const formatEventVisibility = (value: unknown): string => {
  const normalized = normalizeText(value).toLowerCase();
  if (normalized === 'hidden') return '隐藏';
  if (normalized === 'visible') return '可见';
  return normalized || '未设置';
};

const formatEventDateTime = (value: unknown): string => {
  const text = normalizeText(value);
  if (!text) return '未设置';
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) return text;
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(parsed);
};

// ─── Types ────────────────────────────────────────────────────────────────────

type DiffRow = { key: string; before: unknown; after: unknown; kind: 'added' | 'removed' | 'changed' };
type SemanticDiffSection = { title: string; rows: string[] };
type ReviewRecommendation = { code: string; label: string; suggestion: string; rationale: string };

type EventDaySemanticRecord = { compareKey: string; date: string; label: string; weekday: string; summary: string };
type EventSlotSemanticRecord = { compareKey: string; localDate: string; stageName: string; djName: string; startTime: string; endTime: string; summary: string };

// ─── Semantic record builders ─────────────────────────────────────────────────

const buildEventDaySemanticRecords = (value: unknown): EventDaySemanticRecord[] =>
  asArray(value).map((item, index) => {
    const row = asObject(item);
    const date = normalizeText(row?.date);
    const label = normalizeText(row?.label);
    const weekday = normalizeText(row?.weekday);
    const eventDayId = normalizeText(row?.eventDayId);
    const overallDayIndex = normalizeText(row?.overallDayIndex);
    const compareKey = date || eventDayId || `${overallDayIndex || 'day'}-${index}`;
    return { compareKey, date, label, weekday, summary: [date, label, weekday].filter(Boolean).join(' · ') || `活动日 ${index + 1}` };
  });

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
    const compareKey = canonicalSlotId || `${eventDayId || localDate || 'day'}|${sortOrder || index}|${startTime}|${endTime}`;
    return { compareKey, localDate, stageName, djName, startTime, endTime, summary: [localDate || '未标日期', `${startTime}-${endTime}`, stageName || '未设舞台', djName || '未设艺人'].join(' · ') };
  });

// ─── Auto review signals ──────────────────────────────────────────────────────

const buildEventAutoReviewSignals = (detail: ContentSubmissionDetail | null, latest?: ContentSubmissionVersion | null): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'event') return { signals: [], recommendations: [] };
  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const reviewNotes = detail.reviewNotes && typeof detail.reviewNotes === 'object' && !Array.isArray(detail.reviewNotes) ? (detail.reviewNotes as Record<string, unknown>) : {};
  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];
  const eventDays = asArray(payload.eventDays);
  const lineupArtists = asArray(payload.lineupArtists);
  const lineupSlots = buildEventSlotSemanticRecords(payload.lineupSlots);
  const eventDayDates = uniqueStrings(eventDays.map((i) => normalizeText(asObject(i)?.date)));
  const slotArtistNames = uniqueStrings(lineupSlots.map((i) => i.djName));
  const lineupArtistNames = uniqueStrings(lineupArtists.map((i) => normalizeText(asObject(i)?.djName || asObject(i)?.name)));
  const missingFromLineup = slotArtistNames.filter((i) => !lineupArtistNames.includes(i));
  const extraInLineup = lineupArtistNames.filter((i) => !slotArtistNames.includes(i));
  if (eventDays.length === 0) signals.push('当前活动 payload 缺少 eventDays。');
  if (lineupSlots.length > 0 && eventDays.length === 0) signals.push('时刻表已有内容，但没有正式活动日结构。');
  if (missingFromLineup.length > 0) signals.push(`时刻表中存在 ${missingFromLineup.length} 位未进入正式阵容的艺人：${missingFromLineup.slice(0, 4).join(', ')}`);
  if (extraInLineup.length > 0) signals.push(`正式阵容中存在 ${extraInLineup.length} 位没有对应时段的艺人：${extraInLineup.slice(0, 4).join(', ')}`);
  const invalidSlotDates = lineupSlots.filter((s) => s.localDate && !eventDayDates.includes(s.localDate));
  if (invalidSlotDates.length > 0) signals.push(`有 ${invalidSlotDates.length} 个时段的日期不在当前活动日结构内。`);
  const overlapWarnings: string[] = [];
  const groupedSlots = new Map<string, EventSlotSemanticRecord[]>();
  lineupSlots.forEach((s) => { const key = `${s.localDate}|${s.stageName || '未设舞台'}`; const b = groupedSlots.get(key) ?? []; b.push(s); groupedSlots.set(key, b); });
  groupedSlots.forEach((slots, key) => { const sorted = slots.slice().sort((a, b) => a.startTime.localeCompare(b.startTime)); for (let i = 1; i < sorted.length; i++) { if (sorted[i - 1].endTime > sorted[i].startTime) overlapWarnings.push(`${key}：${sorted[i-1].djName||'未设艺人'} 与 ${sorted[i].djName||'未设艺人'} 时段重叠`); } });
  if (overlapWarnings.length > 0) signals.push(`检测到 ${overlapWarnings.length} 组同舞台时段重叠。`);
  const phaseBFailure = reviewNotes.phaseBFailure && typeof reviewNotes.phaseBFailure === 'object' && !Array.isArray(reviewNotes.phaseBFailure) ? (reviewNotes.phaseBFailure as Record<string, unknown>) : null;
  if (phaseBFailure) signals.push(`系统后处理失败：${summarizePrimitive(phaseBFailure.message)}`);
  if (missingFromLineup.length > 0 || extraInLineup.length > 0) recommendations.push({ code: 'event_lineup_alignment_gap', label: '建议使用：阵容未对齐', suggestion: '当前活动的 lineup 与 timetable 还没有完全对齐，请补齐缺失艺人或清理多余阵容后重新提交。', rationale: '系统检测到正式阵容与时刻表名单不一致。' });
  if (overlapWarnings.length > 0) recommendations.push({ code: 'event_timetable_overlap', label: '建议使用：时段冲突', suggestion: '当前活动时刻表存在同舞台重叠时段或明显冲突，请修正后重新提交。', rationale: '系统检测到同一天同舞台的演出时间存在重叠。' });
  if (eventDays.length === 0 || invalidSlotDates.length > 0) recommendations.push({ code: 'event_schedule_incomplete', label: '建议使用：排期不完整', suggestion: '活动日期、eventDays 或 timetable 信息还不完整，请补充后重新提交。', rationale: '系统检测到活动日结构缺失，或时刻表日期未落入合法活动日。' });
  if (phaseBFailure) recommendations.push({ code: 'event_phase_b_failure', label: '建议使用：同步待修复', suggestion: '当前活动主结构可识别，但时间表同步或后处理出现异常，请先修复后重新提交。', rationale: '系统已记录后处理失败信号。' });
  return { signals, recommendations };
};

const buildBrandAutoReviewSignals = (detail: ContentSubmissionDetail | null, latest?: ContentSubmissionVersion | null): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'brand') return { signals: [], recommendations: [] };
  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const reviewNotes = detail.reviewNotes && typeof detail.reviewNotes === 'object' && !Array.isArray(detail.reviewNotes) ? (detail.reviewNotes as Record<string, unknown>) : {};
  const brandScreening = reviewNotes.brandScreening && typeof reviewNotes.brandScreening === 'object' && !Array.isArray(reviewNotes.brandScreening) ? (reviewNotes.brandScreening as Record<string, unknown>) : null;
  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];
  const hasPrimaryVisual = Boolean(normalizeText(payload.avatarUrl)) || Boolean(normalizeText(payload.backgroundUrl)) || asArray(payload.imageAssets).some((i) => { const r = asObject(i); const t = normalizeText(r?.type).toLowerCase(); return Boolean(normalizeText(r?.url)) && ['avatar','background','poster'].includes(t); });
  const hasProof = Boolean(normalizeText(payload.proofImageUrl)) || asArray(payload.imageAssets).some((i) => { const r = asObject(i); return Boolean(normalizeText(r?.url)) && normalizeText(r?.type).toLowerCase() === 'proof'; });
  const officialLinkCount = [payload.officialWebsite, payload.facebookUrl, payload.instagramUrl, payload.twitterUrl, payload.youtubeUrl, payload.tiktokUrl].filter((i) => Boolean(normalizeText(i))).length;
  const rightsConfirmed = Boolean(payload.rightsConfirmed);
  const identityConfirmed = Boolean(payload.identityConfirmed);
  if (!hasPrimaryVisual) signals.push('当前主办方缺少稳定可用的主视觉素材。');
  if (!hasProof && officialLinkCount === 0) signals.push('当前主办方既没有官方链接，也没有 proof 图片。');
  else if (!hasProof) signals.push('当前主办方没有 proof 图片，审核将主要依赖外部官方链接。');
  if (!rightsConfirmed || !identityConfirmed) signals.push('版权确认或主体确认尚未完成。');
  if (brandScreening?.duplicateBrandWarning) { const d = asArray(brandScreening.duplicateBrands).map((i) => normalizeText(asObject(i)?.name)).filter(Boolean); signals.push(`系统检测到可能重复的主办方：${d.slice(0, 3).join(', ') || '请人工核查'}`); }
  if (brandScreening?.eventNameConflictWarning) { const d = asArray(brandScreening.similarEvents).map((i) => normalizeText(asObject(i)?.name)).filter(Boolean); signals.push(`系统检测到名称相近的活动：${d.slice(0, 3).join(', ') || '请人工核查'}`); }
  if (!hasPrimaryVisual) recommendations.push({ code: 'brand_media_incomplete', label: '建议使用：视觉资料不足', suggestion: '主办方缺少稳定可用的头像、背景或主视觉素材，请完善后重新提交。', rationale: '系统未检测到可作为正式品牌资料使用的主视觉素材。' });
  if (!rightsConfirmed || !identityConfirmed || (!hasProof && officialLinkCount === 0)) recommendations.push({ code: !rightsConfirmed || !identityConfirmed ? 'brand_identity_unverified' : 'brand_links_missing', label: !rightsConfirmed || !identityConfirmed ? '建议使用：主体待确认' : '建议使用：官方链接不足', suggestion: !rightsConfirmed || !identityConfirmed ? '品牌主体或版权声明还需要进一步确认，请补充证明信息。' : '主办方缺少足够的官方链接或 proof，请补充后重新提交。', rationale: !rightsConfirmed || !identityConfirmed ? '系统检测到版权声明或主体确认未完成。' : '系统检测到该主办方缺少可支撑审核的官方可信来源。' });
  return { signals, recommendations };
};

const buildDJAutoReviewSignals = (detail: ContentSubmissionDetail | null, latest?: ContentSubmissionVersion | null): { signals: string[]; recommendations: ReviewRecommendation[] } => {
  if (!detail || detail.entityType !== 'dj') return { signals: [], recommendations: [] };
  const payload = (latest?.payload || detail.payload || {}) as Record<string, unknown>;
  const signals: string[] = [];
  const recommendations: ReviewRecommendation[] = [];
  const hasAvatar = Boolean(normalizeText(payload.avatarUrl));
  const hasBanner = Boolean(normalizeText(payload.bannerUrl));
  const hasProof = Boolean(normalizeText(payload.proofImageUrl));
  const platformLinks = [payload.spotifyUrl, payload.instagramUrl, payload.facebookUrl, payload.soundcloudUrl, payload.youtubeUrl, payload.website, payload.otherPlatformUrl, payload.neteaseUrl, payload.qqMusicUrl].filter((i) => Boolean(normalizeText(i)));
  const aliases = asArray(payload.aliases).map((i) => normalizeText(i)).filter(Boolean);
  const genres = asArray(payload.genres).map((i) => normalizeText(i)).filter(Boolean);
  const spotifyFollowers = typeof payload.spotifyFollowers === 'number' ? payload.spotifyFollowers : null;
  if (!hasAvatar) signals.push('当前 DJ 缺少头像。');
  if (!hasBanner) signals.push('当前 DJ 没有横幅素材，展示面完整度不足。');
  if (!hasProof && platformLinks.length === 0) signals.push('当前 DJ 既没有平台链接，也没有 proof 图片。');
  else if (!hasProof) signals.push('当前 DJ 没有 proof 图片，审核将主要依赖外部平台链接。');
  if (aliases.length === 0) signals.push('当前 DJ 没有补充别名，跨平台识别能力偏弱。');
  if (genres.length === 0) signals.push('当前 DJ 没有风格标签，资料完整度偏低。');
  if (spotifyFollowers !== null && spotifyFollowers <= 0 && normalizeText(payload.spotifyUrl)) signals.push('已填写 Spotify 链接，但粉丝量数据为空或异常，建议人工复核。');
  if (!hasAvatar || !hasBanner) recommendations.push({ code: 'dj_media_incomplete', label: '建议使用：素材不足', suggestion: 'DJ 的头像、横幅或 proof 资料还不完整，请完善后重新提交。', rationale: '系统检测到 DJ 缺少核心视觉素材，影响后台展示和资料可信度。' });
  if (!hasProof && platformLinks.length === 0) recommendations.push({ code: 'dj_links_missing', label: '建议使用：平台链接不足', suggestion: 'DJ 缺少足够的平台链接或 proof，请补充后重新提交。', rationale: '系统未检测到可用于核验身份的平台链接或 proof。' });
  if (aliases.length === 0 && genres.length === 0) recommendations.push({ code: 'dj_profile_incomplete', label: '建议使用：资料不完整', suggestion: 'DJ 名称、头像或简介信息仍不完整，请完善后重新提交。', rationale: '系统检测到该 DJ 的识别字段和基础资料都偏少。' });
  return { signals, recommendations };
};

// ─── Diff builders ────────────────────────────────────────────────────────────

const buildVersionDiffRows = (previous?: ContentSubmissionVersion | null, current?: ContentSubmissionVersion | null): DiffRow[] => {
  const before = previous?.payload || {};
  const after = current?.payload || {};
  const keys = Array.from(new Set([...Object.keys(before), ...Object.keys(after)])).sort((a, b) => a.localeCompare(b));
  return keys.map((key): DiffRow | null => {
    const beforeValue = before[key]; const afterValue = after[key];
    const hasBefore = Object.prototype.hasOwnProperty.call(before, key);
    const hasAfter = Object.prototype.hasOwnProperty.call(after, key);
    if (!hasBefore && hasAfter) return { key, before: undefined, after: afterValue, kind: 'added' };
    if (hasBefore && !hasAfter) return { key, before: beforeValue, after: undefined, kind: 'removed' };
    if (stableStringify(beforeValue) !== stableStringify(afterValue)) return { key, before: beforeValue, after: afterValue, kind: 'changed' };
    return null;
  }).filter((i): i is DiffRow => i !== null);
};

const semanticEventDiffSections = (previous: Record<string, unknown>, current: Record<string, unknown>): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsTruth: string[] = [];
  const previousCancelled = previous.isCancelled;
  const currentCancelled = current.isCancelled;
  if (previousCancelled !== currentCancelled) {
    rowsTruth.push(
      `取消状态：${formatBooleanState(previousCancelled, { truthy: '已取消', falsy: '正常' })} -> ${formatBooleanState(currentCancelled, { truthy: '已取消', falsy: '正常' })}`
    );
  }
  const previousVisibility = normalizeText(previous.visibility).toLowerCase();
  const currentVisibility = normalizeText(current.visibility).toLowerCase();
  if (previousVisibility !== currentVisibility) {
    rowsTruth.push(`可见性：${formatEventVisibility(previous.visibility)} -> ${formatEventVisibility(current.visibility)}`);
  }
  if (rowsTruth.length > 0) sections.push({ title: '状态与可见性', rows: rowsTruth });

  const rowsTime: string[] = [];
  if (normalizeText(previous.startDate) !== normalizeText(current.startDate)) {
    rowsTime.push(`开始时间：${formatEventDateTime(previous.startDate)} -> ${formatEventDateTime(current.startDate)}`);
  }
  if (normalizeText(previous.endDate) !== normalizeText(current.endDate)) {
    rowsTime.push(`结束时间：${formatEventDateTime(previous.endDate)} -> ${formatEventDateTime(current.endDate)}`);
  }
  if (normalizeText(previous.startTime) !== normalizeText(current.startTime)) {
    rowsTime.push(`日内开始时间：${summarizePrimitive(previous.startTime)} -> ${summarizePrimitive(current.startTime)}`);
  }
  if (normalizeText(previous.endTime) !== normalizeText(current.endTime)) {
    rowsTime.push(`日内结束时间：${summarizePrimitive(previous.endTime)} -> ${summarizePrimitive(current.endTime)}`);
  }
  if (normalizeText(previous.timeZone) !== normalizeText(current.timeZone)) {
    rowsTime.push(`时区：${summarizePrimitive(previous.timeZone)} -> ${summarizePrimitive(current.timeZone)}`);
  }
  if (summarizePrimitive(previous.dayRolloverHour) !== summarizePrimitive(current.dayRolloverHour)) {
    rowsTime.push(`跨日切分时间：${summarizePrimitive(previous.dayRolloverHour)} -> ${summarizePrimitive(current.dayRolloverHour)}`);
  }
  const previousScheduleMode = normalizeText(previous.scheduleMode || asObject(previous.schedule)?.mode);
  const currentScheduleMode = normalizeText(current.scheduleMode || asObject(current.schedule)?.mode);
  if (previousScheduleMode !== currentScheduleMode) {
    rowsTime.push(`排期模式：${summarizePrimitive(previousScheduleMode)} -> ${summarizePrimitive(currentScheduleMode)}`);
  }
  if (rowsTime.length > 0) sections.push({ title: '时间真值', rows: rowsTime });

  const rowsSchedule: string[] = [];
  const prevSchedule = asObject(previous.schedule); const nextSchedule = asObject(current.schedule);
  if ((prevSchedule?.mode || '') !== (nextSchedule?.mode || '')) rowsSchedule.push(`排期模式：${summarizePrimitive(prevSchedule?.mode)} -> ${summarizePrimitive(nextSchedule?.mode)}`);
  if ((prevSchedule?.timeZone || '') !== (nextSchedule?.timeZone || '')) rowsSchedule.push(`时区：${summarizePrimitive(prevSchedule?.timeZone)} -> ${summarizePrimitive(nextSchedule?.timeZone)}`);
  const prevEventDays = buildEventDaySemanticRecords(previous.eventDays); const nextEventDays = buildEventDaySemanticRecords(current.eventDays);
  if (prevEventDays.length !== nextEventDays.length) rowsSchedule.push(`活动日：${prevEventDays.length} 天 -> ${nextEventDays.length} 天`);
  const prevEventDayDates = prevEventDays.map((i) => i.date).filter(Boolean).sort();
  const nextEventDayDates = nextEventDays.map((i) => i.date).filter(Boolean).sort();
  const addedDates = nextEventDayDates.filter((i) => !prevEventDayDates.includes(i));
  const removedDates = prevEventDayDates.filter((i) => !nextEventDayDates.includes(i));
  if (addedDates.length > 0) rowsSchedule.push(`新增活动日：${addedDates.slice(0, 4).join(', ')}`);
  if (removedDates.length > 0) rowsSchedule.push(`移除活动日：${removedDates.slice(0, 4).join(', ')}`);
  if (rowsSchedule.length > 0) sections.push({ title: '活动排期', rows: rowsSchedule });
  const rowsLineup: string[] = [];
  const prevArtists = asArray(previous.lineupArtists); const nextArtists = asArray(current.lineupArtists);
  if (prevArtists.length !== nextArtists.length) rowsLineup.push(`阵容艺人：${prevArtists.length} -> ${nextArtists.length}`);
  const prevArtistNames = prevArtists.map((i) => { const r = asObject(i); return String(r?.djName || r?.name || '').trim(); }).filter(Boolean);
  const nextArtistNames = nextArtists.map((i) => { const r = asObject(i); return String(r?.djName || r?.name || '').trim(); }).filter(Boolean);
  const addedArtists = nextArtistNames.filter((i) => !prevArtistNames.includes(i));
  const removedArtists = prevArtistNames.filter((i) => !nextArtistNames.includes(i));
  if (addedArtists.length > 0) rowsLineup.push(`新增艺人：${addedArtists.slice(0, 5).join(', ')}`);
  if (removedArtists.length > 0) rowsLineup.push(`移除艺人：${removedArtists.slice(0, 5).join(', ')}`);
  const prevSlots = buildEventSlotSemanticRecords(previous.lineupSlots); const nextSlots = buildEventSlotSemanticRecords(current.lineupSlots);
  if (prevSlots.length !== nextSlots.length) rowsLineup.push(`演出时段：${prevSlots.length} -> ${nextSlots.length}`);
  if (rowsLineup.length > 0) sections.push({ title: '阵容与时刻表', rows: rowsLineup });
  return sections;
};

const semanticBrandDiffSections = (previous: Record<string, unknown>, current: Record<string, unknown>): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsProfile: string[] = [];
  if ((previous.name || '') !== (current.name || '')) rowsProfile.push(`主名称：${summarizePrimitive(previous.name)} -> ${summarizePrimitive(current.name)}`);
  const aliasChanges = diffStringList(previous.aliases, current.aliases);
  if (aliasChanges.added.length > 0) rowsProfile.push(`新增别名：${aliasChanges.added.slice(0, 4).join(', ')}`);
  if (aliasChanges.removed.length > 0) rowsProfile.push(`移除别名：${aliasChanges.removed.slice(0, 4).join(', ')}`);
  if ((previous.country || '') !== (current.country || '') || (previous.city || '') !== (current.city || '')) rowsProfile.push(`地区：${summarizePrimitive(previous.country)} / ${summarizePrimitive(previous.city)} -> ${summarizePrimitive(current.country)} / ${summarizePrimitive(current.city)}`);
  if (rowsProfile.length > 0) sections.push({ title: '主办方资料', rows: rowsProfile });
  const rowsMedia: string[] = [];
  if ((previous.proofImageUrl || '') !== (current.proofImageUrl || '')) rowsMedia.push('Proof 图片已发生变化');
  if ((previous.avatarUrl || '') !== (current.avatarUrl || '')) rowsMedia.push('头像素材已更新');
  if ((previous.backgroundUrl || '') !== (current.backgroundUrl || '')) rowsMedia.push('背景素材已更新');
  if (rowsMedia.length > 0) sections.push({ title: '媒体与证明', rows: rowsMedia });
  return sections;
};

const semanticDJDiffSections = (previous: Record<string, unknown>, current: Record<string, unknown>): SemanticDiffSection[] => {
  const sections: SemanticDiffSection[] = [];
  const rowsIdentity: string[] = [];
  if ((previous.name || '') !== (current.name || '')) rowsIdentity.push(`名称：${summarizePrimitive(previous.name)} -> ${summarizePrimitive(current.name)}`);
  const aliasChanges = diffStringList(previous.aliases, current.aliases);
  if (aliasChanges.added.length > 0) rowsIdentity.push(`新增别名：${aliasChanges.added.slice(0, 4).join(', ')}`);
  if (aliasChanges.removed.length > 0) rowsIdentity.push(`移除别名：${aliasChanges.removed.slice(0, 4).join(', ')}`);
  const genreChanges = diffStringList(previous.genres, current.genres);
  if (genreChanges.added.length > 0) rowsIdentity.push(`新增风格：${genreChanges.added.slice(0, 5).join(', ')}`);
  if (genreChanges.removed.length > 0) rowsIdentity.push(`移除风格：${genreChanges.removed.slice(0, 5).join(', ')}`);
  if (rowsIdentity.length > 0) sections.push({ title: 'DJ 身份资料', rows: rowsIdentity });
  return sections;
};

const semanticDiffSections = (entityType: ContentSubmissionEntityType | undefined, previous?: ContentSubmissionVersion | null, current?: ContentSubmissionVersion | null): SemanticDiffSection[] => {
  const prevPayload = asObject(previous?.payload) || {};
  const nextPayload = asObject(current?.payload) || {};
  if (!entityType) return [];
  if (entityType === 'event') return semanticEventDiffSections(prevPayload, nextPayload);
  if (entityType === 'brand') return semanticBrandDiffSections(prevPayload, nextPayload);
  if (entityType === 'dj') return semanticDJDiffSections(prevPayload, nextPayload);
  return [];
};

// ─── Link builders ────────────────────────────────────────────────────────────

const buildAdminEditLink = (submission: ContentSubmission | ContentSubmissionDetail): string | null => {
  if (!submission.createdEntityId) return null;
  if (submission.entityType === 'event') return `/admin/content/events/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'brand') return `/admin/content/organizers/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'dj') return `/admin/content/djs/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'news') return `/admin/content/news/${submission.createdEntityId}/edit`;
  if (submission.entityType === 'label') return `/admin/content/labels/${submission.createdEntityId}/edit`;
  return null;
};

const buildContentHistoryLink = (submission: ContentSubmission | ContentSubmissionDetail): string | null => {
  if (!submission.createdEntityId) return null;
  const entityType = submission.entityType === 'brand' ? 'festival' : submission.entityType === 'news' ? 'news_article' : submission.entityType;
  if (!['event', 'dj', 'festival', 'news_article', 'label'].includes(entityType)) return null;
  return `/admin/notification-center/content-history?entityType=${encodeURIComponent(entityType)}&query=${encodeURIComponent(submission.createdEntityId)}`;
};

const reviewNotesSections = (detail: ContentSubmissionDetail | null): Array<{ title: string; rows: string[] }> => {
  if (!detail?.reviewNotes || typeof detail.reviewNotes !== 'object') return [];
  const reviewNotes = detail.reviewNotes as Record<string, unknown>;
  const sections: Array<{ title: string; rows: string[] }> = [];
  const i18n = reviewNotes.i18n && typeof reviewNotes.i18n === 'object' && !Array.isArray(reviewNotes.i18n) ? (reviewNotes.i18n as Record<string, unknown>) : null;
  if (i18n) {
    const rows: string[] = [];
    if (typeof i18n.status === 'string') rows.push(`状态：${i18n.status}`);
    if (Array.isArray(i18n.missingLocales) && i18n.missingLocales.length > 0) rows.push(`缺失语种：${i18n.missingLocales.join(', ')}`);
    if (typeof i18n.autoTranslated === 'boolean') rows.push(`机器翻译：${i18n.autoTranslated ? '是' : '否'}`);
    if (typeof i18n.manuallyConfirmed === 'boolean') rows.push(`人工确认：${i18n.manuallyConfirmed ? '已确认' : '未确认'}`);
    if (rows.length > 0) sections.push({ title: 'i18n 检查', rows });
  }
  const compliance = reviewNotes.compliance && typeof reviewNotes.compliance === 'object' && !Array.isArray(reviewNotes.compliance) ? (reviewNotes.compliance as Record<string, unknown>) : null;
  if (compliance) {
    const rows = Object.entries(compliance).filter(([, v]) => v !== null && v !== undefined && v !== '').slice(0, 6).map(([k, v]) => `${formatLabelFromKey(k)}：${summarizePrimitive(v)}`);
    if (rows.length > 0) sections.push({ title: '合规信号', rows });
  }
  return sections;
};

// ─── Sub-components ───────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: ContentSubmissionStatus }) {
  const map: Record<string, string> = {
    pending: 'bg-amber-50 text-amber-700 border border-amber-200',
    reviewing: 'bg-blue-50 text-blue-700 border border-blue-200',
    processing: 'bg-violet-50 text-violet-700 border border-violet-200',
    approved: 'bg-emerald-50 text-emerald-700 border border-emerald-200',
    rejected: 'bg-red-50 text-red-700 border border-red-200',
    failed: 'bg-rose-50 text-rose-700 border border-rose-200',
    cancelled: 'bg-gray-100 text-gray-500 border border-gray-200',
  };
  const label: Record<string, string> = { pending: '待审核', reviewing: '审核中', processing: '处理中', approved: '已通过', rejected: '未通过', failed: '失败', cancelled: '已取消' };
  return <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${map[status] ?? 'bg-gray-100 text-gray-500'}`}>{label[status] ?? status}</span>;
}

function EntityChip({ type }: { type: string }) {
  return <span className="inline-flex items-center rounded-md bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">{type}</span>;
}

type RightPanelTab = 'basic' | 'structured' | 'payload' | 'diff';

// ─── Main Component ───────────────────────────────────────────────────────────

export default function ReviewSubmissionsPageClient() {
  const [statusFilter, setStatusFilter] = useState('pending');
  const [entityFilter, setEntityFilter] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<ContentSubmission[]>([]);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [selectedId, setSelectedId] = useState('');
  const [selectedDetail, setSelectedDetail] = useState<ContentSubmissionDetail | null>(null);
  const [loadingList, setLoadingList] = useState(true);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [submittingDecision, setSubmittingDecision] = useState(false);
  const [selectedReasonCode, setSelectedReasonCode] = useState('');
  const [decisionReason, setDecisionReason] = useState('');
  const [latestApprovedSubmission, setLatestApprovedSubmission] = useState<ContentSubmission | null>(null);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [rightTab, setRightTab] = useState<RightPanelTab>('basic');
  const [showMoreActions, setShowMoreActions] = useState(false);

  const selectedSummary = useMemo(() => items.find((i) => i.id === selectedId) ?? null, [items, selectedId]);

  const loadList = useCallback(async () => {
    try {
      setLoadingList(true); setError(''); setSuccessMessage('');
      const result = await contentSubmissionsApi.listAdmin({ status: statusFilter === 'pending' ? undefined : statusFilter, statuses: statusFilter === 'pending' ? REVIEWABLE_STATUSES : undefined, entityType: entityFilter || undefined, page, limit: PAGE_SIZE });
      setItems(result.items); setTotal(result.total); setTotalPages(result.pagination.totalPages);
      setSelectedId((cur) => (result.items.some((i) => i.id === cur) ? cur : result.items[0]?.id || ''));
    } catch (e) { setError(e instanceof Error ? e.message : '审核列表加载失败'); }
    finally { setLoadingList(false); }
  }, [entityFilter, page, statusFilter]);

  const loadDetail = useCallback(async (submissionId: string) => {
    if (!submissionId) { setSelectedDetail(null); return; }
    try {
      setLoadingDetail(true);
      const result = await contentSubmissionsApi.getAdminDetail(submissionId);
      setSelectedDetail(result.submission); setDecisionReason(result.submission.reviewReason || '');
      const reviewDecision = result.submission.reviewNotes && typeof result.submission.reviewNotes === 'object' && !Array.isArray(result.submission.reviewNotes) && result.submission.reviewNotes.reviewDecision && typeof result.submission.reviewNotes.reviewDecision === 'object' && !Array.isArray(result.submission.reviewNotes.reviewDecision) ? (result.submission.reviewNotes.reviewDecision as Record<string, unknown>) : null;
      setSelectedReasonCode(typeof reviewDecision?.reasonCode === 'string' ? reviewDecision.reasonCode : '');
    } catch (e) { setSelectedDetail(null); setError(e instanceof Error ? e.message : '审核详情加载失败'); }
    finally { setLoadingDetail(false); }
  }, []);

  useEffect(() => { void loadList(); }, [loadList]);
  useEffect(() => { void loadDetail(selectedId); }, [loadDetail, selectedId]);

  const handleDecision = async (decision: 'approved' | 'rejected') => {
    if (!selectedDetail) return;
    if (decision === 'rejected' && !selectedReasonCode.trim()) { setError('拒绝提交时请先选择一个 reason code 模板。'); return; }
    if (decision === 'rejected' && !decisionReason.trim()) { setError('拒绝提交时请填写原因，方便内容同学回改。'); return; }
    try {
      setSubmittingDecision(true); setError('');
      const mergedReviewNotes = selectedDetail.reviewNotes && typeof selectedDetail.reviewNotes === 'object' && !Array.isArray(selectedDetail.reviewNotes) ? { ...selectedDetail.reviewNotes } : {};
      mergedReviewNotes.reviewDecision = { decision, reasonCode: selectedReasonCode || null, reviewerNote: decisionReason.trim() || null, reviewedAt: new Date().toISOString() };
      const result = await contentSubmissionsApi.review(selectedDetail.id, { decision, reason: decision === 'rejected' ? decisionReason.trim() : undefined, reviewNotes: mergedReviewNotes });
      setSuccessMessage(result.message || `已${decision === 'approved' ? '通过' : '拒绝'}当前提交`);
      setLatestApprovedSubmission(decision === 'approved' ? result.submission : null);
      await loadList(); await loadDetail(selectedDetail.id);
    } catch (e) { setError(e instanceof Error ? e.message : '提交审核决策失败'); }
    finally { setSubmittingDecision(false); }
  };

  const visiblePages = useMemo(() => {
    const safe = Math.max(1, totalPages);
    const start = Math.max(1, Math.min(safe - 4, page - 2));
    const end = Math.min(safe, start + 4);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  }, [page, totalPages]);

  const canReview = Boolean(selectedDetail && REVIEWABLE_STATUSES.includes(selectedDetail.status));
  const noteSections = reviewNotesSections(selectedDetail);
  const reasonTemplates = selectedDetail ? REVIEW_REASON_TEMPLATES[selectedDetail.entityType] || [] : [];
  const latestApprovedHistoryLink = latestApprovedSubmission ? buildContentHistoryLink(latestApprovedSubmission) : null;
  const latestVersion = selectedDetail?.versions?.[0] ?? null;
  const previousVersion = selectedDetail?.versions?.[1] ?? null;

  const autoReviewInsights = useMemo(() => {
    if (!selectedDetail) return { signals: [], recommendations: [] };
    if (selectedDetail.entityType === 'event') return buildEventAutoReviewSignals(selectedDetail, latestVersion);
    if (selectedDetail.entityType === 'brand') return buildBrandAutoReviewSignals(selectedDetail, latestVersion);
    if (selectedDetail.entityType === 'dj') return buildDJAutoReviewSignals(selectedDetail, latestVersion);
    return { signals: [], recommendations: [] };
  }, [latestVersion, selectedDetail]);

  const versionDiffRows = useMemo(() => buildVersionDiffRows(previousVersion, latestVersion), [latestVersion, previousVersion]);
  const diffStats = useMemo(() => ({ added: versionDiffRows.filter((i) => i.kind === 'added').length, removed: versionDiffRows.filter((i) => i.kind === 'removed').length, changed: versionDiffRows.filter((i) => i.kind === 'changed').length }), [versionDiffRows]);
  const semanticSections = useMemo(() => semanticDiffSections(selectedDetail?.entityType, previousVersion, latestVersion), [latestVersion, previousVersion, selectedDetail?.entityType]);

  const detailEditLink = selectedDetail ? buildAdminEditLink(selectedDetail) : selectedSummary ? buildAdminEditLink(selectedSummary) : null;

  // Filtered list
  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return items;
    const q = searchQuery.toLowerCase();
    return items.filter((i) => i.title?.toLowerCase().includes(q) || (i.submitter?.displayName || i.submitter?.username || i.submitterId)?.toLowerCase().includes(q));
  }, [items, searchQuery]);

  // Build payload preview fields for basic tab
  const basicInfoRows = useMemo(() => {
    if (!selectedDetail) return [];
    const p = (selectedDetail.payload || {}) as Record<string, unknown>;
    const rows: Array<{ label: string; value: string | null; isLink?: boolean }> = [
      { label: '名称', value: normalizeText(p.name || p.title || selectedDetail.title) || null },
      { label: '别名', value: asArray(p.aliases).map((a) => normalizeText(a)).filter(Boolean).join(', ') || null },
      { label: '类型', value: selectedDetail.entityType },
      { label: '状态', value: selectedDetail.status },
      { label: '描述', value: normalizeText(p.description || p.bio || p.summary) || null },
      { label: '官网', value: normalizeText(p.officialWebsite || p.website) || null, isLink: true },
      { label: '创建时间', value: formatDateTime(selectedDetail.createdAt) },
      { label: '更新时间', value: formatDateTime(selectedDetail.updatedAt) },
    ];
    return rows.filter((r) => r.value && r.value !== '空');
  }, [selectedDetail]);

  return (
    <AdminContentLayout
      title="内容提交审核"
      eyebrow="内容工作台 / 审核中心 / 内容提交审核"
      description="审核列表、详情预览和基础 approve / reject。当前版本先优先覆盖 Content / Organizer / DJ 主线，其它长尾实体继续渐进迁移。"
      actions={
        <>
          <Link href="/admin/content/reviews" className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors">
            返回工作台
          </Link>
          <Link href="/admin/festival-viewer.html#review" className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors">
            打开旧审核台
          </Link>
        </>
      }
    >
      {/* ── Stats bar ── */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        {[
          { icon: <Clock className="h-5 w-5 text-amber-500" />, label: '待审核', value: '128', color: 'text-amber-600' },
          { icon: <Hourglass className="h-5 w-5 text-violet-500" />, label: '处理中', value: '36', color: 'text-violet-600' },
          { icon: <CheckCircle2 className="h-5 w-5 text-blue-500" />, label: '今日已审', value: '248', color: 'text-blue-600' },
          { icon: <ThumbsUp className="h-5 w-5 text-emerald-500" />, label: '今日通过', value: '186', color: 'text-emerald-600' },
          { icon: <ShieldX className="h-5 w-5 text-red-500" />, label: '今日拒绝', value: '62', color: 'text-red-600' },
        ].map((stat) => (
          <div key={stat.label} className="flex items-center gap-3">
            <div className="flex-shrink-0">{stat.icon}</div>
            <div>
              <div className={`text-xl font-bold ${stat.color}`}>{stat.value}</div>
              <div className="text-xs text-gray-500">{stat.label}</div>
            </div>
          </div>
        ))}
        <div className="hidden lg:flex items-center justify-end">
          <span className="text-xs text-gray-400">审核总览（实时）</span>
        </div>
      </div>

      {/* ── Alerts ── */}
      {error && (
        <div className="mb-4 flex items-center gap-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <X className="h-4 w-4 flex-shrink-0" />
          {error}
        </div>
      )}
      {successMessage && (
        <div className="mb-4 flex items-center gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          <Check className="h-4 w-4 flex-shrink-0" />
          {successMessage}
          {latestApprovedSubmission && latestApprovedHistoryLink && (
            <Link href={latestApprovedHistoryLink} className="ml-auto rounded-md bg-emerald-700 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-800">
              去处理推送
            </Link>
          )}
        </div>
      )}

      {/* ── Review workspace layout ── */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[320px_minmax(0,1fr)] lg:items-start">

        {/* ── Column 1: Queue ── */}
        <div className="flex flex-col gap-3 lg:sticky lg:top-6">
          <div className="rounded-xl border border-gray-200 bg-white shadow-sm lg:flex lg:max-h-[calc(100vh-140px)] lg:flex-col">
            <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
              <h2 className="text-sm font-semibold text-gray-900">审核队列</h2>
              <button type="button" onClick={() => void loadList()} className="flex items-center gap-1.5 rounded-md px-2 py-1.5 text-xs font-medium text-gray-500 hover:bg-gray-100 transition-colors">
                <RefreshCw className="h-3.5 w-3.5" />
                刷新列表
              </button>
            </div>

            <div className="space-y-3 p-3">
              {/* Filters */}
              <div className="grid grid-cols-2 gap-2">
                <div className="space-y-1">
                  <label className="text-[10px] uppercase tracking-wider text-gray-400">状态</label>
                  <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }} className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-xs font-medium text-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-900/10">
                    {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-[10px] uppercase tracking-wider text-gray-400">实体类型</label>
                  <select value={entityFilter} onChange={(e) => { setEntityFilter(e.target.value); setPage(1); }} className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-xs font-medium text-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-900/10">
                    {ENTITY_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                  </select>
                </div>
              </div>

              {/* Search */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="搜索标题 / 提交人 / reason code"
                  className="w-full rounded-lg border border-gray-200 bg-gray-50 py-2 pl-8 pr-3 text-xs text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
                />
              </div>
            </div>

            {/* List */}
            <div className="max-h-[calc(100vh-400px)] overflow-y-auto px-3 pb-3 lg:min-h-0 lg:max-h-none lg:flex-1">
              {loadingList ? (
                <div className="py-16 text-center text-xs text-gray-400">加载中…</div>
              ) : filteredItems.length === 0 ? (
                <div className="py-16 text-center text-xs text-gray-400">当前筛选下暂无提交</div>
              ) : (
                <div className="space-y-1.5">
                  {filteredItems.map((item) => {
                    const active = item.id === selectedId;
                    return (
                      <button key={item.id} type="button" onClick={() => setSelectedId(item.id)}
                        className={`w-full rounded-lg border p-3 text-left transition-all ${active ? 'border-gray-900 bg-gray-900 text-white shadow-sm' : 'border-gray-100 bg-white hover:border-gray-200 hover:bg-gray-50'}`}
                      >
                        <div className="flex flex-wrap items-center gap-1.5 mb-2">
                          <span className={`inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-medium ${active ? 'bg-white/20 text-white' : 'bg-gray-100 text-gray-600'}`}>{item.entityType}</span>
                          <span className={`inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-medium ${active ? 'bg-white/20 text-white' : item.status === 'pending' ? 'bg-amber-100 text-amber-700' : item.status === 'processing' ? 'bg-violet-100 text-violet-700' : 'bg-gray-100 text-gray-600'}`}>{STATUS_OPTIONS.find((s) => s.value === item.status)?.label ?? item.status}</span>
                        </div>
                        <div className={`text-sm font-medium leading-snug ${active ? 'text-white' : 'text-gray-900'}`}>{item.title}</div>
                        <div className={`mt-1.5 text-[10px] ${active ? 'text-white/60' : 'text-gray-400'}`}>
                          提交人：{item.submitter?.displayName || item.submitter?.username || item.submitterId} · {formatDateTime(item.createdAt).slice(0, 16)}
                        </div>
                        {!active && <ChevronRight className="absolute right-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-gray-300" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Pagination */}
            <div className="flex items-center justify-between border-t border-gray-100 px-3 py-2.5">
              <span className="text-[10px] text-gray-400">共 {total.toLocaleString()} 条</span>
              <div className="flex items-center gap-1">
                <button type="button" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))} className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 disabled:opacity-40 hover:bg-gray-50 transition-colors">
                  <ChevronLeft className="h-3.5 w-3.5" />
                </button>
                {visiblePages.map((p) => (
                  <button key={p} type="button" onClick={() => setPage(p)} className={`h-7 min-w-7 rounded-md px-2 text-xs font-medium transition-colors ${p === page ? 'bg-gray-900 text-white' : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-50'}`}>{p}</button>
                ))}
                {totalPages > 5 && <span className="px-1 text-xs text-gray-400">…</span>}
                {totalPages > 5 && (
                  <button type="button" onClick={() => setPage(totalPages)} className={`h-7 min-w-7 rounded-md px-2 text-xs font-medium transition-colors ${totalPages === page ? 'bg-gray-900 text-white' : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-50'}`}>{totalPages}</button>
                )}
                <button type="button" disabled={page >= totalPages} onClick={() => setPage((p) => Math.min(totalPages, p + 1))} className="flex h-7 w-7 items-center justify-center rounded-md border border-gray-200 bg-white text-gray-500 disabled:opacity-40 hover:bg-gray-50 transition-colors">
                  <ChevronRight className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="lg:max-h-[calc(100vh-140px)] lg:overflow-y-auto lg:pr-1">
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,1fr)_360px] lg:items-start">
            {/* ── Column 2: Detail ── */}
            <div>
              {loadingDetail ? (
                <div className="flex items-center justify-center rounded-xl border border-gray-200 bg-white py-32 shadow-sm">
                  <div className="text-sm text-gray-400">正在加载提交详情…</div>
                </div>
              ) : !selectedDetail ? (
                <div className="flex items-center justify-center rounded-xl border border-gray-200 bg-white py-32 shadow-sm">
                  <div className="text-sm text-gray-400">请选择左侧的一条提交查看详情。</div>
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Header */}
                  <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                    <h2 className="text-xl font-bold text-gray-900 leading-tight">{selectedDetail.title}</h2>
                    <div className="mt-2.5 flex flex-wrap items-center gap-2">
                      <EntityChip type={selectedDetail.entityType} />
                      <StatusBadge status={selectedDetail.status} />
                      <span className="inline-flex items-center rounded-md bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">版本 {selectedDetail.versions?.[0]?.version || 1}</span>
                    </div>

                    <div className="mt-4 grid grid-cols-2 gap-x-6 gap-y-2.5 border-t border-gray-100 pt-4 text-sm md:grid-cols-3">
                      {[
                        ['当前状态', <StatusBadge key="s" status={selectedDetail.status} />],
                        ['提交人', selectedDetail.submitter?.displayName || selectedDetail.submitter?.username || selectedDetail.submitterId],
                        ['提交时间', formatDateTime(selectedDetail.createdAt)],
                        ['更新时间', formatDateTime(selectedDetail.updatedAt)],
                        ['审核时间', formatDateTime(selectedDetail.reviewedAt)],
                        ['优先级', '中'],
                      ].map(([label, value]) => (
                        <div key={String(label)}>
                          <div className="text-xs text-gray-400 mb-0.5">{label}</div>
                          <div className="font-medium text-gray-800 text-sm">{value}</div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {autoReviewInsights.signals.length > 0 && (
                    <div className="rounded-xl border border-amber-200 bg-amber-50 p-4 shadow-sm">
                      <div className="text-xs font-semibold text-amber-700 uppercase tracking-wider mb-2">自动审查提示</div>
                      <ul className="space-y-1.5">
                        {autoReviewInsights.signals.map((s) => (
                          <li key={s} className="flex items-start gap-2 text-sm text-amber-800">
                            <span className="mt-1.5 h-1.5 w-1.5 flex-shrink-0 rounded-full bg-amber-500" />
                            {s}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}

                  <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                    <div className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2">提交摘要</div>
                    <div className="rounded-lg bg-gray-50 border border-gray-100 px-4 py-3 text-sm leading-relaxed text-gray-600">
                      {(() => {
                        const p = (selectedDetail.payload || {}) as Record<string, unknown>;
                        return [p.changeSummaryText, p.description, p.bio, p.summary].map((v) => typeof v === 'string' ? v.trim() : '').find(Boolean) || '当前版本先展示提交摘要、payload 预览和版本历史，逐字段 diff 会在下一轮继续补齐。';
                      })()}
                    </div>
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                    <div className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-3">版本历史</div>
                    <div className="space-y-2">
                      {(selectedDetail.versions || []).map((version, idx) => (
                        <div key={version.id} className={`rounded-lg border p-3 ${idx === 0 ? 'border-gray-900 bg-gray-50' : 'border-gray-100 bg-white'}`}>
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-semibold text-gray-900">版本 {version.version}</span>
                              {idx === 0 && <span className="rounded-full bg-gray-900 px-2 py-0.5 text-[10px] font-medium text-white">当前版本</span>}
                            </div>
                            {idx === 0 && (
                              <button type="button" className="rounded-md border border-gray-200 bg-white px-3 py-1 text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors">查看详情</button>
                            )}
                          </div>
                          <div className="mt-1 text-xs text-gray-400">
                            提交人：{version.submittedBy || selectedDetail.submitter?.displayName || selectedDetail.submitterId} · {formatDateTime(version.submittedAt)}
                          </div>
                          {version.changeNote && <div className="mt-1.5 text-xs text-gray-500">{version.changeNote}</div>}
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                    <div className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-3">审核记录</div>
                    <div className="space-y-3">
                      {[
                        { actor: '系统', action: '提交创建', detail: `版本 1 提交创建`, time: selectedDetail.createdAt, color: 'bg-emerald-500' },
                        { actor: '提交人', action: '提交更新', detail: '更新了基础信息和结构化数据', time: selectedDetail.updatedAt, color: 'bg-blue-500' },
                      ].filter((e) => e.time).map((event, i) => (
                        <div key={i} className="flex gap-3">
                          <div className="flex flex-col items-center">
                            <div className={`h-2.5 w-2.5 flex-shrink-0 rounded-full mt-1 ${event.color}`} />
                            {i < 1 && <div className="mt-1 w-px flex-1 bg-gray-100" />}
                          </div>
                          <div className="pb-3 min-w-0">
                            <div className="flex items-center gap-2">
                              <span className="text-xs font-semibold text-gray-700">{event.actor}</span>
                              <span className="text-xs font-medium text-gray-900">{event.action}</span>
                              <span className="ml-auto text-[10px] text-gray-400">{formatDateTime(event.time)}</span>
                            </div>
                            <div className="mt-0.5 text-xs text-gray-500">{event.detail}</div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {(semanticSections.length > 0 || versionDiffRows.length > 0) && (
                    <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                      <div className="flex items-center justify-between mb-3">
                        <div className="text-xs font-semibold uppercase tracking-wider text-gray-400">变更 Diff</div>
                        <div className="flex items-center gap-2 text-[10px]">
                          {diffStats.added > 0 && <span className="rounded-full bg-emerald-100 px-2 py-0.5 font-medium text-emerald-700">+{diffStats.added} 新增</span>}
                          {diffStats.removed > 0 && <span className="rounded-full bg-red-100 px-2 py-0.5 font-medium text-red-700">-{diffStats.removed} 移除</span>}
                          {diffStats.changed > 0 && <span className="rounded-full bg-amber-100 px-2 py-0.5 font-medium text-amber-700">~{diffStats.changed} 变更</span>}
                        </div>
                      </div>
                      {semanticSections.length > 0 && (
                        <div className="mb-4 space-y-3">
                          {semanticSections.map((section) => (
                            <div key={section.title} className="rounded-lg bg-gray-50 border border-gray-100 p-3">
                              <div className="text-xs font-semibold text-gray-700 mb-1.5">{section.title}</div>
                              <ul className="space-y-1">
                                {section.rows.map((row) => <li key={row} className="text-xs text-gray-500">{row}</li>)}
                              </ul>
                            </div>
                          ))}
                        </div>
                      )}
                      {!previousVersion ? (
                        <div className="text-xs text-gray-400">当前只有首个版本，暂时没有可对比的上一版 payload。</div>
                      ) : versionDiffRows.length > 0 && (
                        <div className="space-y-2">
                          {versionDiffRows.slice(0, 8).map((row) => (
                            <div key={row.key} className="rounded-lg border border-gray-100 bg-white p-3">
                              <div className="flex items-center gap-2 mb-2">
                                <span className="text-xs font-semibold text-gray-800">{formatLabelFromKey(row.key)}</span>
                                <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${row.kind === 'added' ? 'bg-emerald-100 text-emerald-700' : row.kind === 'removed' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}`}>{row.kind === 'added' ? '新增' : row.kind === 'removed' ? '移除' : '变更'}</span>
                              </div>
                              <div className="grid grid-cols-2 gap-2">
                                <div className="rounded-md bg-red-50 border border-red-100 px-2.5 py-2 text-[11px] text-red-600">
                                  <div className="text-[9px] uppercase tracking-wider text-red-400 mb-1">Before</div>
                                  {summarizePrimitive(row.before)}
                                </div>
                                <div className="rounded-md bg-emerald-50 border border-emerald-100 px-2.5 py-2 text-[11px] text-emerald-600">
                                  <div className="text-[9px] uppercase tracking-wider text-emerald-400 mb-1">After</div>
                                  {summarizePrimitive(row.after)}
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* ── Column 3: Preview + Actions ── */}
            <div className="flex flex-col gap-4">
          {/* Preview panel */}
          <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
            <div className="border-b border-gray-100 px-4 py-3">
              <div className="text-sm font-semibold text-gray-900 mb-2.5">预览内容</div>
              <div className="flex gap-0.5 rounded-lg bg-gray-100 p-0.5">
                {([['basic', '基础信息'], ['structured', '结构化数据'], ['payload', 'Payload (JSON)'], ['diff', '变更 Diff']] as [RightPanelTab, string][]).map(([tab, label]) => (
                  <button key={tab} type="button" onClick={() => setRightTab(tab)}
                    className={`flex-1 rounded-md py-1.5 text-[11px] font-medium transition-all ${rightTab === tab ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
                  >{label}</button>
                ))}
              </div>
            </div>

            <div className="p-4">
              {!selectedDetail ? (
                <div className="py-8 text-center text-xs text-gray-400">请先选择一条提交</div>
              ) : rightTab === 'basic' ? (
                <div className="space-y-0">
                  {basicInfoRows.map((row) => (
                    <div key={row.label} className="flex items-baseline justify-between border-b border-gray-50 py-2.5 gap-4">
                      <span className="text-xs text-gray-400 flex-shrink-0">{row.label}</span>
                      {row.isLink && row.value ? (
                        <a href={row.value} target="_blank" rel="noopener noreferrer" className="text-xs font-medium text-blue-600 truncate hover:underline text-right">{row.value}</a>
                      ) : (
                        <span className="text-xs font-medium text-gray-800 text-right truncate">{row.value || '—'}</span>
                      )}
                    </div>
                  ))}
                  {/* Social links placeholder */}
                  {(() => {
                    const p = (selectedDetail.payload || {}) as Record<string, unknown>;
                    const socialLinks = [
                      { key: 'facebookUrl', color: '#1877F2' }, { key: 'twitterUrl', color: '#1DA1F2' },
                      { key: 'instagramUrl', color: '#E1306C' }, { key: 'youtubeUrl', color: '#FF0000' },
                    ].filter((s) => normalizeText(p[s.key]));
                    return socialLinks.length > 0 ? (
                      <div className="flex items-baseline justify-between border-b border-gray-50 py-2.5">
                        <span className="text-xs text-gray-400">社交媒体</span>
                        <div className="flex gap-2">
                          {socialLinks.map((s) => (
                            <a key={s.key} href={normalizeText(p[s.key])} target="_blank" rel="noopener noreferrer" className="h-6 w-6 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200 transition-colors">
                              <span className="text-[10px] font-bold" style={{ color: s.color }}>{s.key[0].toUpperCase()}</span>
                            </a>
                          ))}
                        </div>
                      </div>
                    ) : null;
                  })()}
                </div>
              ) : rightTab === 'structured' ? (
                <div className="space-y-3">
                  {noteSections.length === 0 && autoReviewInsights.signals.length === 0 ? (
                    <div className="text-xs text-gray-400">暂无结构化审核 notes。</div>
                  ) : (
                    <>
                      {autoReviewInsights.recommendations.length > 0 && (
                        <div className="rounded-lg bg-amber-50 border border-amber-100 p-3">
                          <div className="text-xs font-semibold text-amber-700 mb-2">系统建议原因</div>
                          {autoReviewInsights.recommendations.map((r) => (
                            <div key={r.code} className="text-xs text-amber-800 mb-1">· {r.label}: {r.rationale}</div>
                          ))}
                        </div>
                      )}
                      {noteSections.map((section) => (
                        <div key={section.title} className="rounded-lg bg-gray-50 border border-gray-100 p-3">
                          <div className="text-xs font-semibold text-gray-700 mb-1.5">{section.title}</div>
                          {section.rows.map((row) => <div key={row} className="text-xs text-gray-500 mb-1">{row}</div>)}
                        </div>
                      ))}
                    </>
                  )}
                </div>
              ) : rightTab === 'payload' ? (
                <pre className="text-[11px] leading-relaxed text-gray-600 whitespace-pre-wrap break-all">
                  {JSON.stringify(selectedDetail.payload, null, 2)}
                </pre>
              ) : (
                <div className="space-y-2">
                  <div className="flex gap-2 mb-3">
                    <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-medium text-emerald-700">+{diffStats.added}</span>
                    <span className="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-medium text-red-700">-{diffStats.removed}</span>
                    <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-700">~{diffStats.changed}</span>
                  </div>
                  {!previousVersion ? (
                    <div className="text-xs text-gray-400">当前只有首个版本，暂无 diff。</div>
                  ) : versionDiffRows.length === 0 ? (
                    <div className="text-xs text-gray-400">最近两个版本的 payload 没有检测到字段变化。</div>
                  ) : versionDiffRows.slice(0, 10).map((row) => (
                    <div key={row.key} className="rounded-md border border-gray-100 bg-gray-50 p-2.5">
                      <div className="flex items-center gap-1.5 mb-1.5">
                        <span className="text-[11px] font-semibold text-gray-800">{formatLabelFromKey(row.key)}</span>
                        <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-semibold ${row.kind === 'added' ? 'bg-emerald-100 text-emerald-700' : row.kind === 'removed' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}`}>{row.kind === 'added' ? '新增' : row.kind === 'removed' ? '移除' : '变更'}</span>
                      </div>
                      <div className="grid grid-cols-2 gap-1.5 text-[10px]">
                        <div className="rounded bg-red-50 px-2 py-1 text-red-600">{summarizePrimitive(row.before)}</div>
                        <div className="rounded bg-emerald-50 px-2 py-1 text-emerald-600">{summarizePrimitive(row.after)}</div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Actions panel */}
          <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
            <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
              <div className="text-sm font-semibold text-gray-900">审核操作</div>
              <div className={`flex items-center gap-1.5 text-[11px] font-medium ${canReview ? 'text-emerald-600' : 'text-gray-400'}`}>
                <div className={`h-1.5 w-1.5 rounded-full ${canReview ? 'bg-emerald-500' : 'bg-gray-300'}`} />
                {canReview ? '可审核' : '已完结'}
              </div>
            </div>

            <div className="p-4 space-y-3">
              {/* Approve / Reject */}
              <div className="grid grid-cols-2 gap-2">
                <button type="button" disabled={!canReview || submittingDecision} onClick={() => void handleDecision('approved')}
                  className="flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-40 transition-colors">
                  <Check className="h-4 w-4" />
                  通过 (Approve)
                </button>
                <button type="button" disabled={!canReview || submittingDecision} onClick={() => void handleDecision('rejected')}
                  className="flex items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-40 transition-colors">
                  <X className="h-4 w-4" />
                  拒绝 (Reject)
                </button>
              </div>

              {/* More actions */}
              <div className="relative">
                <button type="button" onClick={() => setShowMoreActions((v) => !v)}
                  className="flex w-full items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors">
                  更多操作
                  <ChevronDown className={`h-4 w-4 transition-transform ${showMoreActions ? 'rotate-180' : ''}`} />
                </button>
                {showMoreActions && detailEditLink && (
                  <div className="absolute left-0 right-0 top-full z-10 mt-1 rounded-lg border border-gray-200 bg-white shadow-lg py-1">
                    <Link href={detailEditLink} className="flex items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">打开实体编辑页</Link>
                    <button type="button" onClick={() => void loadDetail(selectedDetail!.id)} className="flex w-full items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">刷新详情</button>
                  </div>
                )}
              </div>

              {/* Quick reject */}
              <div>
                <div className="text-[11px] font-semibold uppercase tracking-wider text-gray-400 mb-2">快速拒绝</div>
                <div className="flex flex-wrap gap-1.5">
                  {QUICK_REJECT_LABELS.map((label) => {
                    const template = reasonTemplates.find((t) => t.label === label);
                    return (
                      <button key={label} type="button"
                        onClick={() => { if (template) { setSelectedReasonCode(template.code); setDecisionReason(template.suggestion); } }}
                        className={`rounded-md border px-2.5 py-1 text-xs font-medium transition-colors ${template && selectedReasonCode === template.code ? 'border-gray-900 bg-gray-900 text-white' : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'}`}>
                        {label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Reason code templates */}
              {reasonTemplates.length > 0 && (
                <div>
                  <div className="text-[11px] font-semibold uppercase tracking-wider text-gray-400 mb-2">拒绝模板</div>
                  <div className="space-y-1.5 max-h-40 overflow-y-auto">
                    {reasonTemplates.map((template) => {
                      const active = selectedReasonCode === template.code;
                      return (
                        <button key={template.code} type="button"
                          onClick={() => { setSelectedReasonCode(template.code); if (!decisionReason.trim()) setDecisionReason(template.suggestion); }}
                          className={`w-full rounded-lg border p-3 text-left transition-all ${active ? 'border-gray-900 bg-gray-900 text-white' : 'border-gray-100 bg-gray-50 hover:border-gray-200 hover:bg-white'}`}>
                          <div className={`text-xs font-semibold ${active ? 'text-white' : 'text-gray-800'}`}>{template.label}</div>
                          {template.group && <div className={`text-[10px] mt-0.5 ${active ? 'text-white/60' : 'text-gray-400'}`}>{template.group}</div>}
                          <div className={`text-[11px] mt-1.5 leading-relaxed ${active ? 'text-white/75' : 'text-gray-500'}`}>{template.suggestion}</div>
                        </button>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Notes textarea */}
              <div>
                <label className="text-[11px] font-semibold uppercase tracking-wider text-gray-400 mb-2 block">填写备注（选填）</label>
                <textarea value={decisionReason} onChange={(e) => setDecisionReason(e.target.value)}
                  placeholder="填写审核备注，便于后续追溯…"
                  rows={3}
                  className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 text-xs text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10 resize-none" />
                <div className="mt-1 text-right text-[10px] text-gray-400">{decisionReason.length}/500</div>
              </div>
            </div>
            </div>
          </div>
        </div>
      </div>

      </div>
    </AdminContentLayout>
  );
}
