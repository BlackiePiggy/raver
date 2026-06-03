'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import EntityBindingField from '@/components/admin/EntityBindingField';
import {
  rankingAdminApi,
  type RankingBoardDetail,
  type RankingBoardDetailEntry,
  type RankingBoardSummary,
  type RankingEntityType,
} from '@/features/admin-content/ranking-admin';

const renderDelta = (value: number | null): string => {
  if (value === null || value === 0) return 'No change';
  if (value > 0) return `Up ${value} from last year`;
  return `Down ${Math.abs(value)} from last year`;
};

const buildBindingLabel = (entry: RankingBoardDetailEntry, entityType: RankingEntityType) => {
  if (entityType === 'festival') {
    const bound = entry.festival;
    if (!bound) return null;
    return {
      id: bound.id,
      name: bound.name,
      subtitle: [bound.city, bound.country].filter(Boolean).join(', ') || bound.tagline || null,
      imageUrl: bound.avatarUrl || bound.backgroundUrl || null,
    };
  }

  const bound = entry.dj;
  if (!bound) return null;
  return {
    id: bound.id,
    name: bound.name,
    subtitle: bound.country || bound.slug || null,
    imageUrl: bound.avatarUrl || bound.bannerUrl || null,
  };
};

export default function AdminRankingPage() {
  const [boards, setBoards] = useState<RankingBoardSummary[]>([]);
  const [selectedBoardId, setSelectedBoardId] = useState('');
  const [detail, setDetail] = useState<RankingBoardDetail | null>(null);
  const [loadingBoards, setLoadingBoards] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [saving, setSaving] = useState(false);
  const [bindingKey, setBindingKey] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [yearImportText, setYearImportText] = useState('');

  const selectedBoard = useMemo(
    () => boards.find((item) => item.id === selectedBoardId) ?? null,
    [boards, selectedBoardId]
  );

  const loadBoards = async (preferredBoardId?: string) => {
    setLoadingBoards(true);
    setError('');
    try {
      const items = await rankingAdminApi.listBoards();
      setBoards(items);
      const nextSelected = (preferredBoardId ?? selectedBoardId) || items[0]?.id || '';
      setSelectedBoardId(nextSelected);
      if (!nextSelected) {
        setDetail(null);
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Failed to load ranking boards.');
    } finally {
      setLoadingBoards(false);
    }
  };

  const loadBoardDetail = async (boardId: string, year?: number | null) => {
    setLoadingDetail(true);
    setError('');
    try {
      const nextDetail = await rankingAdminApi.fetchBoard(boardId, year);
      setDetail(nextDetail);
      setYearImportText(
        nextDetail.entries
          .slice()
          .sort((a, b) => a.rank - b.rank)
          .map((item) => `${item.rank}. ${item.name}`)
          .join('\n')
      );
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Failed to load ranking board detail.');
    } finally {
      setLoadingDetail(false);
    }
  };

  useEffect(() => {
    void loadBoards();
  }, []);

  useEffect(() => {
    if (!selectedBoardId) return;
    void loadBoardDetail(selectedBoardId);
  }, [selectedBoardId]);

  const handleUpsertYear = async () => {
    if (!detail?.boardId || !detail.year) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.upsertYear(detail.boardId, detail.year, {
        importText: yearImportText.trim(),
      });
      await loadBoardDetail(detail.boardId, detail.year);
      setNotice(`Updated ${detail.title} for ${detail.year}.`);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Failed to update year entries.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteBoard = async () => {
    if (!selectedBoardId) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.deleteBoard(selectedBoardId);
      setNotice('Deleted ranking board.');
      setDetail(null);
      await loadBoards();
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : 'Failed to delete ranking board.');
    } finally {
      setSaving(false);
    }
  };

  const handleSelectYear = async (year: number) => {
    if (!detail?.boardId) return;
    await loadBoardDetail(detail.boardId, year);
  };

  const handleBindEntry = async (entry: RankingBoardDetailEntry, nextEntityId: string | null) => {
    if (!detail?.boardId || !detail.year) return;
    const key = `${detail.boardId}:${detail.year}:${entry.rank}`;
    setBindingKey(key);
    setError('');
    setNotice('');
    try {
      await rankingAdminApi.updateEntryBinding(detail.boardId, detail.year, entry.rank, {
        entityId: nextEntityId,
      });
      await loadBoardDetail(detail.boardId, detail.year);
      setNotice(
        nextEntityId
          ? `Bound #${entry.rank} ${entry.name} to a library entity.`
          : `Cleared entity binding for #${entry.rank} ${entry.name}.`
      );
    } catch (bindError) {
      setError(bindError instanceof Error ? bindError.message : 'Failed to update ranking binding.');
    } finally {
      setBindingKey('');
    }
  };

  return (
    <AdminContentLayout
      title="Ranking Management"
      description="Maintain ranking boards by year and bind each ranking entry to a canonical library entity."
      actions={
        <>
          <Link
            href="/admin/content"
            className="rounded-full border border-[#ececec] bg-white px-5 py-3 text-sm text-[#18211f]"
          >
            Back to Content Console
          </Link>
          <Link
            href="/admin/content/rankings/new"
            className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
          >
            New Ranking Board
          </Link>
        </>
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

        <div className="grid gap-5 xl:grid-cols-[320px_minmax(0,1fr)]">
          <section className="admin-reference-card p-5">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Boards</div>
                <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">Ranking Boards</h2>
              </div>
              <span className="admin-reference-chip">{boards.length}</span>
            </div>

            <div className="mt-4 space-y-3">
              {boards.map((board) => (
                <button
                  key={board.id}
                  type="button"
                  onClick={() => setSelectedBoardId(board.id)}
                  className={`admin-reference-soft-card w-full rounded-[20px] px-4 py-4 text-left ${
                    selectedBoardId === board.id ? 'border border-[#d7e8dc] bg-[#f6fbf7]' : ''
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-[15px] font-semibold text-[#111827]">{board.title}</div>
                      <div className="mt-1 text-xs text-black/45">{board.id}</div>
                    </div>
                    <span className="admin-reference-chip">{board.entityType === 'dj' ? 'DJ' : 'Festival'}</span>
                  </div>
                  <div className="mt-3 text-xs text-black/48">
                    Years: {board.years.length ? board.years.join(' / ') : 'None'}
                  </div>
                </button>
              ))}

              {!boards.length && !loadingBoards ? (
                <div className="admin-reference-soft-card p-4 text-sm text-black/48">No ranking boards yet.</div>
              ) : null}
            </div>
          </section>

          <section className="admin-reference-card p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs uppercase tracking-[0.14em] text-black/38">Details</div>
                <h2 className="mt-2 text-[20px] font-semibold text-[#111827]">
                  {selectedBoard?.title || 'Select a board'}
                </h2>
                <div className="mt-1 text-sm text-black/48">
                  {detail
                    ? `${detail.entityType === 'festival' ? 'Festival / organizer' : 'DJ'} ranking board`
                    : 'Select a ranking board from the left to continue.'}
                </div>
              </div>
              <button
                type="button"
                className="rounded-full border border-[#e8d9d9] bg-white px-4 py-2 text-sm text-[#8b3a3a]"
                disabled={!selectedBoardId || saving}
                onClick={() => void handleDeleteBoard()}
              >
                Delete Board
              </button>
            </div>

            {detail ? (
              <div className="mt-5 space-y-5">
                <div className="admin-reference-soft-card p-4 text-sm text-black/65">
                  <div>Title: {detail.title}</div>
                  <div className="mt-1">Subtitle: {detail.subtitle || 'Not set'}</div>
                  <div className="mt-1">Binding mode: {detail.strictEntityBinding ? 'Strict entityId binding' : 'Name fallback allowed'}</div>
                </div>

                <div className="flex flex-wrap gap-2">
                  {detail.years.map((year) => (
                    <button
                      key={year}
                      type="button"
                      className={`rounded-full px-4 py-2 text-sm ${
                        detail.year === year
                          ? 'bg-[#071110] text-white'
                          : 'border border-[#e8eceb] bg-white text-[#18211f]'
                      }`}
                      onClick={() => void handleSelectYear(year)}
                      disabled={loadingDetail}
                    >
                      {year}
                    </button>
                  ))}
                </div>

                <div className="admin-reference-soft-card p-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-[#111827]">
                        {detail.year ? `${detail.year} entries` : 'Current year'}
                      </div>
                      <p className="mt-1 text-xs text-black/48">Maintain ranking order and keep each line bound to one canonical library object.</p>
                    </div>
                    <button
                      type="button"
                      className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                      disabled={saving || !detail.year}
                      onClick={() => void handleUpsertYear()}
                    >
                      {saving ? 'Saving...' : 'Save Year Entries'}
                    </button>
                  </div>

                  <textarea
                    className="mt-4 min-h-[140px] w-full rounded-[16px] border border-[#e8eceb] bg-white px-3 py-3 text-sm"
                    value={yearImportText}
                    onChange={(event) => setYearImportText(event.target.value)}
                  />
                </div>

                <div className="space-y-4">
                  {detail.entries
                    .slice()
                    .sort((a, b) => a.rank - b.rank)
                    .map((entry) => {
                      const currentBinding = buildBindingLabel(entry, detail.entityType);
                      const rowBindingKey = `${detail.boardId}:${detail.year}:${entry.rank}`;
                      const isBinding = bindingKey === rowBindingKey;
                      return (
                        <div key={`${detail.boardId}-${detail.year}-${entry.rank}`} className="admin-reference-card p-4">
                          <div className="flex flex-wrap items-start justify-between gap-4">
                            <div className="min-w-0">
                              <div className="flex flex-wrap items-center gap-2">
                                <span className="admin-reference-chip">#{entry.rank}</span>
                                <span className="text-base font-semibold text-[#111827]">{entry.name}</span>
                                <span
                                  className={`rounded-full px-2.5 py-1 text-xs ${
                                    currentBinding
                                      ? 'bg-[#edf7f2] text-[#31513d]'
                                      : 'bg-[#f7efda] text-[#7a5a25]'
                                  }`}
                                >
                                  {currentBinding ? 'Bound' : 'Unbound'}
                                </span>
                              </div>
                              <div className="mt-2 text-xs text-black/45">{renderDelta(entry.delta)}</div>
                              {entry.entityId ? (
                                <div className="mt-2 text-xs text-black/45">entityId: {entry.entityId}</div>
                              ) : null}
                            </div>
                            <div className="w-full xl:max-w-[420px]">
                              <EntityBindingField
                                kind={detail.entityType === 'festival' ? 'festival' : 'dj'}
                                mode="single"
                                seedQuery={entry.name}
                                items={currentBinding ? [currentBinding] : []}
                                disabled={isBinding}
                                title="Bound entity"
                                emptyLabel="This ranking entry is not linked to a library entity yet."
                                onAdd={(value) => handleBindEntry(entry, value.id)}
                                onRemove={() => handleBindEntry(entry, null)}
                              />
                            </div>
                          </div>
                        </div>
                      );
                    })}

                  {!detail.entries.length ? (
                    <div className="admin-reference-soft-card p-4 text-sm text-black/48">
                      No entries yet for this year.
                    </div>
                  ) : null}
                </div>
              </div>
            ) : (
              <div className="admin-reference-soft-card mt-4 p-4 text-sm text-black/48">
                {loadingDetail || loadingBoards ? 'Loading...' : 'Select a ranking board to inspect details.'}
              </div>
            )}
          </section>
        </div>
      </section>
    </AdminContentLayout>
  );
}
