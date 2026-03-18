'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/Button';
import { useEffect, useState } from 'react';
import { eventAPI } from '@/lib/api/event';
import { djAPI } from '@/lib/api/dj';
import Navigation from '@/components/Navigation';

export default function Home() {
  const { user } = useAuth();
  const [stats, setStats] = useState({
    eventsCount: 0,
    djsCount: 0,
    upcomingEvents: [] as any[],
    topDJs: [] as any[],
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadStats = async () => {
      try {
        const [eventsRes, djsRes] = await Promise.all([
          eventAPI.getEvents({ limit: 3 }),
          djAPI.getDJs({ limit: 4, sortBy: 'followerCount' }),
        ]);

        setStats({
          eventsCount: eventsRes.pagination.total,
          djsCount: djsRes.pagination.total,
          upcomingEvents: eventsRes.events,
          topDJs: djsRes.djs,
        });
      } catch (error) {
        console.error('Failed to load stats:', error);
      } finally {
        setLoading(false);
      }
    };

    loadStats();
  }, []);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN', {
      month: 'short',
      day: 'numeric',
    });
  };

  return (
    <main className="min-h-screen bg-bg-primary">
      <Navigation />

      {/* Hero Section */}
      <section className="pt-[88px] pb-[60px] px-6">
        <div className="max-w-[980px] mx-auto text-center">
          <h1 className="text-display-sm md:text-display font-semibold text-text-primary mb-6 tracking-tight animate-fade-in">
            电子音乐的
            <br />
            全新体验
          </h1>
          <p className="text-2xl md:text-3xl text-text-secondary mb-8 font-normal leading-snug animate-slide-up">
            发现全球精彩活动，关注喜爱的DJ，
            <br />
            记录你的每一个电音瞬间。
          </p>
          <div className="flex gap-4 justify-center items-center animate-scale-in">
            <Link href="/events">
              <button className="px-6 py-3 bg-primary-blue text-white rounded-full text-base font-medium hover:bg-primary-purple transition-all duration-300 shadow-apple hover:shadow-apple-lg">
                探索活动
              </button>
            </Link>
            <Link href="/djs">
              <button className="px-6 py-3 text-primary-blue text-base font-medium hover:text-primary-purple transition-colors">
                了解更多 →
              </button>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-12 px-6 border-y border-border-secondary bg-bg-secondary">
        <div className="max-w-[980px] mx-auto">
          <div className="grid grid-cols-3 gap-8 text-center">
            <div className="animate-fade-in">
              <div className="text-5xl font-semibold text-text-primary mb-2">
                {loading ? '—' : stats.eventsCount}
              </div>
              <div className="text-sm text-text-secondary">精彩活动</div>
            </div>
            <div className="animate-fade-in" style={{ animationDelay: '0.1s' }}>
              <div className="text-5xl font-semibold text-text-primary mb-2">
                {loading ? '—' : stats.djsCount}
              </div>
              <div className="text-sm text-text-secondary">顶级DJ</div>
            </div>
            <div className="animate-fade-in" style={{ animationDelay: '0.2s' }}>
              <div className="text-5xl font-semibold text-text-primary mb-2">
                ∞
              </div>
              <div className="text-sm text-text-secondary">无限可能</div>
            </div>
          </div>
        </div>
      </section>

      {/* Events Section */}
      <section className="py-24 px-6">
        <div className="max-w-[980px] mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-5xl md:text-6xl font-semibold text-text-primary mb-4 tracking-tight">
              即将开始
            </h2>
            <p className="text-xl text-text-secondary">
              不要错过这些精彩的电音盛宴
            </p>
          </div>

          {loading ? (
            <div className="text-center py-20 text-text-tertiary">加载中...</div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {stats.upcomingEvents.map((event, index) => (
                <Link key={event.id} href={`/events/${event.id}`}>
                  <div
                    className="group animate-fade-in"
                    style={{ animationDelay: `${index * 0.1}s` }}
                  >
                    <div className="relative overflow-hidden rounded-2xl bg-bg-elevated border border-border-secondary hover:border-border-primary transition-all duration-500 hover:scale-[1.02]">
                      {event.coverImageUrl ? (
                        <div className="aspect-[4/3] overflow-hidden relative">
                          <Image
                            src={event.coverImageUrl}
                            alt={event.name}
                            fill
                            className="object-cover group-hover:scale-110 transition-transform duration-700"
                            sizes="(max-width: 768px) 100vw, 33vw"
                          />
                        </div>
                      ) : (
                        <div className="aspect-[4/3] bg-gradient-to-br from-primary-purple/20 to-primary-blue/20 flex items-center justify-center">
                          <span className="text-6xl opacity-50">🎪</span>
                        </div>
                      )}
                      <div className="p-6">
                        <div className="text-xs text-text-tertiary mb-2 uppercase tracking-wider">
                          {formatDate(event.startDate)}
                        </div>
                        <h3 className="text-xl font-semibold text-text-primary mb-2 group-hover:text-primary-blue transition-colors">
                          {event.name}
                        </h3>
                        {event.city && (
                          <p className="text-sm text-text-secondary">
                            {event.city}, {event.country}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}

          <div className="text-center mt-12">
            <Link href="/events">
              <button className="text-primary-blue hover:text-primary-purple transition-colors text-lg font-medium">
                查看所有活动 →
              </button>
            </Link>
          </div>
        </div>
      </section>

      {/* DJs Section */}
      <section className="py-24 px-6 bg-bg-secondary">
        <div className="max-w-[980px] mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-5xl md:text-6xl font-semibold text-text-primary mb-4 tracking-tight">
              热门DJ
            </h2>
            <p className="text-xl text-text-secondary">
              关注你喜欢的电子音乐艺术家
            </p>
          </div>

          {loading ? (
            <div className="text-center py-20 text-text-tertiary">加载中...</div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
              {stats.topDJs.map((dj, index) => (
                <Link key={dj.id} href={`/djs/${dj.id}`}>
                  <div
                    className="group text-center animate-fade-in"
                    style={{ animationDelay: `${index * 0.1}s` }}
                  >
                    <div className="mb-4 relative w-full aspect-square">
                      {dj.avatarUrl ? (
                        <Image
                          src={dj.avatarUrl}
                          alt={dj.name}
                          fill
                          className="rounded-2xl object-cover group-hover:scale-105 transition-transform duration-500"
                          sizes="(max-width: 768px) 50vw, 25vw"
                        />
                      ) : (
                        <div className="w-full aspect-square rounded-2xl bg-gradient-to-br from-primary-blue/20 to-accent-cyan/20 flex items-center justify-center group-hover:scale-105 transition-transform duration-500">
                          <span className="text-6xl opacity-50">🎧</span>
                        </div>
                      )}
                    </div>
                    <h3 className="text-lg font-semibold text-text-primary mb-1 group-hover:text-primary-blue transition-colors">
                      {dj.name}
                    </h3>
                    {dj.country && (
                      <p className="text-sm text-text-tertiary mb-2">{dj.country}</p>
                    )}
                    <div className="text-sm text-text-secondary">
                      {dj.followerCount.toLocaleString()} 粉丝
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}

          <div className="text-center mt-12">
            <Link href="/djs">
              <button className="text-primary-blue hover:text-primary-purple transition-colors text-lg font-medium">
                查看所有DJ →
              </button>
            </Link>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-24 px-6">
        <div className="max-w-[980px] mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-5xl md:text-6xl font-semibold text-text-primary mb-4 tracking-tight">
              为电音爱好者
              <br />
              精心打造
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center animate-fade-in">
              <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-primary-purple/20 to-primary-purple/10 flex items-center justify-center">
                <span className="text-3xl">🎪</span>
              </div>
              <h3 className="text-2xl font-semibold text-text-primary mb-3">
                活动资讯
              </h3>
              <p className="text-text-secondary leading-relaxed">
                整合全球电音活动信息，包括Ultra、Tomorrowland等顶级音乐节
              </p>
            </div>

            <div className="text-center animate-fade-in" style={{ animationDelay: '0.1s' }}>
              <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-primary-blue/20 to-primary-blue/10 flex items-center justify-center">
                <span className="text-3xl">🎧</span>
              </div>
              <h3 className="text-2xl font-semibold text-text-primary mb-3">
                DJ库
              </h3>
              <p className="text-text-secondary leading-relaxed">
                收录全球顶级DJ信息，关注你喜欢的艺术家，获取最新动态
              </p>
            </div>

            <div className="text-center animate-fade-in" style={{ animationDelay: '0.2s' }}>
              <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-accent-green/20 to-accent-green/10 flex items-center justify-center">
                <span className="text-3xl">✅</span>
              </div>
              <h3 className="text-2xl font-semibold text-text-primary mb-3">
                打卡集邮
              </h3>
              <p className="text-text-secondary leading-relaxed">
                记录你的电音之旅，收集活动和DJ打卡，分享精彩瞬间
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      {!user && (
        <section className="py-24 px-6 bg-bg-secondary">
          <div className="max-w-[980px] mx-auto text-center">
            <h2 className="text-5xl md:text-6xl font-semibold text-text-primary mb-6 tracking-tight">
              准备好开始了吗？
            </h2>
            <p className="text-xl text-text-secondary mb-10">
              加入RaveHub社区，发现更多精彩内容
            </p>
            <div className="flex gap-4 justify-center">
              <Link href="/register">
                <button className="px-8 py-4 bg-primary-blue text-white rounded-full text-lg font-medium hover:bg-primary-purple transition-all duration-300 shadow-apple hover:shadow-apple-lg">
                  立即注册
                </button>
              </Link>
              <Link href="/login">
                <button className="px-8 py-4 text-primary-blue text-lg font-medium hover:text-primary-purple transition-colors">
                  登录 →
                </button>
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* Footer */}
      <footer className="py-12 px-6 border-t border-border-secondary">
        <div className="max-w-[980px] mx-auto text-center">
          <p className="text-sm text-text-tertiary mb-2">
            Created with ❤️ for the electronic music community
          </p>
          <p className="text-xs text-text-tertiary">
            © 2026 RaveHub. All rights reserved.
          </p>
        </div>
      </footer>
    </main>
  );
}
