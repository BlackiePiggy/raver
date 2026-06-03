'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { ratingAdminApi, type RatingEvent } from '@/features/admin-content/rating-admin';

export default function AdminRatingsPage() {
  const [items, setItems] = useState<RatingEvent[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [detail, setDetail] = useState<RatingEvent | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [draft, setDraft] = useState({
    name: '',
    description: '',
    imageUrl: '',
    sourceEventId: '',
  });
  const [unitDraft, setUnitDraft] = useState({
    name: '',
    description: '',
    imageUrl: '',
    djIds: '',
  });

  const selectedItem = useMemo(() => items.find((item) => item.id === selectedId) ?? null, [items, selectedId]);

  const loadEvents = async (preferredId?: string) => {
    setLoading(true);
    setError('');
    try {
      const payload = await ratingAdminApi.listEvents();
      setItems(payload.items);
      const nextId = preferredId ?? selectedId ?? payload.items[0]?.id ?? '';
      setSelectedId(nextId);
      if (nextId) {
        const nextDetail = await ratingAdminApi.fetchEvent(nextId);
        setDetail(nextDetail);
      } else {
        setDetail(null);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '加载打分活动失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadEvents();
  }, []);

  useEffect(() => {
    if (!selectedId) return;
    setLoading(true);
    setError('');
    void ratingAdminApi
      .fetchEvent(selectedId)
      .then((payload) => setDetail(payload))
      .catch((nextError) => setError(nextError instanceof Error ? nextError.message : '加载打分详情失败'))
      .finally(() => setLoading(false));
  }, [selectedId]);

  const handleCreateEvent = async () => {
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const created = draft.sourceEventId.trim()
        ? await ratingAdminApi.createEventFromEvent(draft.sourceEventId.trim())
        : await ratingAdminApi.createEvent({
            name: draft.name,
            description: draft.description || undefined,
            imageUrl: draft.imageUrl || null,
          });
      setNotice(`已创建打分活动：${created.name}`);
      await loadEvents(created.id);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '创建打分活动失败');
    } finally {
      setSaving(false);
    }
  };

  const handleCreateUnit = async () => {
    if (!selectedId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.createUnit(selectedId, {
        name: unitDraft.name,
        description: unitDraft.description || undefined,
        imageUrl: unitDraft.imageUrl || null,
        djIds: unitDraft.djIds
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean),
      });
      setNotice('已新增打分项');
      const nextDetail = await ratingAdminApi.fetchEvent(selectedId);
      setDetail(nextDetail);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '新增打分项失败');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteEvent = async () => {
    if (!selectedId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await ratingAdminApi.deleteEvent(selectedId);
      setNotice('打分活动已删除');
      await loadEvents();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '删除打分活动失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminContentLayout
      title="打分管理"
      description="管理评分活动、评分项、来源活动映射与图片资源，支持直接从 Event 生成评分活动。"
      actions={
        <Link href="/admin/content" className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]">
          返回内容控制台
        </Link>
      }
    >
      <section className="space-y-5">
        {error ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">{error}</div> : null}
        {notice ? <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">{notice}</div> : null}

        <div className="grid gap-5 xl:grid-cols-[360px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between">
              <h2 className="text-[20px] font-semibold text-[#111827]">评分活动目录</h2>
              <span className="admin-reference-chip">{items.length}</span>
            </div>
            <div className="mt-4 space-y-3">
              {items.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setSelectedId(item.id)}
                  className={`admin-reference-soft-card w-full rounded-[20px] px-4 py-4 text-left ${
                    selectedId === item.id ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
                  }`}
                >
                  <div className="text-[16px] font-semibold text-[#111827]">{item.name}</div>
                  <div className="mt-2 text-xs text-black/48">{item.id}</div>
                  <div className="mt-2 text-sm text-black/52">评分项 {item.units.length}</div>
                </button>
              ))}
              {!items.length && !loading ? <div className="admin-reference-soft-card p-4 text-sm text-black/48">暂无评分活动。</div> : null}
            </div>
          </section>

          <div className="space-y-5">
            <section className="admin-reference-card p-5">
              <h2 className="text-[20px] font-semibold text-[#111827]">创建评分活动</h2>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="活动名称" value={draft.name} onChange={(event) => setDraft((prev) => ({ ...prev, name: event.target.value }))} />
                <input className="admin-reference-soft-card px-4 py-3 text-sm" placeholder="来源 Event ID（如要从活动生成）" value={draft.sourceEventId} onChange={(event) => setDraft((prev) => ({ ...prev, sourceEventId: event.target.value }))} />
              </div>
              <textarea className="admin-reference-soft-card mt-4 min-h-[110px] w-full px-4 py-3 text-sm" placeholder="描述" value={draft.description} onChange={(event) => setDraft((prev) => ({ ...prev, description: event.target.value }))} />
              <input className="admin-reference-soft-card mt-4 w-full px-4 py-3 text-sm" placeholder="图片 URL（可选）" value={draft.imageUrl} onChange={(event) => setDraft((prev) => ({ ...prev, imageUrl: event.target.value }))} />
              <button type="button" className="mt-4 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateEvent}>
                {saving ? '提交中...' : draft.sourceEventId.trim() ? '从活动生成评分活动' : '创建评分活动'}
              </button>
            </section>

            <section className="admin-reference-card p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-[20px] font-semibold text-[#111827]">当前活动</h2>
                  <div className="mt-1 text-sm text-black/48">{selectedItem ? selectedItem.name : '请选择左侧评分活动'}</div>
                </div>
                <button type="button" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm" disabled={!selectedId || saving} onClick={handleDeleteEvent}>
                  删除评分活动
                </button>
              </div>
              {detail ? (
                <div className="mt-4 space-y-4">
                  <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                    <div>来源活动：{detail.sourceEventId || '未绑定'}</div>
                    <div className="mt-1">评分项数量：{detail.units.length}</div>
                  </div>
                  <div className="admin-reference-soft-card p-4">
                    <div className="text-sm font-semibold text-[#111827]">新增评分项</div>
                    <div className="mt-3 grid gap-3 md:grid-cols-2">
                      <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="评分项名称" value={unitDraft.name} onChange={(event) => setUnitDraft((prev) => ({ ...prev, name: event.target.value }))} />
                      <input className="rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="关联 DJ IDs（逗号分隔）" value={unitDraft.djIds} onChange={(event) => setUnitDraft((prev) => ({ ...prev, djIds: event.target.value }))} />
                    </div>
                    <textarea className="mt-3 min-h-[90px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="描述" value={unitDraft.description} onChange={(event) => setUnitDraft((prev) => ({ ...prev, description: event.target.value }))} />
                    <input className="mt-3 w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-2 text-sm" placeholder="图片 URL（可选）" value={unitDraft.imageUrl} onChange={(event) => setUnitDraft((prev) => ({ ...prev, imageUrl: event.target.value }))} />
                    <button type="button" className="mt-4 rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white" disabled={saving} onClick={handleCreateUnit}>
                      {saving ? '保存中...' : '添加评分项'}
                    </button>
                  </div>
                  <div className="space-y-3">
                    {detail.units.map((unit) => (
                      <div key={unit.id} className="admin-reference-soft-card p-4">
                        <div className="text-[15px] font-semibold text-[#111827]">{unit.name}</div>
                        <div className="mt-1 text-xs text-black/48">{unit.id}</div>
                        <div className="mt-2 text-sm text-black/56">{unit.description || '无描述'}</div>
                      </div>
                    ))}
                    {!detail.units.length ? <div className="admin-reference-soft-card p-4 text-sm text-black/48">当前没有评分项。</div> : null}
                  </div>
                </div>
              ) : (
                <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">{loading ? '加载中...' : '请选择一个评分活动查看详情。'}</div>
              )}
            </section>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
