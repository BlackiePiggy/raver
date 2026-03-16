'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { eventAPI, Event } from '@/lib/api/event';
import { checkinAPI } from '@/lib/api/checkin';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/Button';

export default function EventDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user, token } = useAuth();
  const [event, setEvent] = useState<Event | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [isCheckinLoading, setIsCheckinLoading] = useState(false);

  useEffect(() => {
    const loadEvent = async () => {
      try {
        setIsLoading(true);
        const data = await eventAPI.getEvent(params.id as string);
        setEvent(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load event');
      } finally {
        setIsLoading(false);
      }
    };

    if (params.id) {
      loadEvent();
    }
  }, [params.id]);

  const handleCheckin = async () => {
    if (!user || !token) {
      router.push('/login');
      return;
    }

    try {
      setIsCheckinLoading(true);
      await checkinAPI.createCheckin(
        {
          eventId: params.id as string,
          type: 'event',
          note: `参加了 ${event?.name}`,
          rating: 5,
        },
        token
      );

      const confirmed = confirm(`✅ 打卡成功！\n\n已成功打卡 ${event?.name}\n\n是否前往查看我的打卡记录？`);
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

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return {
      weekday: date.toLocaleDateString('zh-CN', { weekday: 'long' }),
      date: date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      }),
      time: date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
      }),
    };
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center">
        <div className="text-center">
          <div className="w-16 h-16 border-4 border-primary-blue border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-text-secondary">加载中...</p>
        </div>
      </div>
    );
  }

  if (error || !event) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center px-6">
        <div className="text-center max-w-md">
          <div className="text-8xl mb-6 opacity-20">😕</div>
          <h2 className="text-3xl font-semibold text-text-primary mb-4">活动不存在</h2>
          <p className="text-text-secondary mb-8">{error || '未找到该活动'}</p>
          <Button onClick={() => router.push('/events')}>返回活动列表</Button>
        </div>
      </div>
    );
  }

  const startDate = formatDate(event.startDate);
  const endDate = formatDate(event.endDate);

  return (
    <div className="min-h-screen bg-bg-primary">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 backdrop-blur-apple bg-bg-glass border-b border-border-secondary">
        <div className="max-w-[1400px] mx-auto px-6 h-[44px] flex items-center justify-between">
          <Link href="/" className="text-xl font-semibold text-text-primary hover:text-text-secondary transition-colors">
            Raver
          </Link>
          <button
            onClick={() => router.back()}
            className="text-sm text-text-secondary hover:text-text-primary transition-colors flex items-center gap-2"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            返回
          </button>
        </div>
      </nav>

      {/* Hero Image */}
      <section className="pt-[44px] relative">
        <div className="relative h-[60vh] min-h-[500px] overflow-hidden">
          {event.coverImageUrl ? (
            <>
              <img
                src={event.coverImageUrl}
                alt={event.name}
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-bg-primary via-bg-primary/50 to-transparent"></div>
            </>
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-primary-purple/30 to-primary-blue/30 flex items-center justify-center">
              <span className="text-9xl opacity-20">🎪</span>
            </div>
          )}

          {/* Title Overlay */}
          <div className="absolute bottom-0 left-0 right-0 px-6 pb-12">
            <div className="max-w-[1400px] mx-auto">
              <div className="flex items-end justify-between gap-8">
                <div className="flex-1 animate-fade-in">
                  {event.isVerified && (
                    <span className="inline-flex items-center gap-2 text-sm text-accent-green mb-4 bg-accent-green/10 backdrop-blur-apple px-4 py-2 rounded-full border border-accent-green/30">
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      </svg>
                      官方认证活动
                    </span>
                  )}
                  <h1 className="text-5xl md:text-7xl font-bold text-text-primary mb-4 tracking-tight">
                    {event.name}
                  </h1>
                  {event.city && (
                    <p className="text-xl text-text-secondary flex items-center gap-2">
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      {event.city}, {event.country}
                    </p>
                  )}
                </div>

                {/* CTA Buttons */}
                <div className="hidden md:flex gap-4 animate-slide-up">
                  <Button
                    onClick={handleCheckin}
                    isLoading={isCheckinLoading}
                    size="lg"
                  >
                    打卡签到
                  </Button>
                  {event.ticketUrl && (
                    <a href={event.ticketUrl} target="_blank" rel="noopener noreferrer">
                      <Button variant="secondary" size="lg">
                        购买门票
                      </Button>
                    </a>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Content */}
      <section className="py-16 px-6">
        <div className="max-w-[1400px] mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_400px] gap-12">
            {/* Main Content */}
            <div className="space-y-12">
              {/* Description */}
              {event.description && (
                <div className="animate-fade-in">
                  <h2 className="text-3xl font-semibold text-text-primary mb-6">活动介绍</h2>
                  <p className="text-lg text-text-secondary leading-relaxed whitespace-pre-wrap">
                    {event.description}
                  </p>
                </div>
              )}

              {/* Venue Info */}
              {event.venueName && (
                <div className="animate-fade-in" style={{ animationDelay: '0.1s' }}>
                  <h2 className="text-3xl font-semibold text-text-primary mb-6">场地信息</h2>
                  <div className="bg-bg-elevated rounded-3xl p-8 border border-border-secondary">
                    <div className="space-y-4">
                      <div>
                        <div className="text-sm text-text-tertiary mb-1">场地名称</div>
                        <div className="text-xl text-text-primary font-medium">{event.venueName}</div>
                      </div>
                      {event.venueAddress && (
                        <div>
                          <div className="text-sm text-text-tertiary mb-1">地址</div>
                          <div className="text-lg text-text-secondary">{event.venueAddress}</div>
                        </div>
                      )}
                      {event.city && (
                        <div>
                          <div className="text-sm text-text-tertiary mb-1">城市</div>
                          <div className="text-lg text-text-secondary">{event.city}, {event.country}</div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}

              {/* Mobile CTA */}
              <div className="md:hidden flex flex-col gap-4">
                <Button
                  onClick={handleCheckin}
                  isLoading={isCheckinLoading}
                  size="lg"
                  className="w-full"
                >
                  打卡签到
                </Button>
                {event.ticketUrl && (
                  <a href={event.ticketUrl} target="_blank" rel="noopener noreferrer">
                    <Button variant="secondary" size="lg" className="w-full">
                      购买门票
                    </Button>
                  </a>
                )}
              </div>
            </div>

            {/* Sidebar */}
            <div className="space-y-6">
              {/* Date & Time */}
              <div className="bg-bg-elevated rounded-3xl p-8 border border-border-secondary sticky top-[60px] animate-fade-in">
                <h3 className="text-xl font-semibold text-text-primary mb-6">活动时间</h3>

                <div className="space-y-6">
                  <div>
                    <div className="text-sm text-text-tertiary mb-2">开始时间</div>
                    <div className="text-lg text-text-primary font-medium mb-1">
                      {startDate.date}
                    </div>
                    <div className="text-sm text-text-secondary">
                      {startDate.weekday} · {startDate.time}
                    </div>
                  </div>

                  <div className="h-px bg-border-secondary"></div>

                  <div>
                    <div className="text-sm text-text-tertiary mb-2">结束时间</div>
                    <div className="text-lg text-text-primary font-medium mb-1">
                      {endDate.date}
                    </div>
                    <div className="text-sm text-text-secondary">
                      {endDate.weekday} · {endDate.time}
                    </div>
                  </div>

                  <div className="h-px bg-border-secondary"></div>

                  {/* Status */}
                  <div>
                    <div className="text-sm text-text-tertiary mb-2">活动状态</div>
                    <span className={`inline-block px-4 py-2 rounded-full text-sm font-medium ${
                      event.status === 'upcoming'
                        ? 'bg-accent-green/20 text-accent-green'
                        : event.status === 'ongoing'
                        ? 'bg-primary-blue/20 text-primary-blue'
                        : 'bg-text-tertiary/20 text-text-tertiary'
                    }`}>
                      {event.status === 'upcoming' ? '即将开始' : event.status === 'ongoing' ? '进行中' : '已结束'}
                    </span>
                  </div>

                  {/* Links */}
                  {event.officialWebsite && (
                    <>
                      <div className="h-px bg-border-secondary"></div>
                      <a
                        href={event.officialWebsite}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center justify-between p-4 bg-bg-secondary rounded-2xl hover:bg-bg-tertiary transition-colors group"
                      >
                        <span className="text-text-primary font-medium">官方网站</span>
                        <svg className="w-5 h-5 text-text-tertiary group-hover:text-primary-blue transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                        </svg>
                      </a>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
