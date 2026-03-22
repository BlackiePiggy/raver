'use client';

import { useEffect, useMemo, useState } from 'react';
import Navigation from '@/components/Navigation';
import { LabelRecord, labelAPI } from '@/lib/api/label';

const sortOptions: Array<{
  value: 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';
  label: string;
  defaultOrder: 'asc' | 'desc';
}> = [
  { value: 'soundcloudFollowers', label: 'SoundCloud 粉丝数', defaultOrder: 'desc' },
  { value: 'likes', label: '点赞数', defaultOrder: 'desc' },
  { value: 'name', label: '名称', defaultOrder: 'asc' },
  { value: 'nation', label: '国家', defaultOrder: 'asc' },
  { value: 'latestRelease', label: '最新发布时间文本', defaultOrder: 'asc' },
  { value: 'createdAt', label: '入库时间', defaultOrder: 'desc' },
];

const formatCount = (value: number | null): string => {
  if (value === null || !Number.isFinite(value)) return '-';
  return new Intl.NumberFormat('en-US').format(value);
};

function LabelCard({ label }: { label: LabelRecord }) {
  const displayGenres = label.genres.length > 0 ? label.genres.slice(0, 5) : (label.genresPreview?.split(',').map((item) => item.trim()).filter(Boolean) || []);

  return (
    <article className="overflow-hidden rounded-2xl border border-bg-tertiary bg-bg-secondary">
      <div className="relative h-44 w-full bg-bg-tertiary">
        {label.backgroundUrl ? (
          <img src={label.backgroundUrl} alt={`${label.name} banner`} className="h-full w-full object-cover" />
        ) : (
          <div className="h-full w-full bg-[linear-gradient(135deg,#0f172a,#1e293b,#111827)]" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/15 to-transparent" />
      </div>

      <div className="px-5 pb-5 pt-4">
        <div className="-mt-16 mb-3 flex items-end gap-4">
          <div className="h-20 w-20 overflow-hidden rounded-xl border-2 border-white/80 bg-bg-tertiary shadow-lg">
            {label.avatarUrl ? (
              <img src={label.avatarUrl} alt={`${label.name} avatar`} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-lg font-bold text-text-secondary">
                {label.name.slice(0, 2).toUpperCase()}
              </div>
            )}
          </div>
          <div className="pb-2">
            <h2 className="text-2xl font-black text-text-primary">{label.name}</h2>
            <p className="text-sm text-text-secondary">
              {label.nation || '未知国家'}
              {label.locationPeriod ? ` · ${label.locationPeriod}` : ''}
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 rounded-xl border border-bg-primary bg-bg-primary p-3 text-sm">
          <div>
            <p className="text-text-tertiary">SoundCloud Followers</p>
            <p className="text-lg font-bold text-text-primary">{formatCount(label.soundcloudFollowers)}</p>
          </div>
          <div>
            <p className="text-text-tertiary">Likes</p>
            <p className="text-lg font-bold text-text-primary">{formatCount(label.likes)}</p>
          </div>
        </div>

        {displayGenres.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-2">
            {displayGenres.map((genre) => (
              <span key={`${label.id}-${genre}`} className="rounded-full border border-bg-primary bg-bg-primary px-2.5 py-1 text-xs text-text-secondary">
                {genre}
              </span>
            ))}
          </div>
        )}

        {label.introduction && <p className="mt-3 line-clamp-3 text-sm leading-6 text-text-secondary">{label.introduction}</p>}

        <div className="mt-4 flex flex-wrap gap-3 text-sm">
          {label.facebookUrl && (
            <a href={label.facebookUrl} target="_blank" rel="noreferrer" className="text-primary-blue hover:text-primary-purple">
              Facebook
            </a>
          )}
          {label.soundcloudUrl && (
            <a href={label.soundcloudUrl} target="_blank" rel="noreferrer" className="text-primary-blue hover:text-primary-purple">
              SoundCloud
            </a>
          )}
          {label.musicPurchaseUrl && (
            <a href={label.musicPurchaseUrl} target="_blank" rel="noreferrer" className="text-primary-blue hover:text-primary-purple">
              购买链接
            </a>
          )}
          {label.officialWebsiteUrl && (
            <a href={label.officialWebsiteUrl} target="_blank" rel="noreferrer" className="text-primary-blue hover:text-primary-purple">
              官网
            </a>
          )}
          <a href={label.profileUrl} target="_blank" rel="noreferrer" className="text-text-tertiary hover:text-text-primary">
            labelsbase 原页面
          </a>
        </div>
      </div>
    </article>
  );
}

export default function LabelsPage() {
  const [labels, setLabels] = useState<LabelRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState<'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt'>('soundcloudFollowers');
  const [order, setOrder] = useState<'asc' | 'desc'>('desc');

  const currentSort = useMemo(() => sortOptions.find((item) => item.value === sortBy), [sortBy]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setSearch(searchInput.trim());
    }, 300);
    return () => window.clearTimeout(timer);
  }, [searchInput]);

  useEffect(() => {
    const run = async () => {
      try {
        setLoading(true);
        setError('');
        const response = await labelAPI.getLabels({
          page: 1,
          limit: 120,
          sortBy,
          order,
          search,
        });
        setLabels(response.labels);
      } catch (e) {
        setError(e instanceof Error ? e.message : '加载厂牌失败');
      } finally {
        setLoading(false);
      }
    };

    run();
  }, [sortBy, order, search]);

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="mx-auto max-w-6xl px-4 pb-16 pt-[60px]">
        <header className="mb-6 rounded-2xl border border-bg-tertiary bg-bg-secondary p-5">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-text-tertiary">Wiki / Labels</p>
          <h1 className="mt-2 text-4xl font-black text-text-primary">厂牌</h1>
          <p className="mt-2 text-sm text-text-secondary">纵向卡片展示厂牌信息，可按 SoundCloud 粉丝数等维度排序。</p>

          <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-[1fr_220px_160px]">
            <input
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder="搜索厂牌名 / 简介"
              className="w-full rounded-lg border border-bg-primary bg-bg-primary px-3 py-2 text-text-primary placeholder:text-text-tertiary focus:border-primary-blue focus:outline-none"
            />

            <select
              value={sortBy}
              onChange={(event) => {
                const nextSortBy = event.target.value as typeof sortBy;
                setSortBy(nextSortBy);
                const option = sortOptions.find((item) => item.value === nextSortBy);
                setOrder(option?.defaultOrder || 'desc');
              }}
              className="rounded-lg border border-bg-primary bg-bg-primary px-3 py-2 text-text-primary focus:border-primary-blue focus:outline-none"
            >
              {sortOptions.map((item) => (
                <option key={item.value} value={item.value}>
                  {item.label}
                </option>
              ))}
            </select>

            <button
              type="button"
              onClick={() => setOrder((prev) => (prev === 'desc' ? 'asc' : 'desc'))}
              className="rounded-lg border border-bg-primary bg-bg-primary px-3 py-2 text-text-primary hover:border-primary-blue"
            >
              排序: {order === 'desc' ? '降序' : '升序'}
            </button>
          </div>

          <p className="mt-3 text-xs text-text-tertiary">
            当前排序: {currentSort?.label || '-'} / {order === 'desc' ? '降序' : '升序'}
          </p>
        </header>

        {error && (
          <div className="mb-4 rounded-lg border border-accent-red/40 bg-accent-red/10 px-3 py-2 text-sm text-accent-red">
            {error}
          </div>
        )}

        {loading ? (
          <div className="py-12 text-center text-text-secondary">加载中...</div>
        ) : labels.length === 0 ? (
          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary px-4 py-8 text-center text-text-secondary">
            暂无厂牌数据
          </div>
        ) : (
          <div className="space-y-4">
            {labels.map((label) => (
              <LabelCard key={label.id} label={label} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
