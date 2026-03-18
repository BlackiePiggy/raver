'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import { djAPI, DJ } from '@/lib/api/dj';
import { followAPI } from '@/lib/api/follow';
import { checkinAPI } from '@/lib/api/checkin';
import { useAuth } from '@/contexts/AuthContext';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

const getHighResAvatar = (url: string) =>
  url
    .replace('ab6761610000f178', 'ab6761610000e5eb')
    .replace('ab67616100005174', 'ab6761610000e5eb')
    .replace('ab67616d00004851', 'ab67616d0000b273')
    .replace('ab67616d00001e02', 'ab67616d0000b273');

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
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center">
          <div className="text-text-secondary">加载中...</div>
        </div>
      </div>
    );
  }

  if (error || !dj) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center">
          <Card className="max-w-md">
            <div className="text-center">
              <div className="text-6xl mb-4">😕</div>
              <p className="text-text-secondary mb-4">{error || 'DJ 不存在'}</p>
              <Button onClick={() => router.push('/djs')}>返回 DJ 列表</Button>
            </div>
          </Card>
        </div>
      </div>
    );
  }

  const heroImageUrl = dj.bannerUrl || (dj.avatarUrl ? getHighResAvatar(dj.avatarUrl) : null);

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="max-w-6xl mx-auto px-4 py-8 pt-[60px]">
        <Button
          variant="secondary"
          size="sm"
          onClick={() => router.push('/djs')}
          className="mb-6"
        >
          ← 返回
        </Button>

        <section className="relative rounded-2xl overflow-hidden border border-bg-tertiary mb-10">
          <div className="relative w-full aspect-[4/3]">
            {heroImageUrl ? (
              <Image
                src={heroImageUrl}
                alt={dj.name}
                fill
                className="object-cover"
                sizes="(max-width: 1200px) 100vw, 1200px"
                priority
              />
            ) : (
              <div className="w-full h-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">
                <span className="text-9xl">🎧</span>
              </div>
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-bg-primary via-bg-primary/65 to-transparent" />
          </div>

          <div className="absolute left-6 bottom-8 md:left-10 md:bottom-10">
            <div className="flex items-center gap-3 mb-3">
              {dj.isVerified && <span className="text-accent-green text-xl">✓ Verified Artist</span>}
              {dj.country && (
                <span className="px-2 py-1 text-xs rounded-full bg-bg-glass border border-border-secondary text-text-secondary">
                  {dj.country}
                </span>
              )}
            </div>
            <h1
              className="text-5xl md:text-7xl leading-[0.95] text-text-primary font-black tracking-tight"
              style={{ fontFamily: "'Circular Std','SpotifyMixUI','Helvetica Neue',Arial,sans-serif" }}
            >
              {dj.name}
            </h1>
            <p className="mt-3 text-sm md:text-base text-text-secondary">
              {dj.followerCount.toLocaleString()} 关注
            </p>
          </div>
        </section>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
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
