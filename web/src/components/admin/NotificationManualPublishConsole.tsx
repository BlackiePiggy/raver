'use client';

import { useMemo, useState } from 'react';
import AdminToast, { type AdminToastTone } from '@/components/admin/AdminToast';
import EntityBindingField from '@/components/admin/EntityBindingField';
import type { EntityBindingKind, EntityBindingValue } from '@/components/admin/EntityBindingSearch';
import {
  notificationCenterAdminApi,
  type NotificationManualAudienceEntityInput,
  type NotificationManualAudienceSummary,
  type NotificationManualAudienceType,
  type NotificationManualExecutionResult,
  type NotificationManualPreview,
  type NotificationManualRelatedEntityType,
} from '@/lib/api/notification-center-admin';

type ToastState = {
  message: string;
  tone: AdminToastTone;
} | null;

type AudienceDraft = {
  type: NotificationManualAudienceType;
  title: string;
  kind: EntityBindingKind;
  items: EntityBindingValue[];
  emptyLabel: string;
};

const RELATED_ENTITY_OPTIONS: Array<{ value: NotificationManualRelatedEntityType; label: string; kind: EntityBindingKind }> = [
  { value: 'news', label: '资讯', kind: 'news' },
  { value: 'event', label: '活动', kind: 'event' },
  { value: 'dj', label: 'DJ', kind: 'dj' },
  { value: 'festival', label: '主办方', kind: 'festival' },
  { value: 'label', label: '厂牌', kind: 'brand' },
];

const createAudienceDrafts = (): AudienceDraft[] => [
  {
    type: 'direct_users',
    title: '直发用户',
    kind: 'user',
    items: [],
    emptyLabel: '选择具体用户，适合定向触达。',
  },
  {
    type: 'followed_dj',
    title: '关注 DJ 的用户',
    kind: 'dj',
    items: [],
    emptyLabel: '选择一个或多个 DJ，系统会匹配关注这些 DJ 的用户。',
  },
  {
    type: 'followed_brand',
    title: '关注品牌/主办方的用户',
    kind: 'brand',
    items: [],
    emptyLabel: '选择主办方或厂牌，系统会匹配关注这些对象的用户。',
  },
  {
    type: 'favorited_event',
    title: '收藏活动的用户',
    kind: 'event',
    items: [],
    emptyLabel: '选择活动，系统会匹配收藏这些活动的用户。',
  },
];

const toAudiencePayload = (drafts: AudienceDraft[]) =>
  drafts
    .filter((draft) => draft.items.length > 0)
    .map((draft) => ({
      type: draft.type,
      entities: draft.items.map<NotificationManualAudienceEntityInput>((item) => ({
        id: item.id,
        name: item.name,
        entityType: item.entityType ?? null,
      })),
    }));

const mergeSingle = (current: EntityBindingValue[], value: EntityBindingValue): EntityBindingValue[] => [value];

const appendUnique = (current: EntityBindingValue[], value: EntityBindingValue): EntityBindingValue[] => {
  if (current.some((item) => item.id === value.id)) return current;
  return [...current, value];
};

const removeById = (current: EntityBindingValue[], id: string): EntityBindingValue[] =>
  current.filter((item) => item.id !== id);

const renderAudienceSummary = (summary: NotificationManualAudienceSummary) => (
  <div key={summary.type} className="rounded-[18px] border border-[#d8e5dc] bg-white px-4 py-4">
    <div className="text-sm font-semibold text-[#071110]">{summary.label}</div>
    <div className="mt-2 text-xs leading-6 text-[#45604f]">
      {summary.entityCount} 个对象 / {summary.targetUserCount} 次投递 / {summary.uniqueTargetUserCount} 位去重用户
    </div>
    <div className="mt-3 flex flex-wrap gap-2">
      {summary.entities.map((entity) => (
        <span
          key={`${summary.type}:${entity.entityType ?? 'entity'}:${entity.id}`}
          className="rounded-full border border-[#dde5e1] px-3 py-1 text-xs text-[#42514c]"
        >
          {entity.name} / {entity.targetUserCount}
        </span>
      ))}
    </div>
  </div>
);

export default function NotificationManualPublishConsole() {
  const [relatedEntityType, setRelatedEntityType] = useState<NotificationManualRelatedEntityType>('news');
  const [relatedEntity, setRelatedEntity] = useState<EntityBindingValue | null>(null);
  const [headline, setHeadline] = useState('');
  const [summary, setSummary] = useState('');
  const [deeplink, setDeeplink] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [audiences, setAudiences] = useState<AudienceDraft[]>(() => createAudienceDrafts());
  const [preview, setPreview] = useState<NotificationManualPreview | null>(null);
  const [result, setResult] = useState<NotificationManualExecutionResult | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [sendInApp, setSendInApp] = useState(true);
  const [sendApns, setSendApns] = useState(true);
  const [toast, setToast] = useState<ToastState>(null);

  const relatedKind = useMemo(
    () => RELATED_ENTITY_OPTIONS.find((item) => item.value === relatedEntityType)?.kind ?? 'news',
    [relatedEntityType]
  );

  const payload = useMemo(
    () => ({
      content: {
        headline: headline.trim() || undefined,
        summary: summary.trim() || undefined,
        deeplink: deeplink.trim() || undefined,
        imageUrl: imageUrl.trim() || undefined,
        relatedEntity: relatedEntity
          ? {
              type: relatedEntityType,
              id: relatedEntity.id,
            }
          : undefined,
      },
      audiences: toAudiencePayload(audiences),
    }),
    [audiences, deeplink, headline, imageUrl, relatedEntity, relatedEntityType, summary]
  );

  const availableChannels = useMemo(() => {
    const channels: Array<'in_app' | 'apns'> = [];
    if (sendInApp) channels.push('in_app');
    if (sendApns) channels.push('apns');
    return channels;
  }, [sendApns, sendInApp]);

  const handleAudienceAdd = (type: NotificationManualAudienceType, value: EntityBindingValue) => {
    setAudiences((current) =>
      current.map((item) =>
        item.type === type
          ? {
              ...item,
              items: appendUnique(item.items, value),
            }
          : item
      )
    );
  };

  const handleAudienceRemove = (type: NotificationManualAudienceType, value: EntityBindingValue) => {
    setAudiences((current) =>
      current.map((item) =>
        item.type === type
          ? {
              ...item,
              items: removeById(item.items, value.id),
            }
          : item
      )
    );
  };

  const handlePreview = async () => {
    if (payload.audiences.length === 0) {
      setToast({ message: '请至少选择一组受众对象', tone: 'warning' });
      return;
    }

    try {
      setLoadingPreview(true);
      const nextPreview = await notificationCenterAdminApi.previewManualPublish(payload);
      setPreview(nextPreview);
      setResult(null);
      setToast({ message: '预览已更新', tone: 'success' });
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : '预览失败', tone: 'error' });
    } finally {
      setLoadingPreview(false);
    }
  };

  const handlePublish = async () => {
    if (payload.audiences.length === 0) {
      setToast({ message: '请至少选择一组受众对象', tone: 'warning' });
      return;
    }
    if (availableChannels.length === 0) {
      setToast({ message: '请至少选择一种发送渠道', tone: 'warning' });
      return;
    }

    try {
      setPublishing(true);
      const nextResult = await notificationCenterAdminApi.publishManual({
        ...payload,
        channels: availableChannels,
      });
      setResult(nextResult);
      setPreview(null);
      setToast({ message: '手动通知已发送', tone: 'success' });
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : '发送失败', tone: 'error' });
    } finally {
      setPublishing(false);
    }
  };

  return (
    <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
      <AdminToast
        message={toast?.message || null}
        tone={toast?.tone || 'neutral'}
        visible={Boolean(toast?.message)}
        onClose={() => setToast(null)}
      />

      <div className="admin-studio-label">Manual APNS / Related Content Publish</div>
      <h2 className="mt-2 text-xl font-semibold text-[#071110]">手动 APNS / 关联内容发布台</h2>
      <p className="mt-2 max-w-3xl text-sm leading-6 text-[#5b6763]">
        这里用于正式运营发布。先选择一个关联内容对象作为基底，再决定是否覆盖标题、摘要、deeplink 和图片，然后选择受众对象并预览触达范围。
      </p>

      <div className="mt-5 grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="space-y-5">
          <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
            <div className="text-sm font-semibold text-[#071110]">关联内容对象</div>
            <div className="mt-3">
              <select
                value={relatedEntityType}
                onChange={(event) => {
                  setRelatedEntityType(event.target.value as NotificationManualRelatedEntityType);
                  setRelatedEntity(null);
                }}
                className="w-full rounded-[16px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
              >
                {RELATED_ENTITY_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="mt-4">
              <EntityBindingField
                kind={relatedKind}
                mode="single"
                title="关联内容"
                items={relatedEntity ? [relatedEntity] : []}
                emptyLabel="先搜索并绑定一个关联内容对象，之后可以继续手动覆盖标题与文案。"
                onAdd={(value) => setRelatedEntity(mergeSingle([], value)[0] ?? null)}
                onRemove={() => setRelatedEntity(null)}
              />
            </div>
          </div>

          <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
            <div className="text-sm font-semibold text-[#071110]">发送内容</div>
            <div className="mt-4 grid gap-4">
              <label className="text-sm text-[#5b6763]">
                标题
                <input
                  value={headline}
                  onChange={(event) => setHeadline(event.target.value)}
                  className="mt-2 w-full rounded-[16px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                  placeholder="如果不填，会优先使用关联对象的标题"
                />
              </label>
              <label className="text-sm text-[#5b6763]">
                摘要
                <textarea
                  value={summary}
                  onChange={(event) => setSummary(event.target.value)}
                  className="mt-2 h-28 w-full rounded-[16px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                  placeholder="如果不填，会优先使用关联对象的摘要"
                />
              </label>
              <label className="text-sm text-[#5b6763]">
                Deeplink
                <input
                  value={deeplink}
                  onChange={(event) => setDeeplink(event.target.value)}
                  className="mt-2 w-full rounded-[16px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                  placeholder="如果不填，会优先使用关联对象的 deeplink"
                />
              </label>
              <label className="text-sm text-[#5b6763]">
                图片 URL
                <input
                  value={imageUrl}
                  onChange={(event) => setImageUrl(event.target.value)}
                  className="mt-2 w-full rounded-[16px] border border-[#d9e1de] bg-white px-4 py-3 text-sm text-[#071110]"
                  placeholder="如果不填，会优先使用关联对象的图片"
                />
              </label>
            </div>
          </div>
        </div>

        <div className="space-y-5">
          <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
            <div className="text-sm font-semibold text-[#071110]">受众对象</div>
            <div className="mt-4 space-y-4">
              {audiences.map((audience) => (
                <EntityBindingField
                  key={audience.type}
                  kind={audience.kind}
                  mode="multiple"
                  title={audience.title}
                  items={audience.items}
                  emptyLabel={audience.emptyLabel}
                  onAdd={(value) => handleAudienceAdd(audience.type, value)}
                  onRemove={(value) => handleAudienceRemove(audience.type, value)}
                />
              ))}
            </div>
          </div>

          <div className="rounded-[24px] border border-[#edf1ef] bg-[#fbfcfb] p-4">
            <div className="text-sm font-semibold text-[#071110]">发送渠道</div>
            <div className="mt-3 space-y-3">
              <label className="flex items-center justify-between rounded-[16px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                <span>站内通知</span>
                <input type="checkbox" checked={sendInApp} onChange={(event) => setSendInApp(event.target.checked)} />
              </label>
              <label className="flex items-center justify-between rounded-[16px] border border-[#e7ece8] bg-white px-4 py-3 text-sm text-[#071110]">
                <span>APNS 推送</span>
                <input type="checkbox" checked={sendApns} onChange={(event) => setSendApns(event.target.checked)} />
              </label>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => void handlePreview()}
                disabled={loadingPreview}
                className="rounded-full border border-[#d9e1de] bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:opacity-45"
              >
                {loadingPreview ? '预览中...' : '预览受众'}
              </button>
              <button
                type="button"
                onClick={() => void handlePublish()}
                disabled={publishing}
                className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
              >
                {publishing ? '发送中...' : '发送通知'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {preview ? (
        <div className="mt-5 rounded-[24px] border border-[#dbe6dd] bg-[#f6fbf7] p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-[#44614f]">Preview</div>
          <div className="mt-3 grid gap-4 md:grid-cols-3">
            <div className="rounded-[18px] border border-[#d8e5dc] bg-white px-4 py-4">
              <div className="text-sm font-semibold text-[#071110]">对象数量</div>
              <div className="mt-2 text-3xl font-semibold text-[#071110]">{preview.totals.selectedEntityCount}</div>
            </div>
            <div className="rounded-[18px] border border-[#d8e5dc] bg-white px-4 py-4">
              <div className="text-sm font-semibold text-[#071110]">总投递次数</div>
              <div className="mt-2 text-3xl font-semibold text-[#071110]">{preview.totals.totalTargetAssignments}</div>
            </div>
            <div className="rounded-[18px] border border-[#d8e5dc] bg-white px-4 py-4">
              <div className="text-sm font-semibold text-[#071110]">去重用户数</div>
              <div className="mt-2 text-3xl font-semibold text-[#071110]">{preview.totals.totalUniqueTargetUsers}</div>
            </div>
          </div>

          <div className="mt-4 rounded-[18px] border border-[#d8e5dc] bg-white px-4 py-4">
            <div className="text-sm font-semibold text-[#071110]">{preview.content.headline}</div>
            <div className="mt-2 text-sm leading-6 text-[#45604f]">{preview.content.summary}</div>
            <div className="mt-2 text-xs text-[#45604f]">{preview.content.deeplink || '无 deeplink'}</div>
          </div>

          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {preview.audiences.map(renderAudienceSummary)}
          </div>
        </div>
      ) : null}

      {result ? (
        <div className="mt-5 rounded-[24px] border border-[#dbe6dd] bg-[#f6fbf7] p-5">
          <div className="text-xs uppercase tracking-[0.24em] text-[#44614f]">Publish Result</div>
          <div className="mt-3 text-lg font-semibold text-[#071110]">{result.content.headline}</div>
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {result.audiences.map(renderAudienceSummary)}
          </div>
        </div>
      ) : null}
    </section>
  );
}
