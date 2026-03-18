'use client';

import React, { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { checkinAPI, Checkin } from '@/lib/api/checkin';
import { useAuth } from '@/contexts/AuthContext';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export default function MyCheckinsPage() {
  const router = useRouter();
  const { user, token } = useAuth();
  const [checkins, setCheckins] = useState<Checkin[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<'all' | 'event' | 'dj'>('all');

  const loadCheckins = useCallback(async () => {
    if (!token) return;

    try {
      setIsLoading(true);
      const response = await checkinAPI.getMyCheckins(
        token,
        1,
        filter === 'all' ? undefined : filter
      );
      setCheckins(response.checkins);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load checkins');
    } finally {
      setIsLoading(false);
    }
  }, [token, filter]);

  useEffect(() => {
    if (!user) {
      router.push('/login');
      return;
    }

    loadCheckins();
  }, [user, router, loadCheckins]);

  const handleDelete = async (id: string) => {
    if (!token || !confirm('确定要删除这条打卡记录吗？')) return;

    try {
      await checkinAPI.deleteCheckin(id, token);
      setCheckins(checkins.filter(c => c.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete checkin');
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="max-w-5xl mx-auto px-4 py-8 pt-[60px]">
        <div className="mb-8">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
            我的打卡
          </h1>
          <p className="text-text-secondary">记录你的电音之旅</p>
        </div>

        <div className="mb-6 flex gap-2">
          <Button
            variant={filter === 'all' ? 'primary' : 'secondary'}
            size="sm"
            onClick={() => setFilter('all')}
          >
            全部
          </Button>
          <Button
            variant={filter === 'event' ? 'primary' : 'secondary'}
            size="sm"
            onClick={() => setFilter('event')}
          >
            活动打卡
          </Button>
          <Button
            variant={filter === 'dj' ? 'primary' : 'secondary'}
            size="sm"
            onClick={() => setFilter('dj')}
          >
            DJ打卡
          </Button>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500 text-red-500 px-4 py-3 rounded-lg mb-8">
            {error}
          </div>
        )}

        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="text-center">
              <div className="animate-spin text-6xl mb-4">⏳</div>
              <div className="text-text-secondary">加载中...</div>
            </div>
          </div>
        ) : checkins.length === 0 ? (
          <div className="text-center py-20">
            <div className="text-8xl mb-6 animate-bounce">✅</div>
            <h3 className="text-2xl font-bold text-text-primary mb-4">还没有打卡记录</h3>
            <p className="text-text-secondary mb-8">开始你的电音之旅，记录每一个精彩瞬间</p>
            <div className="flex gap-4 justify-center">
              <Button onClick={() => router.push('/events')} size="lg">
                🎪 去活动打卡
              </Button>
              <Button variant="secondary" onClick={() => router.push('/djs')} size="lg">
                🎧 去DJ打卡
              </Button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {checkins.map((checkin) => (
              <Card key={checkin.id} className="hover:border-primary-purple transition-all">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-3">
                      <div className={`text-4xl ${checkin.type === 'event' ? 'animate-pulse' : ''}`}>
                        {checkin.type === 'event' ? '🎪' : '🎧'}
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <h3 className="text-xl font-bold text-text-primary">
                            {checkin.type === 'event' ? checkin.event?.name : checkin.dj?.name}
                          </h3>
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            checkin.type === 'event'
                              ? 'bg-primary-purple/20 text-primary-purple'
                              : 'bg-primary-blue/20 text-primary-blue'
                          }`}>
                            {checkin.type === 'event' ? '活动' : 'DJ'}
                          </span>
                        </div>
                        <p className="text-sm text-text-tertiary flex items-center gap-2">
                          <span>📅</span>
                          {formatDate(checkin.createdAt)}
                        </p>
                      </div>
                    </div>

                    {checkin.note && (
                      <div className="bg-bg-tertiary rounded-lg p-3 mb-3">
                        <p className="text-text-secondary text-sm">{checkin.note}</p>
                      </div>
                    )}

                    {checkin.rating && (
                      <div className="flex items-center gap-1 mb-2">
                        {Array.from({ length: 5 }).map((_, i) => (
                          <span
                            key={i}
                            className={`text-lg ${i < checkin.rating! ? 'text-yellow-500' : 'text-gray-600'}`}
                          >
                            ⭐
                          </span>
                        ))}
                      </div>
                    )}

                    {checkin.type === 'event' && checkin.event?.city && (
                      <p className="text-sm text-text-tertiary flex items-center gap-1">
                        <span>📍</span>
                        {checkin.event.city}, {checkin.event.country}
                      </p>
                    )}

                    {checkin.type === 'dj' && checkin.dj?.country && (
                      <p className="text-sm text-text-tertiary flex items-center gap-1">
                        <span>🌍</span>
                        {checkin.dj.country}
                      </p>
                    )}
                  </div>

                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => handleDelete(checkin.id)}
                    className="ml-4"
                  >
                    🗑️ 删除
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
