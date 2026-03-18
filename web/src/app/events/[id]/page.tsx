'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import { eventAPI, Event } from '@/lib/api/event';
import { checkinAPI } from '@/lib/api/checkin';
import { useAuth } from '@/contexts/AuthContext';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';

const SCHEDULE_TZ = 'Asia/Shanghai';
const TIME_COL_WIDTH = 68;
const PX_PER_MIN = 1.08;

type DayGroup = {
  key: string;
  label: string;
  slots: NonNullable<Event['lineupSlots']>;
  stages: Array<{
    stageName: string;
    slots: NonNullable<Event['lineupSlots']>;
  }>;
};

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

  // Festival day rule: 00:00-11:59 归属前一日，避免跨午夜场次被拆成“第三天”
  const getFestivalDayKey = (dateString: string) => {
    const localText = new Date(dateString).toLocaleString('sv-SE', {
      timeZone: SCHEDULE_TZ,
      hour12: false,
    });
    const [datePart, timePart] = localText.split(' ');
    const hour = Number(timePart.split(':')[0] || '0');

    if (hour >= 12) {
      return datePart;
    }

    const [y, m, d] = datePart.split('-').map(Number);
    const prev = new Date(Date.UTC(y, m - 1, d));
    prev.setUTCDate(prev.getUTCDate() - 1);
    return new Intl.DateTimeFormat('sv-SE', {
      timeZone: 'UTC',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(prev);
  };

  const formatSlotTime = (dateString: string) =>
    new Date(dateString).toLocaleTimeString('zh-CN', {
      timeZone: SCHEDULE_TZ,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });

  const toMs = (dateString: string) => new Date(dateString).getTime();
  const floorToHour = (ms: number) => {
    const d = new Date(ms);
    d.setMinutes(0, 0, 0);
    return d.getTime();
  };
  const ceilToHour = (ms: number) => {
    const d = new Date(ms);
    if (d.getMinutes() !== 0 || d.getSeconds() !== 0 || d.getMilliseconds() !== 0) {
      d.setHours(d.getHours() + 1);
    }
    d.setMinutes(0, 0, 0);
    return d.getTime();
  };

  const formatDayLabel = (dateString: string) =>
    new Date(dateString).toLocaleDateString('zh-CN', {
      timeZone: SCHEDULE_TZ,
      month: 'long',
      day: 'numeric',
      weekday: 'long',
    });

  const dayGroups: DayGroup[] = React.useMemo(() => {
    if (!event?.lineupSlots || event.lineupSlots.length === 0) {
      return [];
    }

    const sorted = [...event.lineupSlots].sort(
      (a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime()
    );
    const map = new Map<string, NonNullable<Event['lineupSlots']>>();
    for (const slot of sorted) {
      const key = getFestivalDayKey(slot.startTime);
      if (!map.has(key)) {
        map.set(key, []);
      }
      map.get(key)!.push(slot);
    }

    const entries = Array.from(map.entries());
    return entries.map(([key, slots], index) => {
      const stageMap = new Map<string, NonNullable<Event['lineupSlots']>>();
      for (const slot of slots) {
        const stageName = (slot.stageName || '未命名舞台').trim() || '未命名舞台';
        if (!stageMap.has(stageName)) {
          stageMap.set(stageName, []);
        }
        stageMap.get(stageName)!.push(slot);
      }

      return {
        key,
        label: `Day ${index + 1} · ${formatDayLabel(slots[0].startTime)}`,
        slots,
        stages: Array.from(stageMap.entries()).map(([stageName, stageSlots]) => ({
          stageName,
          slots: stageSlots.sort((a, b) => toMs(a.startTime) - toMs(b.startTime)),
        })),
      };
    });
  }, [event?.lineupSlots]);

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
      <Navigation />

      {/* Hero Image */}
      <section className="pt-[44px] relative">
        <div className="relative h-[60vh] min-h-[500px] overflow-hidden">
          {event.coverImageUrl ? (
            <>
              <Image
                src={event.coverImageUrl}
                alt={event.name}
                fill
                className="object-cover"
                sizes="100vw"
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
                  {event.eventType && (
                    <div className="mb-3">
                      <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-primary-purple/20 text-primary-purple border border-primary-purple/40">
                        {event.eventType}
                      </span>
                    </div>
                  )}
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

              {event.lineupImageUrl && (
                <div className="animate-fade-in">
                  <h2 className="text-3xl font-semibold text-text-primary mb-6">活动阵容图</h2>
                  <div className="w-full rounded-3xl overflow-hidden border border-border-secondary bg-black/20">
                    <img
                      src={event.lineupImageUrl}
                      alt={`${event.name} lineup`}
                      className="block w-full h-auto object-contain"
                      loading="lazy"
                      referrerPolicy="no-referrer"
                    />
                  </div>
                </div>
              )}

              {event.lineupSlots && event.lineupSlots.length > 0 && (
                <div className="animate-fade-in">
                  <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
                    <h2 className="text-3xl font-semibold text-text-primary">参演DJ时段</h2>
                    <button
                      type="button"
                      onClick={() => router.push(`/events/${event.id}/routine`)}
                      className="px-4 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white text-sm"
                    >
                      去制定我的路线
                    </button>
                  </div>
                  <div className="space-y-6">
                    {dayGroups.map((group) => (
                      <div
                        key={group.key}
                        className="rounded-3xl bg-gradient-to-br from-transparent via-bg-secondary/25 to-transparent p-3 md:p-4"
                      >
                        <div className="flex items-center justify-between gap-3 mb-4">
                          <h3 className="text-lg md:text-xl font-semibold text-text-primary">{group.label}</h3>
                          <span className="text-xs px-2.5 py-1 rounded-full border border-primary-blue/40 text-primary-blue bg-primary-blue/10">
                            {group.slots.length} Sets
                          </span>
                        </div>

                        {(() => {
                          const stageNames = group.stages.map((stage) => stage.stageName);
                          const minStart = Math.min(...group.slots.map((s) => toMs(s.startTime)));
                          const maxEnd = Math.max(...group.slots.map((s) => toMs(s.endTime)));
                          const axisStart = floorToHour(minStart);
                          const axisEnd = ceilToHour(maxEnd);
                          const totalMinutes = Math.max((axisEnd - axisStart) / 60000, 60);
                          const axisHeight = totalMinutes * PX_PER_MIN;
                          const stageWidthPercent = stageNames.length > 0 ? 100 / stageNames.length : 100;
                          const hours = Array.from({ length: Math.floor(totalMinutes / 60) + 1 }).map(
                            (_, i) => axisStart + i * 3600000
                          );

                          return (
                            <div className="rounded-2xl bg-bg-primary/15">
                              <div className="relative w-full">
                                <div className="flex border-b border-border-secondary">
                                  <div
                                    className="shrink-0 p-2 text-xs text-text-tertiary bg-bg-secondary/70 border-r border-border-secondary"
                                    style={{ width: TIME_COL_WIDTH }}
                                  >
                                    Time
                                  </div>
                                  {stageNames.map((stageName) => (
                                    <div
                                      key={`${group.key}-head-${stageName}`}
                                      className="shrink-0 p-2 text-sm font-semibold text-text-primary bg-bg-secondary/70 border-r border-border-secondary last:border-r-0"
                                      style={{ width: `calc((100% - ${TIME_COL_WIDTH}px) / ${stageNames.length || 1})` }}
                                    >
                                      {stageName}
                                    </div>
                                  ))}
                                </div>

                                <div className="flex relative" style={{ height: axisHeight }}>
                                  <div
                                    className="shrink-0 border-r border-border-secondary bg-bg-secondary/40"
                                    style={{ width: TIME_COL_WIDTH, height: axisHeight }}
                                  >
                                    {hours.map((hourMs) => {
                                      const top = ((hourMs - axisStart) / 60000) * PX_PER_MIN;
                                      return (
                                        <div
                                          key={`${group.key}-time-${hourMs}`}
                                          className="absolute left-0 text-[11px] text-text-tertiary px-2"
                                          style={{ top: Math.max(top - 8, 0) }}
                                        >
                                          {new Date(hourMs).toLocaleTimeString('zh-CN', {
                                            timeZone: SCHEDULE_TZ,
                                            hour: '2-digit',
                                            minute: '2-digit',
                                            hour12: false,
                                          })}
                                        </div>
                                      );
                                    })}
                                  </div>

                                  <div className="relative" style={{ width: `calc(100% - ${TIME_COL_WIDTH}px)`, height: axisHeight }}>
                                    {stageNames.map((stageName, idx) => (
                                      <div
                                        key={`${group.key}-col-${stageName}`}
                                        className="absolute top-0 bottom-0 border-r border-border-secondary/40"
                                        style={{ left: `${idx * stageWidthPercent}%`, width: `${stageWidthPercent}%` }}
                                      />
                                    ))}
                                    {hours.map((hourMs) => {
                                      const top = ((hourMs - axisStart) / 60000) * PX_PER_MIN;
                                      return (
                                        <div
                                          key={`${group.key}-line-${hourMs}`}
                                          className="absolute left-0 right-0 border-t border-border-secondary/50"
                                          style={{ top }}
                                        />
                                      );
                                    })}

                                    {group.slots.map((slot, idx) => {
                                      const stageName = (slot.stageName || '未命名舞台').trim() || '未命名舞台';
                                      const stageIndex = stageNames.findIndex((s) => s === stageName);
                                      if (stageIndex < 0) return null;

                                      const djName = slot.djName || slot.dj?.name || 'Unknown DJ';
                                      const fallbackLetter = djName.slice(0, 1).toUpperCase();
                                      const bgImage = slot.dj?.bannerUrl || slot.dj?.avatarUrl || null;
                                      const top = ((toMs(slot.startTime) - axisStart) / 60000) * PX_PER_MIN + 2;
                                      const height = Math.max(((toMs(slot.endTime) - toMs(slot.startTime)) / 60000) * PX_PER_MIN - 4, 50);
                                      const left = `calc(${stageIndex * stageWidthPercent}% + 6px)`;
                                      const width = `calc(${stageWidthPercent}% - 12px)`;

                                      const cardClassName = `absolute rounded-xl border border-border-secondary bg-bg-elevated/95 p-2 overflow-hidden ${slot.dj?.id ? 'cursor-pointer hover:border-primary-blue/60 hover:-translate-y-[1px] transition-all duration-200' : ''}`;
                                      const cardContent = (
                                        <>
                                          {bgImage && (
                                            <div
                                              className="absolute inset-0 bg-cover bg-center scale-110"
                                              style={{ backgroundImage: `url(${bgImage})` }}
                                            />
                                          )}
                                          <div className="absolute inset-0 bg-gradient-to-br from-black/70 via-black/55 to-black/75" />
                                          <div className="relative z-10 flex items-start gap-2">
                                            {slot.dj?.avatarUrl ? (
                                              <div className="relative h-9 w-9 rounded-full overflow-hidden border border-primary-blue/50 shrink-0">
                                                <Image
                                                  src={slot.dj.avatarUrl}
                                                  alt={djName}
                                                  fill
                                                  className="object-cover"
                                                  sizes="36px"
                                                />
                                              </div>
                                            ) : (
                                              <div className="h-9 w-9 rounded-full shrink-0 border border-primary-purple/50 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-white text-sm font-semibold">
                                                {fallbackLetter}
                                              </div>
                                            )}
                                            <div className="min-w-0">
                                              <p className="text-sm font-semibold text-white truncate">{djName}</p>
                                              <p className="text-[11px] text-white/80">
                                                {formatSlotTime(slot.startTime)} - {formatSlotTime(slot.endTime)}
                                              </p>
                                            </div>
                                          </div>
                                        </>
                                      );

                                      if (slot.dj?.id) {
                                        return (
                                          <Link
                                            key={`${slot.id || idx}`}
                                            href={`/djs/${slot.dj.id}`}
                                            className={cardClassName}
                                            style={{ top, left, width, height }}
                                            title={`查看 ${djName} 详情`}
                                          >
                                            {cardContent}
                                          </Link>
                                        );
                                      }

                                      return (
                                        <div
                                          key={`${slot.id || idx}`}
                                          className={cardClassName}
                                          style={{ top, left, width, height }}
                                        >
                                          {cardContent}
                                        </div>
                                      );
                                    })}
                                  </div>
                                </div>
                              </div>
                            </div>
                          );
                        })()}
                      </div>
                    ))}
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
                <h3 className="text-xl font-semibold text-text-primary mb-4">活动信息</h3>

                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                      <div className="text-xs text-text-tertiary mb-1">开始时间</div>
                      <div className="text-sm text-text-primary font-medium">{startDate.date}</div>
                      <div className="text-xs text-text-secondary">{startDate.time}</div>
                    </div>
                    <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                      <div className="text-xs text-text-tertiary mb-1">结束时间</div>
                      <div className="text-sm text-text-primary font-medium">{endDate.date}</div>
                      <div className="text-xs text-text-secondary">{endDate.time}</div>
                    </div>
                  </div>

                  <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                    <div className="flex items-center justify-between gap-2">
                      <div className="text-xs text-text-tertiary">活动状态</div>
                      <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium ${
                        event.status === 'upcoming'
                          ? 'bg-accent-green/20 text-accent-green'
                          : event.status === 'ongoing'
                          ? 'bg-primary-blue/20 text-primary-blue'
                          : 'bg-text-tertiary/20 text-text-tertiary'
                      }`}>
                        {event.status === 'upcoming' ? '即将开始' : event.status === 'ongoing' ? '进行中' : '已结束'}
                      </span>
                    </div>
                  </div>

                  {(event.venueName || event.venueAddress || event.city) && (
                    <>
                      <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                        <div className="text-xs text-text-tertiary mb-1.5">场地信息</div>
                        {event.venueName && (
                          <p className="text-sm text-text-primary leading-snug">{event.venueName}</p>
                        )}
                        {event.venueAddress && (
                          <p className="mt-1 text-sm text-text-secondary leading-snug">{event.venueAddress}</p>
                        )}
                        {event.city && (
                          <p className="mt-1 text-sm text-text-tertiary">
                            {event.city}{event.country ? `, ${event.country}` : ''}
                          </p>
                        )}
                      </div>
                    </>
                  )}

                  {(Array.isArray(event.ticketTiers) && event.ticketTiers.length > 0) || event.ticketNotes ? (
                    <>
                      <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                        <div className="text-xs text-text-tertiary mb-1.5">票价信息</div>
                        {Array.isArray(event.ticketTiers) && event.ticketTiers.length > 0 && (
                          <div className="space-y-1 mb-1">
                            {event.ticketTiers.map((tier, index) => (
                              <div key={tier.id || `${tier.name}-${index}`} className="text-sm text-text-primary">
                                {tier.name} - {(tier.currency || event.ticketCurrency || 'CNY')} {tier.price}
                              </div>
                            ))}
                          </div>
                        )}
                        {event.ticketNotes && (
                          <div className="text-sm text-text-secondary">{event.ticketNotes}</div>
                        )}
                      </div>
                    </>
                  ) : null}

                  {event.organizerName && (
                    <>
                      <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                        <div className="text-xs text-text-tertiary mb-2">发布方</div>
                        {event.organizer?.id ? (
                          <Link href={`/users/${event.organizer.id}`} className="inline-flex items-center gap-2 rounded-lg border border-bg-primary bg-bg-secondary px-3 py-2 hover:border-primary-blue/50 transition-colors">
                            {event.organizer.avatarUrl ? (
                              <div className="relative h-8 w-8 rounded-full overflow-hidden border border-bg-primary">
                                <Image
                                  src={event.organizer.avatarUrl}
                                  alt={event.organizer.displayName || event.organizer.username}
                                  fill
                                  className="object-cover"
                                  sizes="32px"
                                />
                              </div>
                            ) : (
                              <div className="h-8 w-8 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xs text-white">
                                {(event.organizer.displayName || event.organizer.username || 'U').slice(0, 1).toUpperCase()}
                              </div>
                            )}
                            <span className="text-text-primary">
                              {event.organizer.displayName || event.organizer.username || event.organizerName}
                            </span>
                          </Link>
                        ) : (
                          <div className="text-text-primary">{event.organizerName}</div>
                        )}
                      </div>
                    </>
                  )}

                  {/* Links */}
                  {event.officialWebsite && (
                    <>
                      <a
                        href={event.officialWebsite}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center justify-between p-3 bg-bg-secondary rounded-xl border border-bg-primary hover:bg-bg-tertiary transition-colors group"
                      >
                        <span className="text-sm text-text-primary font-medium">官方网站</span>
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
