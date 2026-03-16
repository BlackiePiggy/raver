'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { djAPI, DJ } from '@/lib/api/dj';
import { followAPI } from '@/lib/api/follow';
import { checkinAPI } from '@/lib/api/checkin';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export default function DJDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user, token } = useAuth();
  const [dj, setDJ] = useState<DJ | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [isFollowing, setIsFollowing] = useState(false);
  const [isFollowLoading, setIsFollowLoading] = useState(false);
  const [isCheckinLoading, setIsCheckinLoading] = useState(false);

  useEffect(() => {
    const loadDJ = async () => {
      try {
        setIsLoading(true);
        const data = await djAPI.getDJ(params.djId as string);
        setDJ(data);

        if (user && token) {
          const status = await followAPI.checkFollowStatus(params.djId as string, token);
          setIsFollowing(status.isFollowing);
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load DJ');
      } finally {
        setIsLoading(false);
      }
    };

    if (params.djId) {
      loadDJ();
    }
  }, [params.djId, user, token]);

  const handleFollow = async () => {
    if (!user || !token) {
      router.push('/login');
      return;
    }

    try {
      setIsFollowLoading(true);
      if (isFollowing) {
        await followAPI.unfollowDJ(params.djId as string, token);
        setIsFollowing(false);
        if (dj) {
          setDJ({ ...dj, followerCount: dj.followerCount - 1 });
        }
      } else {
        await followAPI.followDJ(params.djId as string, token);
        setIsFollowing(true);
        if (dj) {
          setDJ({ ...dj, followerCount: dj.followerCount + 1 });
        }
      }
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to follow/unfollow');
    } finally {
      setIsFollowLoading(false);
    }
  };

  const handleCheckin = async () => {
    if (!user || !token) {
      router.push('/login');
      return;
    }

    try {
      setIsCheckinLoading(true);
      await checkinAPI.createCheckin(
        {
          djId: params.djId as string,
          type: 'dj',
          note: `打卡 ${dj?.name}`,
          rating: 5,
        },
        token
      );

      // 使用更友好的提示
      const confirmed = confirm(`✅ 打卡成功！\n\n已成功打卡 ${dj?.name}\n\n是否前往查看我的打卡记录？`);
      if (confirmed) {
        router.push('/checkins');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : '打卡失败';
      alert(`❌ ${errorMessage}\n\n请稍后重试`);
    } finally {
      setIsCheckinLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <div className="text-text-secondary">加载中...</div>
      </div>
    );
  }

  if (error || !dj) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <Card className="max-w-md">
          <div className="text-center">
            <div className="text-6xl mb-4">😕</div>
            <p className="text-text-secondary mb-4">{error || 'DJ 不存在'}</p>
            <Button onClick={() => router.push('/djs')}>返回 DJ 列表</Button>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <div className="max-w-5xl mx-auto px-4 py-8">
        <Button
          variant="secondary"
          size="sm"
          onClick={() => router.push('/djs')}
          className="mb-6"
        >
          ← 返回
        </Button>

        {dj.bannerUrl ? (
          <div className="h-64 rounded-xl overflow-hidden mb-8">
            <img
              src={dj.bannerUrl}
              alt={dj.name}
              className="w-full h-full object-cover"
            />
          </div>
        ) : (
          <div className="h-64 rounded-xl bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center mb-8">
            <span className="text-9xl">🎧</span>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <div className="flex items-start gap-6 mb-8">
              {dj.avatarUrl ? (
                <img
                  src={dj.avatarUrl}
                  alt={dj.name}
                  className="w-32 h-32 rounded-full object-cover border-4 border-primary-purple"
                />
              ) : (
                <div className="w-32 h-32 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-5xl">
                  🎧
                </div>
              )}

              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <h1 className="text-4xl font-bold text-text-primary">
                    {dj.name}
                  </h1>
                  {dj.isVerified && (
                    <span className="text-accent-green text-2xl">✓</span>
                  )}
                </div>

                {dj.country && (
                  <div className="flex items-center text-text-secondary mb-4">
                    <span className="mr-2">🌍</span>
                    <span>{dj.country}</span>
                  </div>
                )}

                <div className="flex items-center text-text-secondary">
                  <span className="mr-2">👥</span>
                  <span className="text-2xl font-bold text-primary-purple">
                    {dj.followerCount.toLocaleString()}
                  </span>
                  <span className="ml-2">粉丝</span>
                </div>
              </div>
            </div>

            {dj.bio && (
              <Card className="mb-8">
                <h2 className="text-2xl font-bold text-text-primary mb-4">简介</h2>
                <p className="text-text-secondary whitespace-pre-wrap">{dj.bio}</p>
              </Card>
            )}

            <Card>
              <h2 className="text-2xl font-bold text-text-primary mb-4">音乐平台</h2>
              <div className="space-y-3">
                {dj.spotifyId && (
                  <a
                    href={`https://open.spotify.com/artist/${dj.spotifyId}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 bg-accent-green/10 hover:bg-accent-green/20 rounded-lg transition-colors"
                  >
                    <span className="text-2xl">🎵</span>
                    <span className="text-accent-green font-medium">在 Spotify 上收听</span>
                  </a>
                )}

                {dj.appleMusicId && (
                  <a
                    href={`https://music.apple.com/artist/${dj.appleMusicId}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 bg-primary-blue/10 hover:bg-primary-blue/20 rounded-lg transition-colors"
                  >
                    <span className="text-2xl">🎵</span>
                    <span className="text-primary-blue font-medium">在 Apple Music 上收听</span>
                  </a>
                )}

                {dj.soundcloudUrl && (
                  <a
                    href={dj.soundcloudUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 p-3 bg-primary-blue/10 hover:bg-primary-blue/20 rounded-lg transition-colors"
                  >
                    <span className="text-2xl">☁️</span>
                    <span className="text-primary-blue font-medium">在 SoundCloud 上收听</span>
                  </a>
                )}
              </div>
            </Card>
          </div>

          <div className="space-y-4">
            <Card>
              <h3 className="text-xl font-bold text-text-primary mb-4">快速操作</h3>

              <div className="space-y-3">
                <Button
                  variant="primary"
                  size="lg"
                  className="w-full"
                  onClick={() => router.push(`/djs/${params.djId}/sets`)}
                >
                  🎵 查看DJ Sets
                </Button>

                <Button
                  variant={isFollowing ? "secondary" : "primary"}
                  size="lg"
                  className="w-full"
                  onClick={handleFollow}
                  isLoading={isFollowLoading}
                >
                  {isFollowing ? '已关注' : '关注'}
                </Button>

                <Button
                  variant="secondary"
                  size="lg"
                  className="w-full"
                  onClick={handleCheckin}
                  isLoading={isCheckinLoading}
                >
                  打卡
                </Button>

                <Button variant="secondary" size="lg" className="w-full">
                  分享
                </Button>
              </div>
            </Card>

            {(dj.instagramUrl || dj.twitterUrl) && (
              <Card>
                <h3 className="text-xl font-bold text-text-primary mb-4">社交媒体</h3>
                <div className="space-y-3">
                  {dj.instagramUrl && (
                    <a
                      href={dj.instagramUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-3 p-2 hover:bg-bg-tertiary rounded-lg transition-colors"
                    >
                      <span className="text-xl">📷</span>
                      <span className="text-text-secondary">Instagram</span>
                    </a>
                  )}

                  {dj.twitterUrl && (
                    <a
                      href={dj.twitterUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-3 p-2 hover:bg-bg-tertiary rounded-lg transition-colors"
                    >
                      <span className="text-xl">🐦</span>
                      <span className="text-text-secondary">Twitter</span>
                    </a>
                  )}
                </div>
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
