'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  identifierAdminApi,
  type UnreleasedTrackItem,
  type UnreleasedTrackSourceType,
  type UnreleasedTrackUpdateInput,
} from '@/features/admin-content/identifier-admin';

const PAGE_SIZE = 20;

type EditDraftMap = Record<string, UnreleasedTrackUpdateInput>;

const sourceTypeLabel: Record<UnreleasedTrackSourceType, string> = {
  default_track: '默认轨道',
  tracklist_track: '用户 Tracklist',
};

const formatSeconds = (value: number): string => {
  const total = Math.max(0, Math.floor(value));
  const hour = Math.floor(total / 3600);
  const minute = Math.floor((total % 3600) / 60);
  const second = total % 60;
  if (hour > 0) {
    return `${hour}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
  }
  return `${minute}:${String(second).padStart(2, '0')}`;
};

const buildDraftFromItem = (item: UnreleasedTrackItem): UnreleasedTrackUpdateInput => ({
  title: item.title,
  artist: item.artist,
  status: item.status,
  label: item.label || '',
  releaseYear: item.releaseYear,
  spotifyUrl: item.spotifyUrl || '',
  spotifyId: item.spotifyId || '',
  spotifyUri: item.spotifyUri || '',
  appleMusicUrl: item.appleMusicUrl || '',
  youtubeMusicUrl: item.youtubeMusicUrl || '',
  soundcloudUrl: item.soundcloudUrl || '',
  beatportUrl: item.beatportUrl || '',
  neteaseUrl: item.neteaseUrl || '',
  neteaseId: item.neteaseId || '',
});

export default function AdminIdentifiersPage() {
  const [items, setItems] = useState<UnreleasedTrackItem[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [sourceType, setSourceType] = useState<'all' | UnreleasedTrackSourceType>('all');
  const [loading, setLoading] = useState(false);
  const [savingKey, setSavingKey] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [drafts, setDrafts] = useState<EditDraftMap>({});

  const hasItems = items.length > 0;

  const load = async (nextPage = page) => {
    setLoading(true);
    setError('');
    try {
      const payload = await identifierAdminApi.listUnreleasedTracks({
        search,
        sourceType,
        page: nextPage,
        limit: PAGE_SIZE,
      });
      setItems(payload.items);
      setPage(payload.pagination.page);
      setTotal(payload.pagination.total);
      setTotalPages(payload.pagination.totalPages);
      setDrafts(
        Object.fromEntries(payload.items.map((item) => [item.rowId, buildDraftFromItem(item)]))
      );
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载未发布歌曲 ID 列表失败。');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load(1);
  }, [sourceType]);

  const summary = useMemo(() => {
    const defaultCount = items.filter((item) => item.sourceType === 'default_track').length;
    const tracklistCount = items.filter((item) => item.sourceType === 'tracklist_track').length;
    return { defaultCount, tracklistCount };
  }, [items]);

  const updateDraft = (rowId: string, patch: Partial<UnreleasedTrackUpdateInput>) => {
    setDrafts((current) => ({
      ...current,
      [rowId]: {
        ...current[rowId],
        ...patch,
      },
    }));
  };

  const handleSave = async (item: UnreleasedTrackItem) => {
    const draft = drafts[item.rowId];
    if (!draft) return;
    setSavingKey(item.rowId);
    setError('');
    setNotice('');
    try {
      await identifierAdminApi.updateUnreleasedTrack(item.rowId, {
        ...draft,
        label: typeof draft.label === 'string' ? draft.label.trim() || null : draft.label,
        spotifyUrl: typeof draft.spotifyUrl === 'string' ? draft.spotifyUrl.trim() || null : draft.spotifyUrl,
        spotifyId: typeof draft.spotifyId === 'string' ? draft.spotifyId.trim() || null : draft.spotifyId,
        spotifyUri: typeof draft.spotifyUri === 'string' ? draft.spotifyUri.trim() || null : draft.spotifyUri,
        appleMusicUrl:
          typeof draft.appleMusicUrl === 'string' ? draft.appleMusicUrl.trim() || null : draft.appleMusicUrl,
        youtubeMusicUrl:
          typeof draft.youtubeMusicUrl === 'string' ? draft.youtubeMusicUrl.trim() || null : draft.youtubeMusicUrl,
        soundcloudUrl:
          typeof draft.soundcloudUrl === 'string' ? draft.soundcloudUrl.trim() || null : draft.soundcloudUrl,
        beatportUrl:
          typeof draft.beatportUrl === 'string' ? draft.beatportUrl.trim() || null : draft.beatportUrl,
        neteaseUrl: typeof draft.neteaseUrl === 'string' ? draft.neteaseUrl.trim() || null : draft.neteaseUrl,
        neteaseId: typeof draft.neteaseId === 'string' ? draft.neteaseId.trim() || null : draft.neteaseId,
      });
      setNotice(`已更新未发布曲目：${item.artist} - ${item.title}`);
      await load(page);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存未发布曲目失败。');
    } finally {
      setSavingKey('');
    }
  };

  return (
    <AdminContentLayout
      title="ID 管理"
      description="统一管理未发布歌曲条目。这里的 ID 指 track / tracklist 中标记为 unreleased ID 的曲目，而不是实体 identifier。"
      actions={
        <Link
          href="/admin/content"
          className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]"
        >
          返回内容控制台
        </Link>
      }
    >
      <section className="space-y-5">
        {error ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] p-4 text-sm text-[#6a3530]">
            {error}
          </div>
        ) : null}
        {notice ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] p-4 text-sm text-[#2f4027]">
            {notice}
          </div>
        ) : null}

        <section className="grid gap-4 md:grid-cols-3">
          <div className="admin-reference-pastel-card bg-[#eaf4ff] p-4">
            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Total</div>
            <div className="mt-3 text-3xl font-semibold text-[#111827]">{total}</div>
            <div className="mt-2 text-sm text-black/48">当前筛选下的未发布条目总数</div>
          </div>
          <div className="admin-reference-pastel-card bg-[#edf7f2] p-4">
            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Default Track</div>
            <div className="mt-3 text-3xl font-semibold text-[#111827]">{summary.defaultCount}</div>
            <div className="mt-2 text-sm text-black/48">当前页默认轨道来源</div>
          </div>
          <div className="admin-reference-pastel-card bg-[#fff3df] p-4">
            <div className="text-xs uppercase tracking-[0.14em] text-black/38">Tracklist Track</div>
            <div className="mt-3 text-3xl font-semibold text-[#111827]">{summary.tracklistCount}</div>
            <div className="mt-2 text-sm text-black/48">当前页用户 Tracklist 来源</div>
          </div>
        </section>

        <section className="admin-reference-card p-5">
          <div className="flex flex-wrap items-center gap-3">
            <input
              className="admin-reference-soft-card min-w-[260px] flex-1 px-4 py-3 text-sm"
              placeholder="搜索曲名 / 艺人 / set / contributor"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <select
              className="admin-reference-soft-card px-4 py-3 text-sm"
              value={sourceType}
              onChange={(event) => setSourceType(event.target.value as 'all' | UnreleasedTrackSourceType)}
            >
              <option value="all">全部来源</option>
              <option value="default_track">默认轨道</option>
              <option value="tracklist_track">用户 Tracklist</option>
            </select>
            <button
              type="button"
              className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
              disabled={loading}
              onClick={() => void load(1)}
            >
              {loading ? '加载中...' : '搜索'}
            </button>
          </div>
        </section>

        <section className="space-y-4">
          {items.map((item) => {
            const draft = drafts[item.rowId] || buildDraftFromItem(item);
            const rowSaving = savingKey === item.rowId;
            return (
              <div key={item.rowId} className="admin-reference-card p-5">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="admin-reference-chip">{sourceTypeLabel[item.sourceType]}</span>
                      <span className="admin-reference-chip">{draft.status || item.status}</span>
                      <span className="text-base font-semibold text-[#111827]">
                        {item.artist} - {item.title}
                      </span>
                    </div>
                    <div className="mt-2 text-sm text-black/52">
                      Set: {item.setTitle} · DJ: {item.djDisplayName} · 位置 #{item.position} · {formatSeconds(item.startTime)}
                      {item.endTime !== null ? ` - ${formatSeconds(item.endTime)}` : ''}
                    </div>
                    <div className="mt-1 text-xs text-black/45">
                      {item.tracklistId
                        ? `Tracklist: ${item.tracklistTitle || item.tracklistId}`
                        : '来源：默认轨道'}
                      {item.contributorName ? ` · Contributor: ${item.contributorName}` : ''}
                    </div>
                    <div className="mt-1 text-xs text-black/38">rowId: {item.rowId}</div>
                  </div>

                  <button
                    type="button"
                    className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                    disabled={rowSaving}
                    onClick={() => void handleSave(item)}
                  >
                    {rowSaving ? '保存中...' : '保存'}
                  </button>
                </div>

                <div className="mt-4 grid gap-3 xl:grid-cols-4">
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.artist || ''}
                    placeholder="艺人"
                    onChange={(event) => updateDraft(item.rowId, { artist: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.title || ''}
                    placeholder="曲名"
                    onChange={(event) => updateDraft(item.rowId, { title: event.target.value })}
                  />
                  <select
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.status || item.status}
                    onChange={(event) =>
                      updateDraft(item.rowId, {
                        status: event.target.value as UnreleasedTrackItem['status'],
                      })
                    }
                  >
                    <option value="id">id / unreleased</option>
                    <option value="released">released</option>
                    <option value="remix">remix</option>
                    <option value="edit">edit</option>
                  </select>
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.label || ''}
                    placeholder="Label"
                    onChange={(event) => updateDraft(item.rowId, { label: event.target.value })}
                  />
                </div>

                <div className="mt-3 grid gap-3 xl:grid-cols-4">
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.releaseYear ?? ''}
                    placeholder="Release Year"
                    onChange={(event) =>
                      updateDraft(item.rowId, {
                        releaseYear: event.target.value ? Number(event.target.value) : null,
                      })
                    }
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.spotifyId || ''}
                    placeholder="Spotify ID"
                    onChange={(event) => updateDraft(item.rowId, { spotifyId: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.neteaseId || ''}
                    placeholder="Netease ID"
                    onChange={(event) => updateDraft(item.rowId, { neteaseId: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.spotifyUri || ''}
                    placeholder="Spotify URI"
                    onChange={(event) => updateDraft(item.rowId, { spotifyUri: event.target.value })}
                  />
                </div>

                <div className="mt-3 grid gap-3 xl:grid-cols-2">
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.spotifyUrl || ''}
                    placeholder="Spotify URL"
                    onChange={(event) => updateDraft(item.rowId, { spotifyUrl: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.appleMusicUrl || ''}
                    placeholder="Apple Music URL"
                    onChange={(event) => updateDraft(item.rowId, { appleMusicUrl: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.youtubeMusicUrl || ''}
                    placeholder="YouTube Music URL"
                    onChange={(event) => updateDraft(item.rowId, { youtubeMusicUrl: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.soundcloudUrl || ''}
                    placeholder="SoundCloud URL"
                    onChange={(event) => updateDraft(item.rowId, { soundcloudUrl: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.beatportUrl || ''}
                    placeholder="Beatport URL"
                    onChange={(event) => updateDraft(item.rowId, { beatportUrl: event.target.value })}
                  />
                  <input
                    className="admin-reference-soft-card px-4 py-3 text-sm"
                    value={draft.neteaseUrl || ''}
                    placeholder="Netease URL"
                    onChange={(event) => updateDraft(item.rowId, { neteaseUrl: event.target.value })}
                  />
                </div>
              </div>
            );
          })}

          {!hasItems ? (
            <div className="admin-reference-soft-card p-5 text-sm text-black/48">
              {loading ? '加载中...' : '当前没有符合条件的未发布歌曲条目。'}
            </div>
          ) : null}
        </section>

        <section className="admin-reference-card flex flex-wrap items-center justify-between gap-3 px-5 py-4">
          <div className="text-sm text-black/52">
            共 {total} 条，当前第 {page} / {totalPages} 页
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm text-[#18211f]"
              disabled={page <= 1 || loading}
              onClick={() => void load(page - 1)}
            >
              上一页
            </button>
            <button
              type="button"
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm text-[#18211f]"
              disabled={page >= totalPages || loading}
              onClick={() => void load(page + 1)}
            >
              下一页
            </button>
          </div>
        </section>
      </section>
    </AdminContentLayout>
  );
}
