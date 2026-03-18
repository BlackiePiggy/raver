'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import { DJSetAPI } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import Navigation from '@/components/Navigation';

export default function DJSetsPage() {
  const params = useParams();
  const router = useRouter();
  const [djSets, setDjSets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [djName, setDjName] = useState('');

  useEffect(() => {
    const fetchDJSets = async () => {
      try {
        const data = await DJSetAPI.getDJSetsByDJ(params.djId as string);
        setDjSets(data);
        if (data.length > 0) {
          setDjName(data[0].dj.name);
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };

    if (params.djId) {
      fetchDJSets();
    }
  }, [params.djId]);

  if (loading) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <div className="text-text-secondary text-xl">加载中...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />

      <div className="pt-[44px] max-w-7xl mx-auto px-4 py-8">
        <Button
          variant="secondary"
          size="sm"
          onClick={() => router.push(`/djs/${params.djId}`)}
          className="mb-6"
        >
          ← 返回DJ详情
        </Button>

        <div className="mb-8">
          <h1 className="text-4xl font-bold text-text-primary mb-2">
            {djName ? `${djName} 的 DJ Sets` : 'DJ Sets'}
          </h1>
          <p className="text-text-secondary">
            共 {djSets.length} 个视频表演
          </p>
        </div>

        {djSets.length === 0 ? (
          <div className="text-center py-16">
            <div className="text-6xl mb-4">🎵</div>
            <p className="text-text-secondary text-lg mb-6">
              该DJ还没有上传任何Sets
            </p>
            <Button
              variant="primary"
              onClick={() => router.push('/upload')}
            >
              上传第一个Set
            </Button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {djSets.map((set) => (
              <Link
                key={set.id}
                href={`/dj-sets/${set.id}`}
                className="bg-bg-secondary rounded-xl overflow-hidden hover:scale-105 hover:shadow-2xl transition-all duration-300 border border-bg-tertiary"
              >
                {set.thumbnailUrl ? (
                  <div className="relative w-full h-48">
                    <Image
                      src={set.thumbnailUrl}
                      alt={set.title}
                      fill
                      className="object-cover"
                      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                    />
                  </div>
                ) : (
                  <div className="w-full h-48 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">
                    <span className="text-6xl">🎧</span>
                  </div>
                )}
                <div className="p-5">
                  <h2 className="text-xl font-semibold text-text-primary mb-2 line-clamp-2">
                    {set.title}
                  </h2>
                  <p className="text-text-secondary mb-3">{set.dj.name}</p>
                  {set.venue && (
                    <div className="flex items-center text-text-secondary text-sm mb-3">
                      <span className="mr-2">📍</span>
                      <span>{set.venue}</span>
                    </div>
                  )}
                  {set.eventName && (
                    <div className="flex items-center text-text-secondary text-sm mb-3">
                      <span className="mr-2">🎪</span>
                      <span>{set.eventName}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-4 text-sm text-text-secondary pt-3 border-t border-bg-tertiary">
                    <span className="flex items-center gap-1">
                      <span>🕒</span>
                      <span>{new Date(set.createdAt).toLocaleDateString('zh-CN')}</span>
                    </span>
                    <span className="flex items-center gap-1">
                      <span>🎵</span>
                      <span>{set.tracks.length} 首歌</span>
                    </span>
                    {set.viewCount > 0 && (
                      <span className="flex items-center gap-1">
                        <span>👁️</span>
                        <span>{set.viewCount}</span>
                      </span>
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
