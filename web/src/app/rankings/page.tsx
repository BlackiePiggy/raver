'use client';

import Link from 'next/link';
import Navigation from '@/components/Navigation';

const rankingBoards = [
  {
    id: 'djmag',
    title: 'DJ MAG TOP 100',
    subtitle: '全球电子音乐最有影响力榜单之一',
    years: '2014 - 2025',
  },
  {
    id: 'dongye',
    title: '东野 DJ 榜',
    subtitle: '中文圈 DJ 热度与影响力榜单',
    years: '2024 - 2025',
  },
];

export default function RankingsIndexPage() {
  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="mx-auto max-w-6xl px-4 pb-16 pt-[60px]">
        <header className="mb-8 rounded-2xl border border-bg-tertiary bg-bg-secondary px-5 py-5">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-text-tertiary">Ranking Directory</p>
          <h1 className="mt-2 text-4xl font-black text-text-primary">DJ 榜单入口</h1>
          <p className="mt-2 text-sm text-text-secondary">先选择榜单，再进入对应榜单的历年详情页面。</p>
        </header>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {rankingBoards.map((board) => (
            <Link
              key={board.id}
              href={`/rankings/${board.id}`}
              className="group rounded-2xl border border-bg-tertiary bg-bg-secondary p-5 transition duration-300 hover:-translate-y-1 hover:border-primary-blue/70 hover:shadow-[0_16px_40px_rgba(29,110,255,0.22)]"
            >
              <h2 className="text-2xl font-black text-text-primary">{board.title}</h2>
              <p className="mt-2 text-sm text-text-secondary">{board.subtitle}</p>
              <p className="mt-4 text-xs uppercase tracking-[0.2em] text-text-tertiary">{board.years}</p>
              <p className="mt-4 text-sm font-semibold text-primary-blue group-hover:text-primary-purple">进入榜单详情 →</p>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
