'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getApiUrl } from '@/lib/config';

interface MySet {
  id: string;
  title: string;
  thumbnailUrl?: string;
  createdAt: string;
  dj?: { name: string };
  tracks: { id: string }[];
}

interface MyEvent {
  id: string;
  name: string;
  coverImageUrl?: string | null;
  createdAt: string;
  city?: string | null;
  country?: string | null;
  startDate: string;
  lineupSlots?: { id: string }[];
}

type PublishType = 'djset' | 'event';

const formatDateTime = (value?: string | null) => {
  if (!value) return '未知';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '未知';
  return d.toLocaleString('zh-CN');
};

export default function MyPublishesPage() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();

  const [activeType, setActiveType] = useState<PublishType>('djset');
  const [sets, setSets] = useState<MySet[]>([]);
  const [events, setEvents] = useState<MyEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [deletingKey, setDeletingKey] = useState('');

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }
    const params = new URLSearchParams(window.location.search);
    if (params.get('type') === 'event') {
      setActiveType('event');
    }
  }, []);

  useEffect(() => {
    const loadAll = async () => {
      if (!token) return;
      setLoading(true);
      setError('');
      try {
        const [setsRes, eventsRes] = await Promise.all([
          fetch(getApiUrl('/dj-sets/mine'), { headers: { Authorization: `Bearer ${token}` } }),
          fetch(getApiUrl('/events/mine'), { headers: { Authorization: `Bearer ${token}` } }),
        ]);

        const setsData = await setsRes.json().catch(() => []);
        const eventsData = await eventsRes.json().catch(() => ({ events: [] }));

        if (!setsRes.ok) {
          throw new Error(setsData.error || '加载我的 DJ Sets 失败');
        }
        if (!eventsRes.ok) {
          throw new Error(eventsData.error || '加载我的活动失败');
        }

        setSets(Array.isArray(setsData) ? setsData : []);
        setEvents(Array.isArray(eventsData.events) ? eventsData.events : []);
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载失败');
      } finally {
        setLoading(false);
      }
    };

    if (user && token) {
      loadAll();
    }
  }, [user, token]);

  const rightTitle = useMemo(() => (activeType === 'djset' ? 'DJ Set 发布列表' : '活动发布列表'), [activeType]);

  const handleDeleteSet = async (id: string, title: string) => {
    if (!token) return;
    const ok = window.confirm(`确认删除 DJ Set「${title}」吗？此操作不可恢复。`);
    if (!ok) return;

    setDeletingKey(`djset-${id}`);
    try {
      const response = await fetch(getApiUrl(`/dj-sets/${id}`), {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || '删除 DJ Set 失败');
      }
      setSets((prev) => prev.filter((set) => set.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : '删除 DJ Set 失败');
    } finally {
      setDeletingKey('');
    }
  };

  const handleDeleteEvent = async (id: string, name: string) => {
    if (!token) return;
    const ok = window.confirm(`确认删除活动「${name}」吗？此操作不可恢复。`);
    if (!ok) return;

    setDeletingKey(`event-${id}`);
    try {
      const response = await fetch(getApiUrl(`/events/${id}`), {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || '删除活动失败');
      }
      setEvents((prev) => prev.filter((event) => event.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : '删除活动失败');
    } finally {
      setDeletingKey('');
    }
  };

  if (!user) return null;

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-7xl mx-auto px-4 py-6">
        <h1 className="text-3xl font-bold text-text-primary mb-2">我的发布</h1>
        <p className="text-text-secondary mb-6">左侧切换内容类型，右侧查看发布列表，点击即可进入编辑。</p>

        <div className="grid grid-cols-1 lg:grid-cols-[260px_1fr] gap-5">
          <aside className="rounded-xl border border-bg-tertiary bg-bg-secondary p-4 h-fit lg:sticky lg:top-[64px]">
            <p className="text-sm text-text-secondary mb-3">发布内容导航</p>
            <div className="space-y-2">
              <button
                type="button"
                onClick={() => setActiveType('djset')}
                className={`w-full text-left px-3 py-2 rounded-lg border text-sm transition-colors ${
                  activeType === 'djset'
                    ? 'bg-primary-blue/20 border-primary-blue text-primary-blue'
                    : 'bg-bg-tertiary border-bg-primary text-text-secondary hover:text-text-primary'
                }`}
              >
                DJ Set（{sets.length}）
              </button>
              <button
                type="button"
                onClick={() => setActiveType('event')}
                className={`w-full text-left px-3 py-2 rounded-lg border text-sm transition-colors ${
                  activeType === 'event'
                    ? 'bg-primary-purple/20 border-primary-purple text-primary-purple'
                    : 'bg-bg-tertiary border-bg-primary text-text-secondary hover:text-text-primary'
                }`}
              >
                活动（{events.length}）
              </button>
            </div>
            <div className="mt-4 pt-4 border-t border-bg-primary space-y-2">
              <Link href="/upload" className="block text-sm text-primary-blue hover:text-primary-purple">+ 发布 DJ Set</Link>
              <Link href="/events/publish" className="block text-sm text-primary-blue hover:text-primary-purple">+ 发布活动</Link>
            </div>
          </aside>

          <section className="rounded-xl border border-bg-tertiary bg-bg-secondary p-4 md:p-5">
            <h2 className="text-xl font-semibold text-text-primary mb-4">{rightTitle}</h2>

            {loading ? (
              <div className="text-text-secondary">加载中...</div>
            ) : error ? (
              <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red px-3 py-2 text-sm">{error}</div>
            ) : activeType === 'djset' ? (
              sets.length === 0 ? (
                <p className="text-text-tertiary">暂无 DJ Set 发布内容。</p>
              ) : (
                <div className="space-y-3">
                  {sets.map((set) => (
                    <div key={set.id} className="rounded-lg border border-bg-primary bg-bg-tertiary/50 p-3 hover:border-primary-blue/50">
                      <div className="flex items-center gap-3">
                        <Link href={`/my-sets/${set.id}/edit`} className="flex min-w-0 flex-1 items-center gap-3">
                          {set.thumbnailUrl ? (
                            <div className="relative h-16 w-28 rounded-md overflow-hidden border border-bg-primary">
                              <Image src={set.thumbnailUrl} alt={set.title} fill className="object-cover" sizes="112px" />
                            </div>
                          ) : (
                            <div className="h-16 w-28 rounded-md bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">🎧</div>
                          )}
                          <div className="min-w-0 flex-1">
                            <p className="text-text-primary font-medium truncate">{set.title}</p>
                            <p className="text-xs text-text-tertiary mt-1">DJ: {set.dj?.name || 'Unknown'} · 曲目: {set.tracks.length}</p>
                            <p className="text-xs text-text-tertiary mt-1">发布时间: {formatDateTime(set.createdAt)}</p>
                          </div>
                          <span className="text-sm text-primary-blue whitespace-nowrap">编辑 →</span>
                        </Link>
                        <button
                          type="button"
                          onClick={() => handleDeleteSet(set.id, set.title)}
                          disabled={deletingKey === `djset-${set.id}`}
                          className="shrink-0 rounded-md border border-accent-red/40 bg-accent-red/10 px-3 py-1.5 text-xs text-accent-red hover:bg-accent-red/20 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {deletingKey === `djset-${set.id}` ? '删除中...' : '删除'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )
            ) : events.length === 0 ? (
              <p className="text-text-tertiary">暂无活动发布内容。</p>
            ) : (
              <div className="space-y-3">
                {events.map((event) => (
                  <div key={event.id} className="rounded-lg border border-bg-primary bg-bg-tertiary/50 p-3 hover:border-primary-purple/50">
                    <div className="flex items-center gap-3">
                      <Link href={`/events/my/${event.id}/edit`} className="flex min-w-0 flex-1 items-center gap-3">
                        {event.coverImageUrl ? (
                          <div className="relative h-16 w-28 rounded-md overflow-hidden border border-bg-primary">
                            <Image src={event.coverImageUrl} alt={event.name} fill className="object-cover" sizes="112px" />
                          </div>
                        ) : (
                          <div className="h-16 w-28 rounded-md bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">🎪</div>
                        )}
                        <div className="min-w-0 flex-1">
                          <p className="text-text-primary font-medium truncate">{event.name}</p>
                          <p className="text-xs text-text-tertiary mt-1">{event.city || 'Unknown'}{event.country ? `, ${event.country}` : ''} · 阵容时段: {event.lineupSlots?.length || 0}</p>
                          <p className="text-xs text-text-tertiary mt-1">活动时间: {formatDateTime(event.startDate)} · 发布时间: {formatDateTime(event.createdAt)}</p>
                        </div>
                        <span className="text-sm text-primary-purple whitespace-nowrap">编辑 →</span>
                      </Link>
                      <button
                        type="button"
                        onClick={() => handleDeleteEvent(event.id, event.name)}
                        disabled={deletingKey === `event-${event.id}`}
                        className="shrink-0 rounded-md border border-accent-red/40 bg-accent-red/10 px-3 py-1.5 text-xs text-accent-red hover:bg-accent-red/20 disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {deletingKey === `event-${event.id}` ? '删除中...' : '删除'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
