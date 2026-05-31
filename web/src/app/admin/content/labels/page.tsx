'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { labelStudioApi, type LabelStudioLoadedLabel } from '@/features/admin-content/label-studio';

const formatNumber = (value?: number | null): string =>
  typeof value === 'number' && Number.isFinite(value) ? new Intl.NumberFormat('zh-CN').format(value) : '未同步';

function LabelDetailOverlay({
  item,
  detail,
  loading,
  error,
  onClose,
}: {
  item: LabelStudioLoadedLabel | null;
  detail: LabelStudioLoadedLabel | null;
  loading: boolean;
  error: string;
  onClose: () => void;
}) {
  if (!item) return null;

  const resolved = detail ?? item;
  const heroImage = resolved.backgroundUrl || resolved.avatarUrl || resolved.logoUrl || '';

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/45 p-4" onClick={onClose}>
      <div
        className="relative max-h-[90vh] w-full max-w-[1040px] overflow-hidden rounded-[28px] border border-white/70 bg-[#f7f5ef] shadow-[0_30px_120px_rgba(7,17,16,0.24)]"
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute right-6 top-6 z-10 inline-flex h-10 w-10 items-center justify-center rounded-full border border-[#e8eceb] bg-white text-[#6b7280]"
          aria-label="关闭厂牌详情"
        >
          ×
        </button>

        <div className="grid max-h-[90vh] overflow-y-auto lg:grid-cols-[1.05fr_1.45fr]">
          <div className="border-b border-[#e8eceb] bg-[linear-gradient(180deg,#eef4f0_0%,#f7f5ef_100%)] p-6 lg:border-b-0 lg:border-r">
            <div className="overflow-hidden rounded-[24px] border border-[#dfe7e2] bg-[#e7ece9]">
              {heroImage ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={heroImage} alt={resolved.name} className="aspect-[1.25/1] w-full object-cover" />
              ) : (
                <div className="flex aspect-[1.25/1] items-center justify-center text-sm text-[#7b8794]">暂无主视觉</div>
              )}
            </div>

            <div className="-mt-10 px-4">
              <div className="rounded-[24px] border border-[#e8eceb] bg-white/96 p-5 shadow-[0_12px_32px_rgba(33,52,47,0.08)]">
                <div className="flex flex-wrap gap-2">
                  {resolved.nation ? <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.nation}</span> : null}
                  {resolved.genresPreview ? <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">{resolved.genresPreview}</span> : null}
                </div>
                <div className="mt-3 text-[28px] font-semibold tracking-[-0.04em] text-[#111827]">{resolved.name}</div>
                <div className="mt-2 text-sm font-medium text-[#6b7280]">{resolved.locationPeriod || resolved.slug}</div>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              {[
                ['Followers', formatNumber(resolved.soundcloudFollowers)],
                ['Likes', formatNumber(resolved.likes)],
                ['Genres', resolved.genres.length.toLocaleString()],
                ['Founder', resolved.founderName || '未设置'],
              ].map(([label, value]) => (
                <div key={label} className="rounded-[20px] border border-[#e8eceb] bg-white px-4 py-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">{label}</div>
                  <div className="mt-2 text-xl font-semibold text-[#111827]">{value}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.14em] text-[#9aa1ad]">Label Profile</div>
                <div className="mt-2 text-[26px] font-semibold tracking-[-0.04em] text-[#111827]">详细信息</div>
              </div>
              <Link
                href={`/admin/content/labels/${item.id}/edit`}
                className="inline-flex h-[42px] items-center rounded-full bg-[#071110] px-5 text-sm font-semibold text-white"
              >
                编辑厂牌
              </Link>
            </div>

            {loading ? (
              <div className="mt-6 rounded-[22px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
                正在加载厂牌完整信息...
              </div>
            ) : error ? (
              <div className="mt-6 rounded-[22px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
                {error}
              </div>
            ) : (
              <div className="mt-6 space-y-5">
                <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                  <div className="text-sm font-semibold text-[#111827]">简介</div>
                  <div className="mt-3 text-sm leading-7 text-[#4b5563]">
                    {resolved.introduction || resolved.introductionPreview || '暂无厂牌简介。'}
                  </div>
                </section>

                <section className="grid gap-5 lg:grid-cols-2">
                  <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="text-sm font-semibold text-[#111827]">基础资料</div>
                    <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                      <div><span className="font-medium text-[#111827]">ID: </span>{resolved.id}</div>
                      <div><span className="font-medium text-[#111827]">Slug: </span>{resolved.slug}</div>
                      <div><span className="font-medium text-[#111827]">Profile Slug: </span>{resolved.profileSlug || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Profile URL: </span>{resolved.profileUrl || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Founded: </span>{resolved.foundedAt || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Founder DJ ID: </span>{resolved.founderDjId || '未设置'}</div>
                    </div>
                  </div>

                  <div className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                    <div className="text-sm font-semibold text-[#111827]">链接与联系</div>
                    <div className="mt-4 space-y-3 text-sm text-[#4b5563]">
                      <div><span className="font-medium text-[#111827]">Official: </span>{resolved.officialWebsiteUrl || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Facebook: </span>{resolved.facebookUrl || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">SoundCloud: </span>{resolved.soundcloudUrl || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Purchase: </span>{resolved.musicPurchaseUrl || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Contact: </span>{resolved.generalContactEmail || '未设置'}</div>
                      <div><span className="font-medium text-[#111827]">Demo: </span>{resolved.demoSubmissionDisplay || resolved.demoSubmissionUrl || '未设置'}</div>
                    </div>
                  </div>
                </section>

                <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
                  <div className="text-sm font-semibold text-[#111827]">Genres</div>
                  <div className="mt-4 flex flex-wrap gap-2">
                    {resolved.genres.length ? resolved.genres.map((genre) => (
                      <span key={genre} className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#4b5563]">
                        {genre}
                      </span>
                    )) : <div className="text-sm text-[#6b7280]">暂无 genres。</div>}
                  </div>
                </section>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function AdminContentLabelsPage() {
  const [items, setItems] = useState<LabelStudioLoadedLabel[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState('');
  const [inputValue, setInputValue] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedLabel, setSelectedLabel] = useState<LabelStudioLoadedLabel | null>(null);
  const [selectedLabelDetail, setSelectedLabelDetail] = useState<LabelStudioLoadedLabel | null>(null);
  const [selectedLabelLoading, setSelectedLabelLoading] = useState(false);
  const [selectedLabelError, setSelectedLabelError] = useState('');
  const [detailCache, setDetailCache] = useState<Record<string, LabelStudioLoadedLabel>>({});

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        setLoading(true);
        setError(null);
        const response = await labelStudioApi.listLabels(page, 12, search);
        if (cancelled) return;
        setItems(response.items);
        setTotalPages(response.pagination.totalPages || 1);
      } catch (loadError) {
        if (cancelled) return;
        setError(loadError instanceof Error ? loadError.message : '加载厂牌失败');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [page, search]);

  const openDetailOverlay = async (item: LabelStudioLoadedLabel) => {
    setSelectedLabel(item);
    setSelectedLabelError('');
    const cached = detailCache[item.id];
    if (cached) {
      setSelectedLabelDetail(cached);
      setSelectedLabelLoading(false);
      return;
    }

    setSelectedLabelDetail(null);
    setSelectedLabelLoading(true);
    try {
      const detail = await labelStudioApi.fetchLabel(item.id);
      setDetailCache((current) => ({ ...current, [item.id]: detail }));
      setSelectedLabelDetail(detail);
    } catch (detailError) {
      setSelectedLabelError(detailError instanceof Error ? detailError.message : '厂牌详情加载失败');
    } finally {
      setSelectedLabelLoading(false);
    }
  };

  const closeDetailOverlay = () => {
    setSelectedLabel(null);
    setSelectedLabelDetail(null);
    setSelectedLabelLoading(false);
    setSelectedLabelError('');
  };

  return (
    <AdminContentLayout
      title="厂牌工作区"
      description="厂牌资料、视觉链接和官方渠道现在已经可以直接在网页后台中创建与编辑，并采用更接近参考后台的内容优先排版。"
      actions={
        <>
          <Link href="/admin/content" className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110]">
            返回内容控制台
          </Link>
          <Link href="/admin/content/labels/new" className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
            新建厂牌
          </Link>
        </>
      }
    >
      <section className="space-y-5">
        <div className="grid gap-4 lg:grid-cols-4">
          {[
            { label: 'Label Studio', value: 'Live', note: '创建 / 编辑已接入', tone: 'bg-[#dff4a8]' },
            { label: 'Visual Mode', value: 'URL', note: '视觉先走 URL 模式', tone: 'bg-[#f3e5a8]' },
            { label: 'Paging', value: `${page}/${totalPages}`, note: '标准页码', tone: 'bg-[#f7c4c0]' },
            { label: 'Results', value: String(items.length), note: '当前页数据', tone: 'bg-[#dbeefe]' },
          ].map((item) => (
            <div key={item.label} className={`admin-reference-pastel-card p-5 ${item.tone}`}>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">{item.label}</div>
              <div className="mt-4 text-[34px] font-semibold tracking-[-0.04em] text-[#1a1a1a]">{item.value}</div>
              <div className="mt-2 text-[13px] text-black/55">{item.note}</div>
            </div>
          ))}
        </div>

        <section className="admin-reference-card p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-[12px] uppercase tracking-[0.18em] text-black/35">Label Directory</div>
              <h2 className="mt-2 text-[30px] font-semibold tracking-[-0.03em] text-[#1a1a1a]">厂牌目录</h2>
            </div>
            <div className="flex flex-wrap gap-3">
              <input
                value={inputValue}
                onChange={(event) => setInputValue(event.target.value)}
                className="admin-studio-input w-[260px]"
                placeholder="搜索厂牌名称"
              />
              <button
                type="button"
                onClick={() => {
                  setPage(1);
                  setSearch(inputValue.trim());
                }}
                className="admin-studio-button-secondary px-5 py-3 text-sm"
              >
                搜索
              </button>
            </div>
          </div>

          {loading ? (
            <div className="mt-6 text-sm text-black/48">正在加载厂牌目录...</div>
          ) : error ? (
            <div className="admin-studio-pastel-rose mt-6 p-4 text-sm text-[#6a3530]">{error}</div>
          ) : (
            <div className="mt-6 grid gap-4 xl:grid-cols-2">
              {items.map((item) => (
                <div
                  key={item.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => void openDetailOverlay(item)}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault();
                      void openDetailOverlay(item);
                    }
                  }}
                  className="admin-reference-soft-card cursor-pointer p-5 transition-colors hover:bg-[#fafaf8] focus:outline-none focus:ring-2 focus:ring-[#d9e7dd]"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap gap-2">
                        {item.nation ? <span className="admin-reference-chip">{item.nation}</span> : null}
                        {item.genresPreview ? <span className="admin-reference-chip">{item.genresPreview}</span> : null}
                      </div>
                      <h3 className="mt-4 text-xl font-semibold tracking-[-0.02em] text-[#071110]">{item.name}</h3>
                      <p className="mt-2 line-clamp-3 text-sm leading-7 text-black/48">
                        {item.introductionPreview || item.introduction || '暂无厂牌简介'}
                      </p>
                    </div>
                    <Link
                      href={`/admin/content/labels/${item.id}/edit`}
                      onClick={(event) => event.stopPropagation()}
                      className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white"
                    >
                      编辑厂牌
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              disabled={page <= 1}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              上一页
            </button>
            <button
              type="button"
              onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
              disabled={page >= totalPages}
              className="admin-studio-button-secondary px-5 py-3 text-sm disabled:opacity-50"
            >
              下一页
            </button>
          </div>
        </section>
      </section>

      <LabelDetailOverlay
        item={selectedLabel}
        detail={selectedLabelDetail}
        loading={selectedLabelLoading}
        error={selectedLabelError}
        onClose={closeDetailOverlay}
      />
    </AdminContentLayout>
  );
}
