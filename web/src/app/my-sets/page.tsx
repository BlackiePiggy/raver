'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getApiUrl } from '@/lib/config';

interface MyTrack {
  id: string;
  createdAt?: string;
}

interface MySet {
  id: string;
  title: string;
  thumbnailUrl?: string;
  createdAt: string;
  dj: { name: string };
  tracks: MyTrack[];
}

const formatDateTime = (value?: string | null) => {
  if (!value) {
    return '未知';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '未知';
  }
  return date.toLocaleString('zh-CN');
};

export default function MySetsPage() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();
  const [sets, setSets] = useState<MySet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    const loadMySets = async () => {
      if (!token) {
        return;
      }
      setLoading(true);
      setError('');
      try {
        const response = await fetch(getApiUrl('/dj-sets/mine'), {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        const data = await response.json().catch(() => []);
        if (!response.ok) {
          throw new Error(data.error || '加载我的上传失败');
        }
        setSets(Array.isArray(data) ? data : []);
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载失败');
      } finally {
        setLoading(false);
      }
    };

    if (user && token) {
      loadMySets();
    }
  }, [user, token]);

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-7xl mx-auto p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-text-primary">我的 DJ Set 上传管理</h1>
            <p className="text-text-secondary mt-1">查看你上传的视频和 tracklist，并进入编辑。</p>
          </div>
          <Link
            href="/upload"
            className="px-4 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white"
          >
            + 新建上传
          </Link>
        </div>

        {loading ? (
          <div className="text-text-secondary">加载中...</div>
        ) : error ? (
          <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red p-3">{error}</div>
        ) : sets.length === 0 ? (
          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-8 text-center">
            <p className="text-text-secondary mb-4">你还没有上传任何 DJ Set。</p>
            <Link href="/upload" className="text-primary-blue hover:text-primary-purple">去上传第一个 Set</Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {sets.map((set) => {
              const tracklistTs = set.tracks
                .map((track) => (track.createdAt ? new Date(track.createdAt).getTime() : NaN))
                .filter((ts) => !Number.isNaN(ts));
              const tracklistUploadedAt =
                tracklistTs.length > 0 ? new Date(Math.min(...tracklistTs)).toISOString() : null;

              return (
                <div key={set.id} className="rounded-xl overflow-hidden border border-bg-tertiary bg-bg-secondary">
                  {set.thumbnailUrl ? (
                    <div className="relative w-full h-44">
                      <Image src={set.thumbnailUrl} alt={set.title} fill className="object-cover" sizes="(max-width:768px) 100vw, 33vw" />
                    </div>
                  ) : (
                    <div className="h-44 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-5xl">🎬</div>
                  )}

                  <div className="p-4">
                    <h3 className="text-lg text-text-primary font-semibold line-clamp-2">{set.title}</h3>
                    <p className="text-sm text-text-secondary mt-1">DJ: {set.dj?.name || 'Unknown DJ'}</p>
                    <p className="text-xs text-text-tertiary mt-3">视频上传时间：{formatDateTime(set.createdAt)}</p>
                    <p className="text-xs text-text-tertiary mt-1">
                      Tracklist 上传时间：{tracklistUploadedAt ? formatDateTime(tracklistUploadedAt) : '暂无'}
                    </p>
                    <p className="text-xs text-text-tertiary mt-1">Track 数量：{set.tracks.length}</p>

                    <div className="mt-4 flex items-center gap-2">
                      <Link
                        href={`/dj-sets/${set.id}`}
                        className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary text-sm"
                      >
                        查看详情
                      </Link>
                      <Link
                        href={`/my-sets/${set.id}/edit`}
                        className="px-3 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white text-sm"
                      >
                        编辑视频与Tracklist
                      </Link>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
