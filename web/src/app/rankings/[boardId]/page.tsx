'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { DJ, djAPI } from '@/lib/api/dj';
import { getApiUrl } from '@/lib/config';

type RankingItem = {
  rank: number;
  name: string;
};

type DisplayItem = RankingItem & {
  delta: number | null;
  dj: DJ | null;
};

const BOARD_META: Record<string, { title: string; years: number[] }> = {
  djmag: { title: 'DJ MAG TOP 100', years: [2022, 2023, 2024, 2025] },
  dongye: { title: '东野 DJ 榜', years: [2024, 2025] },
};

const normalizeName = (name: string) => name.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]/g, '');

const getHighResAvatar = (url: string) =>
  url
    .replace('ab6761610000f178', 'ab6761610000e5eb')
    .replace('ab67616100005174', 'ab6761610000e5eb')
    .replace('ab67616d00004851', 'ab67616d0000b273')
    .replace('ab67616d00001e02', 'ab67616d0000b273');

const parseRankingText = (text: string): RankingItem[] =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)\.\s+(.+)$/);
      if (!match) {
        return null;
      }
      return { rank: Number(match[1]), name: match[2].trim() };
    })
    .filter((item): item is RankingItem => item !== null)
    .sort((a, b) => a.rank - b.rank);

function RankingCard({ item }: { item: DisplayItem }) {
  const [failed, setFailed] = useState(false);
  const imageUrl = item.dj?.avatarUrl ? getHighResAvatar(item.dj.avatarUrl) : null;

  const inner = (
    <article className="overflow-hidden rounded-xl bg-bg-secondary p-2 shadow-md transition duration-300 hover:-translate-y-1 hover:scale-[1.02] hover:shadow-[0_12px_40px_rgba(29,110,255,0.28)]">
      <div className="relative aspect-square w-full overflow-hidden bg-bg-tertiary">
        {imageUrl && !failed ? (
          <img
            src={imageUrl}
            alt={item.name}
            loading="lazy"
            referrerPolicy="no-referrer"
            className="h-full w-full object-cover"
            onError={() => setFailed(true)}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[linear-gradient(140deg,#1f2937,#0f172a,#111827)] text-xl font-black text-white/80">
            {item.name.slice(0, 2).toUpperCase()}
          </div>
        )}
        <div className="absolute bottom-0 left-0 bg-[#ef1a1a] px-3 py-2">
          <span className="text-4xl font-black leading-none text-white">{item.rank}</span>
        </div>
      </div>
      <div className="bg-bg-secondary pb-2 pt-3">
        <h3 className="truncate text-2xl font-black uppercase tracking-tight text-text-primary">{item.name}</h3>
        <p className="mt-1 text-lg font-black text-text-primary">
          {item.delta === null
            ? '—'
            : item.delta > 0
              ? `▲ ${item.delta}`
              : item.delta < 0
                ? `▼ ${Math.abs(item.delta)}`
                : '• 0'}
        </p>
      </div>
    </article>
  );

  if (!item.dj?.id) {
    return inner;
  }
  return <Link href={`/djs/${item.dj.id}`}>{inner}</Link>;
}

export default function RankingDetailPage() {
  const params = useParams<{ boardId: string }>();
  const boardId = params.boardId;
  const board = BOARD_META[boardId];
  const [year, setYear] = useState<number>(board?.years[board.years.length - 1] || 2025);
  const [ranking, setRanking] = useState<RankingItem[]>([]);
  const [previousRanking, setPreviousRanking] = useState<RankingItem[]>([]);
  const [djPool, setDjPool] = useState<DJ[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!board) {
      return;
    }
    setYear(board.years[board.years.length - 1]);
  }, [boardId, board]);

  useEffect(() => {
    if (!board) {
      setError('未知榜单');
      setLoading(false);
      return;
    }

    const run = async () => {
      try {
        setLoading(true);
        setError('');

        const yearList = board.years;
        const previousYear = yearList[yearList.indexOf(year) - 1];
        const [currentText, previousText] = await Promise.all([
          fetch(`/rankings/${boardId}/${year}.txt`).then((res) => (res.ok ? res.text() : Promise.resolve(''))),
          previousYear
            ? fetch(`/rankings/${boardId}/${previousYear}.txt`).then((res) => (res.ok ? res.text() : Promise.resolve('')))
            : Promise.resolve(''),
        ]);

        const currentParsed = parseRankingText(currentText);
        const previousParsed = parseRankingText(previousText);
        setRanking(currentParsed);
        setPreviousRanking(previousParsed);

        const namesToEnsure = [...new Set([...currentParsed, ...previousParsed].map((item) => item.name))];
        if (namesToEnsure.length > 0) {
          fetch(getApiUrl('/djs/ensure'), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ names: namesToEnsure }),
          }).catch(() => null);
        }

        const djRes = await djAPI.getDJs({ limit: 400, live: false, sortBy: 'followerCount' });
        setDjPool(djRes.djs);
      } catch (e) {
        setError(e instanceof Error ? e.message : '加载榜单失败');
      } finally {
        setLoading(false);
      }
    };

    run();
  }, [boardId, board, year]);

  const djMap = useMemo(() => {
    const map: Record<string, DJ> = {};
    djPool.forEach((dj) => {
      map[normalizeName(dj.name)] = dj;
    });
    return map;
  }, [djPool]);

  const previousRankMap = useMemo(() => {
    const map: Record<string, number> = {};
    previousRanking.forEach((item) => {
      map[normalizeName(item.name)] = item.rank;
    });
    return map;
  }, [previousRanking]);

  const displayRanking = useMemo<DisplayItem[]>(() => {
    if (!board) {
      return [];
    }
    const firstYear = board.years[0];
    return ranking.map((item) => {
      const key = normalizeName(item.name);
      const prevRank = previousRankMap[key];
      return {
        ...item,
        delta: year === firstYear || prevRank === undefined ? null : prevRank - item.rank,
        dj: djMap[key] || null,
      };
    });
  }, [ranking, previousRankMap, djMap, year, board]);

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="mx-auto max-w-[1600px] px-4 pb-16 pt-[60px]">
        <header className="mb-8 rounded-2xl border border-bg-tertiary bg-bg-secondary px-5 py-5">
          <Link href="/rankings" className="text-xs text-text-tertiary hover:text-text-primary">
            ← 返回榜单入口
          </Link>
          <h1 className="mt-2 text-4xl font-black text-text-primary">{board?.title || '榜单详情'}</h1>
          {board && (
            <p className="mt-2 text-sm text-text-secondary">
              升降根据上一年同名 DJ 名次自动计算。{year === board.years[0] ? '当前首年不显示升降。' : ''}
            </p>
          )}
          {board && (
            <div className="mt-4 flex flex-wrap gap-2">
              {board.years.map((itemYear) => (
                <button
                  key={itemYear}
                  type="button"
                  onClick={() => setYear(itemYear)}
                  className={`rounded-lg px-3 py-2 text-sm ${
                    year === itemYear
                      ? 'bg-primary-blue text-white'
                      : 'border border-bg-tertiary bg-bg-primary text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {itemYear}
                </button>
              ))}
            </div>
          )}
        </header>

        {error && (
          <div className="mb-4 rounded-lg border border-accent-red/40 bg-accent-red/10 px-3 py-2 text-sm text-accent-red">
            {error}
          </div>
        )}

        {loading ? (
          <div className="py-14 text-center text-text-secondary">加载中...</div>
        ) : (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {displayRanking.map((item) => (
              <RankingCard key={`${boardId}-${year}-${item.rank}-${item.name}`} item={item} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
