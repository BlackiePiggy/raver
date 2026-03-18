'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { djAPI, DJ } from '@/lib/api/dj';
import { DJCard } from '@/components/DJCard';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import Navigation from '@/components/Navigation';
import { getApiUrl } from '@/lib/config';

const getInitials = (name: string) =>
  name
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

const getLowResAvatar = (url: string) =>
  url
    .replace('ab6761610000e5eb', 'ab6761610000f178')
    .replace('ab67616100005174', 'ab6761610000f178')
    .replace('ab67616d0000b273', 'ab67616d00004851')
    .replace('ab67616d00001e02', 'ab67616d00004851');

const getHighResAvatar = (url: string) =>
  url
    .replace('ab6761610000f178', 'ab6761610000e5eb')
    .replace('ab67616100005174', 'ab6761610000e5eb')
    .replace('ab67616d00004851', 'ab67616d0000b273')
    .replace('ab67616d00001e02', 'ab67616d0000b273');

const DEFAULT_GLOW = 'rgba(59,130,246,0.95)';

const getAverageGlowColorFromImage = async (url: string): Promise<string> => {
  try {
    if (typeof window === 'undefined') {
      return DEFAULT_GLOW;
    }

    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.referrerPolicy = 'no-referrer';
    img.src = url;

    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error('image load failed'));
    });

    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return DEFAULT_GLOW;
    }

    const sampleSize = 24;
    canvas.width = sampleSize;
    canvas.height = sampleSize;
    ctx.drawImage(img, 0, 0, sampleSize, sampleSize);
    const { data } = ctx.getImageData(0, 0, sampleSize, sampleSize);

    let r = 0;
    let g = 0;
    let b = 0;
    let count = 0;

    for (let i = 0; i < data.length; i += 4) {
      const alpha = data[i + 3];
      if (alpha < 32) {
        continue;
      }

      const cr = data[i];
      const cg = data[i + 1];
      const cb = data[i + 2];
      const brightness = (cr + cg + cb) / 3;
      if (brightness < 18) {
        continue;
      }

      r += cr;
      g += cg;
      b += cb;
      count += 1;
    }

    if (count === 0) {
      return DEFAULT_GLOW;
    }

    const ar = Math.min(255, Math.round((r / count) * 1.2));
    const ag = Math.min(255, Math.round((g / count) * 1.2));
    const ab = Math.min(255, Math.round((b / count) * 1.2));
    return `rgba(${ar}, ${ag}, ${ab}, 0.95)`;
  } catch {
    return DEFAULT_GLOW;
  }
};

function DJAvatar({
  dj,
  sizeClass,
}: {
  dj: DJ;
  sizeClass: string;
}) {
  const [failed, setFailed] = useState(false);
  const src = dj.avatarUrl ? getLowResAvatar(dj.avatarUrl) : null;

  if (!src || failed) {
    return (
      <div className={`flex items-center justify-center rounded-full bg-gradient-to-br from-primary-purple to-primary-blue font-bold text-white ${sizeClass}`}>
        {getInitials(dj.name)}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={dj.name}
      loading="lazy"
      referrerPolicy="no-referrer"
      className={`rounded-full object-cover ${sizeClass}`}
      onError={() => setFailed(true)}
    />
  );
}

function DJHeroPreview({
  dj,
  representativeWorks,
  genres,
  recentPerformances,
}: {
  dj: DJ | null;
  representativeWorks: string[];
  genres: string[];
  recentPerformances: Array<{ title: string; when: string; where: string }>;
}) {
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    setFailed(false);
  }, [dj?.id]);

  if (!dj) {
    return null;
  }

  const src = dj.avatarUrl ? getHighResAvatar(dj.avatarUrl) : null;

  return (
    <div className="pointer-events-auto absolute left-6 z-40 h-[500px] w-[300px] overflow-hidden rounded-2xl border border-white/20 bg-black/58 p-3 backdrop-blur-xl transition-all duration-300 md:w-[390px]">
      <div className="relative aspect-[4/3] overflow-hidden rounded-xl bg-bg-tertiary">
        {src && !failed ? (
          <img
            src={src}
            alt={dj.name}
            loading="eager"
            referrerPolicy="no-referrer"
            className="h-full w-full object-cover"
            onError={() => setFailed(true)}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[linear-gradient(140deg,#1f2937,#0f172a,#111827)] text-4xl font-black text-white/80">
            {getInitials(dj.name)}
          </div>
        )}
      </div>
      <div className="mt-3 max-h-[250px] overflow-y-auto pr-1 md:max-h-[200px]">
        <p className="text-2xl font-bold text-white">{dj.name}</p>
        <p className="mt-1 text-xs text-white/75">{dj.country || 'Unknown Region'}</p>
        <p className="mt-1 text-xs text-white/70">粉丝：{dj.followerCount.toLocaleString()}</p>

        {genres.length > 0 && (
          <div className="mt-3">
            <p className="text-[11px] uppercase tracking-wide text-white/70">风格</p>
            <div className="mt-1 flex flex-wrap gap-1.5">
              {genres.slice(0, 5).map((genre) => (
                <span key={genre} className="rounded-full border border-white/25 bg-white/10 px-2 py-0.5 text-[11px] text-white/90">
                  {genre}
                </span>
              ))}
            </div>
          </div>
        )}

        {representativeWorks.length > 0 && (
          <div className="mt-3">
            <p className="text-[11px] uppercase tracking-wide text-white/70">代表作品</p>
            <ul className="mt-1 space-y-1">
              {representativeWorks.slice(0, 4).map((work) => (
                <li key={work} className="line-clamp-1 text-xs text-white/85">
                  {work}
                </li>
              ))}
            </ul>
          </div>
        )}

        {recentPerformances.length > 0 && (
          <div className="mt-3">
            <p className="text-[11px] uppercase tracking-wide text-white/70">最近表演</p>
            <div className="mt-1 space-y-1.5">
              {recentPerformances.slice(0, 3).map((item, idx) => (
                <div key={`${item.title}-${idx}`} className="rounded-lg border border-white/15 bg-white/[0.04] px-2 py-1.5">
                  <p className="line-clamp-1 text-xs font-medium text-white/90">{item.title}</p>
                  <p className="line-clamp-1 text-[11px] text-white/70">
                    {item.when}
                    {item.where ? ` · ${item.where}` : ''}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}

        {dj.bio && <p className="mt-3 line-clamp-3 text-xs text-white/70">{dj.bio}</p>}
      </div>
    </div>
  );
}

export default function DJsPage() {
  const [djs, setDJs] = useState<DJ[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [hoveredDjId, setHoveredDjId] = useState<string | null>(null);
  const [hoveredRowIndex, setHoveredRowIndex] = useState<number | null>(null);
  const [avatarGlowMap, setAvatarGlowMap] = useState<Record<string, string>>({});
  const inflightGlowTasks = useRef<Record<string, boolean>>({});
  const [worksMap, setWorksMap] = useState<Record<string, string[]>>({});
  const [recentMap, setRecentMap] = useState<Record<string, Array<{ title: string; when: string; where: string }>>>({});
  const [sortBy, setSortBy] = useState<'followerCount' | 'name' | 'createdAt'>('followerCount');
  const showCardView = search.trim().length > 0 || sortBy !== 'followerCount';

  const hoveredDj = useMemo(
    () => djs.find((dj) => dj.id === hoveredDjId) || null,
    [djs, hoveredDjId]
  );

  const marqueeDjs = useMemo(() => djs.slice(0, 40), [djs]);
  const rows = useMemo(() => {
    const segmented = [0, 1, 2, 3].map((mod) => marqueeDjs.filter((_, idx) => idx % 4 === mod));
    return segmented.map((row) => (row.length > 0 ? row : marqueeDjs.slice(0, 8)));
  }, [marqueeDjs]);

  useEffect(() => {
    const fetchHoverDetails = async () => {
      if (!hoveredDjId || (worksMap[hoveredDjId] && recentMap[hoveredDjId])) {
        return;
      }

      try {
        const response = await fetch(getApiUrl(`/dj-sets/dj/${hoveredDjId}`));
        const sets = await response.json();
        if (!Array.isArray(sets)) {
          setWorksMap((prev) => ({ ...prev, [hoveredDjId]: [] }));
          setRecentMap((prev) => ({ ...prev, [hoveredDjId]: [] }));
          return;
        }

        const titles: string[] = [];
        sets.forEach((set: any) => {
          const tracks = Array.isArray(set?.tracks) ? set.tracks : [];
          tracks.forEach((track: any) => {
            if (track?.title && typeof track.title === 'string') {
              titles.push(track.title.trim());
            }
          });
        });

        const unique = [...new Set(titles)].filter(Boolean).slice(0, 4);
        setWorksMap((prev) => ({ ...prev, [hoveredDjId]: unique }));

        const recent = sets
          .slice(0, 4)
          .map((set: any) => {
            const whenSource = set?.recordedAt || set?.createdAt;
            const when = whenSource
              ? new Date(whenSource).toLocaleDateString('zh-CN')
              : '日期未知';
            const where = set?.eventName || set?.venue || '';
            const title = typeof set?.title === 'string' && set.title.trim() ? set.title.trim() : 'Untitled Set';
            return { title, when, where };
          });
        setRecentMap((prev) => ({ ...prev, [hoveredDjId]: recent }));
      } catch {
        setWorksMap((prev) => ({ ...prev, [hoveredDjId]: [] }));
        setRecentMap((prev) => ({ ...prev, [hoveredDjId]: [] }));
      }
    };

    fetchHoverDetails();
  }, [hoveredDjId, worksMap, recentMap]);

  const hoveredGenres = useMemo(() => {
    if (!hoveredDj) return [];
    if (hoveredDj.spotify?.genres?.length) {
      return hoveredDj.spotify.genres.slice(0, 5);
    }
    const bio = hoveredDj.bio || '';
    const match = bio.match(/Spotify genres:\s*(.+)$/i);
    if (!match?.[1]) return [];
    return match[1]
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean)
      .slice(0, 5);
  }, [hoveredDj]);

  const ensureGlowColor = useCallback(async (dj: DJ) => {
    if (avatarGlowMap[dj.id] || inflightGlowTasks.current[dj.id]) {
      return;
    }
    const src = dj.avatarUrl ? getLowResAvatar(dj.avatarUrl) : null;
    if (!src) {
      setAvatarGlowMap((prev) => ({ ...prev, [dj.id]: DEFAULT_GLOW }));
      return;
    }

    inflightGlowTasks.current[dj.id] = true;
    const color = await getAverageGlowColorFromImage(src);
    setAvatarGlowMap((prev) => ({ ...prev, [dj.id]: color }));
    delete inflightGlowTasks.current[dj.id];
  }, [avatarGlowMap]);

  useEffect(() => {
    const loadDJs = async () => {
      try {
        setIsLoading(true);
        setError('');

        if (showCardView) {
          const response = await djAPI.getDJs({
            page,
            limit: 18,
            search: search || undefined,
            sortBy,
            live: true,
          });
          setDJs(response.djs);
          setTotalPages(response.pagination.totalPages);
          return;
        }

        const response = await djAPI.getDJs({
          limit: 60,
          sortBy: 'followerCount',
          live: false,
        });
        setDJs(response.djs);
        setTotalPages(1);

        // Non-blocking incremental refresh: warms DB cache for top DJs.
        djAPI
          .getDJs({
            limit: 18,
            sortBy: 'followerCount',
            live: true,
          })
          .catch(() => null);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load DJs');
      } finally {
        setIsLoading(false);
      }
    };

    loadDJs();
  }, [page, search, sortBy, showCardView]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const clearSearch = () => {
    setSearch('');
    setSearchInput('');
    setPage(1);
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="mx-auto max-w-7xl px-4 py-8 pt-[44px]">
        <div className="mb-8">
          <h1 className="mb-4 bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-4xl font-bold text-transparent">
            DJ 库
          </h1>
        </div>

        <div className="mb-8 space-y-4">
          <form onSubmit={handleSearch} className="flex gap-4">
            <div className="flex-1">
              <Input
                type="text"
                placeholder="搜索 DJ 名称..."
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
              />
            </div>
            <Button type="submit" variant="primary">
              搜索
            </Button>
            {search && (
              <Button type="button" variant="secondary" onClick={clearSearch}>
                清空
              </Button>
            )}
            <Link
              href="/rankings"
              className="inline-flex items-center justify-center rounded-lg border border-border-secondary bg-bg-secondary px-4 py-2 text-sm font-medium text-text-primary transition hover:border-primary-blue"
            >
              DJ 榜单
            </Link>
          </form>

          <div className="flex gap-2">
            <span className="py-2 text-sm text-text-secondary">排序:</span>
            <Button
              variant={sortBy === 'followerCount' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => {
                setPage(1);
                setSortBy('followerCount');
              }}
            >
              热度
            </Button>
            <Button
              variant={sortBy === 'name' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => {
                setPage(1);
                setSortBy('name');
              }}
            >
              名称
            </Button>
            <Button
              variant={sortBy === 'createdAt' ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => {
                setPage(1);
                setSortBy('createdAt');
              }}
            >
              最新
            </Button>
          </div>
        </div>

        {error && (
          <div className="mb-8 rounded-lg border border-red-500 bg-red-500/10 px-4 py-3 text-red-500">
            {error}
          </div>
        )}

        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="text-text-secondary">加载中...</div>
          </div>
        ) : djs.length === 0 ? (
          <div className="py-20 text-center">
            <div className="mb-4 text-6xl">🎧</div>
            <p className="text-text-secondary">暂无 DJ</p>
          </div>
        ) : (
          <>
            {showCardView ? (
              <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                {djs.map((dj) => (
                  <DJCard key={dj.id} dj={dj} />
                ))}
              </div>
            ) : (
              <div className="relative left-1/2 mb-8 h-[72vh] min-h-[580px] w-screen -translate-x-1/2 overflow-hidden bg-[radial-gradient(circle_at_15%_20%,rgba(0,190,255,0.24),transparent_36%),radial-gradient(circle_at_85%_24%,rgba(147,51,234,0.25),transparent_42%),radial-gradient(circle_at_50%_85%,rgba(52,211,153,0.2),transparent_40%),#060914]">
                <div className="absolute -left-24 top-16 h-64 w-64 rounded-full bg-cyan-400/20 blur-3xl" />
                <div className="absolute -right-20 bottom-12 h-80 w-80 rounded-full bg-fuchsia-500/20 blur-3xl" />

                <div className="mx-auto h-full w-full max-w-[1600px] px-4">
                  <DJHeroPreview
                    dj={hoveredDj}
                    representativeWorks={hoveredDj ? worksMap[hoveredDj.id] || [] : []}
                    genres={hoveredGenres}
                    recentPerformances={hoveredDj ? recentMap[hoveredDj.id] || [] : []}
                  />

                  <div className="absolute left-0 right-0 top-0 space-y-2 md:space-y-3">
                    {rows.map((row, rowIndex) => (
                      <div
                        key={`row-${rowIndex}`}
                        className={`marquee-row ${rowIndex % 2 === 1 ? 'marquee-reverse' : ''} marquee-speed-${rowIndex + 1} ${
                          hoveredRowIndex === rowIndex ? 'row-paused' : ''
                        }`}
                      >
                        <div className="marquee-track">
                          {[...Array(8)].flatMap(() => row).map((dj, idx) => (
                            <Link
                              key={`${dj.id}-${rowIndex}-${idx}`}
                              href={`/djs/${dj.id}`}
                              onMouseEnter={() => {
                                ensureGlowColor(dj);
                                setHoveredDjId(dj.id);
                                setHoveredRowIndex(rowIndex);
                              }}
                              onMouseLeave={() => {
                                setHoveredDjId((current) => (current === dj.id ? null : current));
                                setHoveredRowIndex((current) => (current === rowIndex ? null : current));
                              }}
                              className="group mx-2 inline-flex"
                            >
                              <div
                                className={`rounded-full p-[2px] transition-all duration-300 ${
                                  hoveredDjId === dj.id
                                    ? 'relative z-50 scale-125'
                                    : 'hover:scale-110'
                                }`}
                                style={
                                  hoveredDjId === dj.id
                                    ? { boxShadow: `0 0 45px ${avatarGlowMap[dj.id] || DEFAULT_GLOW}` }
                                    : undefined
                                }
                              >
                                <DJAvatar dj={dj} sizeClass="h-14 w-14 md:h-20 md:w-20" />
                              </div>
                            </Link>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

              </div>
            )}

            {showCardView && totalPages > 1 && (
              <div className="flex justify-center gap-2">
                <Button
                  variant="secondary"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page === 1}
                >
                  上一页
                </Button>
                <span className="px-4 py-2 text-text-secondary">
                  第 {page} / {totalPages} 页
                </span>
                <Button
                  variant="secondary"
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                >
                  下一页
                </Button>
              </div>
            )}
          </>
        )}
      </div>

      <style jsx>{`
        .marquee-row {
          position: relative;
          width: 100%;
          overflow: visible;
          white-space: nowrap;
          padding: 18px 0;
          z-index: 1;
        }
        .marquee-track {
          display: inline-flex;
          width: max-content;
          animation: marqueeLeft 38s linear infinite;
          will-change: transform;
        }
        .marquee-reverse .marquee-track {
          animation-name: marqueeRight;
          animation-duration: 42s;
        }
        .row-paused .marquee-track {
          animation-play-state: paused;
        }
        .marquee-speed-1 .marquee-track {
          animation-duration: 34s;
        }
        .marquee-speed-2 .marquee-track {
          animation-duration: 40s;
        }
        .marquee-speed-3 .marquee-track {
          animation-duration: 36s;
        }
        .marquee-speed-4 .marquee-track {
          animation-duration: 44s;
        }
        @keyframes marqueeLeft {
          0% {
            transform: translateX(0);
          }
          100% {
            transform: translateX(-12.5%);
          }
        }
        @keyframes marqueeRight {
          0% {
            transform: translateX(-12.5%);
          }
          100% {
            transform: translateX(0);
          }
        }
      `}</style>
    </div>
  );
}
