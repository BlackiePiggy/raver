'use client';

import Link from 'next/link';
import Navigation from '@/components/Navigation';

export default function NewPublishPage() {
  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-4xl mx-auto p-6 space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-text-primary">新建发布</h1>
          <p className="text-text-secondary mt-1">选择你要发布的内容类型。</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Link href="/upload" className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 hover:border-primary-blue/50 transition-colors">
            <h2 className="text-xl font-semibold text-text-primary">发布 DJ Set</h2>
            <p className="text-sm text-text-secondary mt-2">上传视频链接、封面与 tracklist。</p>
          </Link>

          <Link href="/events/publish" className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 hover:border-primary-purple/50 transition-colors">
            <h2 className="text-xl font-semibold text-text-primary">发布活动</h2>
            <p className="text-sm text-text-secondary mt-2">发布活动封面、阵容与演出时段。</p>
          </Link>
        </div>
      </div>
    </div>
  );
}
