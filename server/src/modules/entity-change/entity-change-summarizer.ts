import type {
  EntityChange,
  EntityChangeResult,
  EntityChangeSummary,
  PublicEntityChange,
} from './entity-change.types';

const entityLabelZh = (entityType: EntityChangeResult['entityType']): string => {
  if (entityType === 'event') return '活动';
  if (entityType === 'dj') return 'DJ';
  if (entityType === 'djSet') return 'DJ Set';
  if (entityType === 'news') return '资讯';
  if (entityType === 'post') return '帖子';
  if (entityType === 'label') return '厂牌';
  return '主办方';
};

const entityLabelEn = (entityType: EntityChangeResult['entityType']): string => {
  if (entityType === 'event') return 'Event';
  if (entityType === 'dj') return 'DJ';
  if (entityType === 'djSet') return 'DJ Set';
  if (entityType === 'news') return 'News';
  if (entityType === 'post') return 'Post';
  if (entityType === 'label') return 'Label';
  return 'Brand';
};

const entityLabelJa = (entityType: EntityChangeResult['entityType']): string => {
  if (entityType === 'event') return 'イベント';
  if (entityType === 'dj') return 'DJ';
  if (entityType === 'djSet') return 'DJ Set';
  if (entityType === 'news') return 'ニュース';
  if (entityType === 'post') return '投稿';
  if (entityType === 'label') return 'レーベル';
  return 'ブランド';
};

const phraseZh = (change: Pick<EntityChange, 'kind' | 'pathLabelZh' | 'beforeDisplayZh' | 'afterDisplayZh'>): string => {
  const before = change.beforeDisplayZh ?? '未设置';
  const after = change.afterDisplayZh ?? '未设置';
  if (change.kind === 'added') return `新增${change.pathLabelZh}「${after}」`;
  if (change.kind === 'removed') return `移除${change.pathLabelZh}「${before}」`;
  if (change.kind === 'reordered') return `${change.pathLabelZh}顺序已调整`;
  return `${change.pathLabelZh}由「${before}」改为「${after}」`;
};

const phraseEn = (change: Pick<EntityChange, 'kind' | 'pathLabelEn' | 'beforeDisplayEn' | 'afterDisplayEn'>): string => {
  const before = change.beforeDisplayEn ?? 'not set';
  const after = change.afterDisplayEn ?? 'not set';
  if (change.kind === 'added') return `added ${change.pathLabelEn}: "${after}"`;
  if (change.kind === 'removed') return `removed ${change.pathLabelEn}: "${before}"`;
  if (change.kind === 'reordered') return `reordered ${change.pathLabelEn}`;
  return `changed ${change.pathLabelEn} from "${before}" to "${after}"`;
};

const phraseJa = (change: Pick<EntityChange, 'kind' | 'pathLabelJa' | 'beforeDisplayJa' | 'afterDisplayJa'>): string => {
  const before = change.beforeDisplayJa ?? '未設定';
  const after = change.afterDisplayJa ?? '未設定';
  if (change.kind === 'added') return `${change.pathLabelJa}「${after}」を追加`;
  if (change.kind === 'removed') return `${change.pathLabelJa}「${before}」を削除`;
  if (change.kind === 'reordered') return `${change.pathLabelJa}の順序を変更`;
  return `${change.pathLabelJa}を「${before}」から「${after}」に変更`;
};

const publicPhraseZh = (change: PublicEntityChange): string => {
  const before = change.before ?? '未设置';
  const after = change.after ?? '未设置';
  if (change.kind === 'added') return `新增${change.label}「${after}」`;
  if (change.kind === 'removed') return `移除${change.label}「${before}」`;
  if (change.kind === 'reordered') return `${change.label}顺序已调整`;
  return `${change.label}由「${before}」改为「${after}」`;
};

const publicPhraseJa = (change: PublicEntityChange): string => {
  const before = change.beforeJa ?? '未設定';
  const after = change.afterJa ?? '未設定';
  if (change.kind === 'added') return `${change.labelJa}「${after}」を追加`;
  if (change.kind === 'removed') return `${change.labelJa}「${before}」を削除`;
  if (change.kind === 'reordered') return `${change.labelJa}の順序を変更`;
  return `${change.labelJa}を「${before}」から「${after}」に変更`;
};

const summarizeZh = (input: {
  entityType: EntityChangeResult['entityType'];
  displayName: string;
  changes: string[];
  total: number;
}): string | null => {
  if (input.total === 0 || input.changes.length === 0) return null;
  const label = entityLabelZh(input.entityType);
  const visible = input.changes.slice(0, 3);
  const suffix = input.total > visible.length ? `等 ${input.total} 处` : '';
  const body = [...visible, suffix].filter(Boolean).join('；');
  return `${label}「${input.displayName}」更新了：${body}。`;
};

const summarizeEn = (input: {
  entityType: EntityChangeResult['entityType'];
  displayName: string;
  changes: string[];
  total: number;
}): string | null => {
  if (input.total === 0 || input.changes.length === 0) return null;
  const label = entityLabelEn(input.entityType);
  const visible = input.changes.slice(0, 3);
  const suffix = input.total > visible.length ? `and ${input.total - visible.length} more` : '';
  const body = [...visible, suffix].filter(Boolean).join('; ');
  return `${label} "${input.displayName}" was updated: ${body}.`;
};

const summarizeJa = (input: {
  entityType: EntityChangeResult['entityType'];
  displayName: string;
  changes: string[];
  total: number;
}): string | null => {
  if (input.total === 0 || input.changes.length === 0) return null;
  const label = entityLabelJa(input.entityType);
  const visible = input.changes.slice(0, 3);
  const suffix = input.total > visible.length ? `ほか ${input.total - visible.length} 件` : '';
  const body = [...visible, suffix].filter(Boolean).join('；');
  return `${label}「${input.displayName}」が更新されました：${body}。`;
};

export const buildEntityChangeSummary = (input: {
  entityType: EntityChangeResult['entityType'];
  displayName: string;
  changes: EntityChange[];
  publicChanges: PublicEntityChange[];
}): EntityChangeSummary => {
  const operatorChanges = input.changes.filter((change) => change.audience === 'operator' || change.audience === 'public');
  const privateZh = input.changes.map(phraseZh);
  const privateEn = input.changes.map(phraseEn);
  const privateJa = input.changes.map(phraseJa);
  const operatorZh = operatorChanges.map(phraseZh);
  const operatorEn = operatorChanges.map(phraseEn);
  const operatorJa = operatorChanges.map(phraseJa);
  const publicZh = input.publicChanges.map(publicPhraseZh);
  const publicJa = input.publicChanges.map(publicPhraseJa);
  const publicEn = input.publicChanges.map((change) => {
    const before = change.beforeEn ?? 'not set';
    const after = change.afterEn ?? 'not set';
    if (change.kind === 'added') return `added ${change.labelEn}: "${after}"`;
    if (change.kind === 'removed') return `removed ${change.labelEn}: "${before}"`;
    if (change.kind === 'reordered') return `reordered ${change.labelEn}`;
    return `changed ${change.labelEn} from "${before}" to "${after}"`;
  });

  return {
    privateSummaryZh: summarizeZh({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: privateZh,
      total: input.changes.length,
    }),
    operatorSummaryZh: summarizeZh({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: operatorZh,
      total: operatorChanges.length,
    }),
    publicSummaryZh: summarizeZh({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: publicZh,
      total: input.publicChanges.length,
    }),
    privateSummaryEn: summarizeEn({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: privateEn,
      total: input.changes.length,
    }),
    operatorSummaryEn: summarizeEn({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: operatorEn,
      total: operatorChanges.length,
    }),
    publicSummaryEn: summarizeEn({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: publicEn,
      total: input.publicChanges.length,
    }),
    privateSummaryJa: summarizeJa({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: privateJa,
      total: input.changes.length,
    }),
    operatorSummaryJa: summarizeJa({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: operatorJa,
      total: operatorChanges.length,
    }),
    publicSummaryJa: summarizeJa({
      entityType: input.entityType,
      displayName: input.displayName,
      changes: publicJa,
      total: input.publicChanges.length,
    }),
  };
};
