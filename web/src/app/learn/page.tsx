'use client';

import Link from 'next/link';
import Navigation from '@/components/Navigation';

export default function LearnPage() {
  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-5xl mx-auto p-6 space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-text-primary">学习</h1>
          <p className="text-text-secondary mt-1">在这里集中查看电音流派知识和历年 DJ 榜单。</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Link href="/genres" className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 hover:border-primary-blue/50 transition-colors">
            <h2 className="text-xl font-semibold text-text-primary">流派树</h2>
            <p className="text-sm text-text-secondary mt-2">从主流 EDM 到细分分支，按树状结构逐层学习。</p>
          </Link>

          <Link href="/rankings" className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 hover:border-primary-purple/50 transition-colors">
            <h2 className="text-xl font-semibold text-text-primary">DJ 榜单</h2>
            <p className="text-sm text-text-secondary mt-2">查看各榜单及历年排名变化。</p>
          </Link>
        </div>
      </div>
    </div>
  );
}
