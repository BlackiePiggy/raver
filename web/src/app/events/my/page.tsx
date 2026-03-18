'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { eventAPI, Event } from '@/lib/api/event';

export default function MyPublishedEventsPage() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    const loadMyEvents = async () => {
      if (!token) {
        return;
      }
      setLoading(true);
      setError('');
      try {
        const data = await eventAPI.getMyEvents(token);
        setEvents(data.events || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载我的活动失败');
      } finally {
        setLoading(false);
      }
    };

    if (user && token) {
      loadMyEvents();
    }
  }, [user, token]);

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-6xl mx-auto p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-text-primary">我的发布活动</h1>
            <p className="text-text-secondary mt-1">查看并修改你发布过的活动内容。</p>
          </div>
          <Link
            href="/events/publish"
            className="px-4 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white"
          >
            + 发布新活动
          </Link>
        </div>

        {loading ? (
          <div className="text-text-secondary">加载中...</div>
        ) : error ? (
          <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red px-4 py-3">{error}</div>
        ) : events.length === 0 ? (
          <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-10 text-center">
            <p className="text-text-secondary mb-4">你还没有发布过活动。</p>
            <Link href="/events/publish" className="text-primary-blue hover:text-primary-purple">去发布第一个活动</Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {events.map((event) => (
              <div key={event.id} className="rounded-xl overflow-hidden border border-bg-tertiary bg-bg-secondary">
                {event.coverImageUrl ? (
                  <div className="relative w-full h-44">
                    <Image src={event.coverImageUrl} alt={event.name} fill className="object-cover" sizes="(max-width:768px) 100vw, 33vw" />
                  </div>
                ) : (
                  <div className="h-44 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-5xl">🎪</div>
                )}

                <div className="p-4">
                  <h3 className="text-lg font-semibold text-text-primary line-clamp-2">{event.name}</h3>
                  <p className="text-xs text-text-tertiary mt-2">发布时间：{new Date(event.createdAt).toLocaleString('zh-CN')}</p>
                  <p className="text-xs text-text-tertiary mt-1">活动时间：{new Date(event.startDate).toLocaleString('zh-CN')}</p>

                  <div className="mt-4 flex items-center gap-2">
                    <Link href={`/events/${event.id}`} className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary text-sm">
                      查看
                    </Link>
                    <Link href={`/events/my/${event.id}/edit`} className="px-3 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white text-sm">
                      编辑
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
