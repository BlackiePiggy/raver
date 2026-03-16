'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { eventAPI, Event } from '@/lib/api/event';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import Navigation from '@/components/Navigation';

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);

  const loadEvents = async () => {
    try {
      setIsLoading(true);
      const response = await eventAPI.getEvents({ page, search: search || undefined });
      setEvents(response.events);
      setTotalPages(response.pagination.totalPages);
      setTotal(response.pagination.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load events');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadEvents();
  }, [page]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    loadEvents();
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return {
      month: date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase(),
      day: date.getDate(),
      year: date.getFullYear(),
      fullDate: date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      }),
    };
  };

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />

      {/* Hero Section */}
      <section className="pt-[88px] pb-12 px-6">
        <div className="max-w-[1200px] mx-auto">
          <div className="text-center mb-12 animate-fade-in">
            <h1 className="text-6xl md:text-7xl font-semibold text-text-primary mb-4 tracking-tight">
              发现精彩活动
            </h1>
            <p className="text-xl text-text-secondary max-w-2xl mx-auto">
              全球顶级电子音乐节和活动，不容错过的电音盛宴
            </p>
          </div>

          {/* Search Bar */}
          <form onSubmit={handleSearch} className="max-w-2xl mx-auto mb-8 animate-slide-up">
            <div className="relative">
              <Input
                type="text"
                placeholder="搜索活动名称、城市或国家..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pr-24 h-14 text-lg"
              />
              <button
                type="submit"
                className="absolute right-2 top-1/2 -translate-y-1/2 px-6 py-2 bg-primary-blue text-white rounded-full text-sm font-medium hover:bg-primary-purple transition-all duration-300"
              >
                搜索
              </button>
            </div>
          </form>

          {/* Stats */}
          <div className="text-center mb-12 animate-fade-in">
            <p className="text-sm text-text-tertiary">
              共找到 <span className="text-text-primary font-semibold">{total}</span> 个活动
            </p>
          </div>
        </div>
      </section>

      {/* Events Grid */}
      <section className="pb-24 px-6">
        <div className="max-w-[1200px] mx-auto">
          {error && (
            <div className="bg-red-500/10 border border-red-500 text-red-500 px-6 py-4 rounded-2xl mb-8 text-center">
              {error}
            </div>
          )}

          {isLoading ? (
            <div className="flex items-center justify-center py-32">
              <div className="text-center">
                <div className="w-12 h-12 border-4 border-primary-blue border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
                <p className="text-text-secondary">加载中...</p>
              </div>
            </div>
          ) : events.length === 0 ? (
            <div className="text-center py-32">
              <div className="text-8xl mb-6 opacity-20">🎪</div>
              <h3 className="text-2xl font-semibold text-text-primary mb-4">暂无活动</h3>
              <p className="text-text-secondary mb-8">试试搜索其他关键词</p>
              <Button onClick={() => { setSearch(''); loadEvents(); }}>
                清除搜索
              </Button>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 gap-8 mb-12">
                {events.map((event, index) => {
                  const date = formatDate(event.startDate);
                  return (
                    <Link key={event.id} href={`/events/${event.id}`}>
                      <div
                        className="group animate-fade-in"
                        style={{ animationDelay: `${index * 0.05}s` }}
                      >
                        <div className="bg-bg-elevated rounded-3xl overflow-hidden border border-border-secondary hover:border-border-primary transition-all duration-500 hover:shadow-apple-lg">
                          <div className="grid grid-cols-1 md:grid-cols-[300px_1fr] gap-0">
                            {/* Image */}
                            <div className="relative aspect-[4/3] md:aspect-auto overflow-hidden">
                              {event.coverImageUrl ? (
                                <img
                                  src={event.coverImageUrl}
                                  alt={event.name}
                                  className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                                />
                              ) : (
                                <div className="w-full h-full bg-gradient-to-br from-primary-purple/20 to-primary-blue/20 flex items-center justify-center">
                                  <span className="text-7xl opacity-30">🎪</span>
                                </div>
                              )}

                              {/* Date Badge */}
                              <div className="absolute top-6 left-6 bg-bg-glass backdrop-blur-apple rounded-2xl p-4 text-center border border-border-secondary">
                                <div className="text-xs text-text-tertiary font-medium mb-1">
                                  {date.month}
                                </div>
                                <div className="text-3xl font-bold text-text-primary">
                                  {date.day}
                                </div>
                              </div>

                              {/* Status Badge */}
                              <div className="absolute bottom-6 left-6">
                                <span className="px-4 py-2 bg-accent-green/20 backdrop-blur-apple text-accent-green rounded-full text-xs font-semibold border border-accent-green/30">
                                  即将开始
                                </span>
                              </div>
                            </div>

                            {/* Content */}
                            <div className="p-8 md:p-10 flex flex-col justify-center">
                              <div className="flex items-start justify-between mb-4">
                                <div className="flex-1">
                                  <h2 className="text-3xl font-semibold text-text-primary mb-3 group-hover:text-primary-blue transition-colors">
                                    {event.name}
                                  </h2>
                                  {event.isVerified && (
                                    <span className="inline-flex items-center gap-1 text-sm text-accent-green">
                                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                                      </svg>
                                      官方认证
                                    </span>
                                  )}
                                </div>
                              </div>

                              {event.description && (
                                <p className="text-text-secondary mb-6 line-clamp-2 leading-relaxed">
                                  {event.description}
                                </p>
                              )}

                              <div className="space-y-3">
                                {event.venueName && (
                                  <div className="flex items-center gap-3 text-text-secondary">
                                    <svg className="w-5 h-5 text-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                                    </svg>
                                    <span>{event.venueName}</span>
                                  </div>
                                )}

                                {event.city && (
                                  <div className="flex items-center gap-3 text-text-secondary">
                                    <svg className="w-5 h-5 text-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                    </svg>
                                    <span>{event.city}, {event.country}</span>
                                  </div>
                                )}

                                <div className="flex items-center gap-3 text-text-secondary">
                                  <svg className="w-5 h-5 text-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                  <span>{date.fullDate}</span>
                                </div>
                              </div>

                              <div className="mt-6 flex items-center gap-4">
                                <span className="text-primary-blue font-medium group-hover:text-primary-purple transition-colors">
                                  查看详情 →
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </Link>
                  );
                })}
              </div>

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-center gap-4">
                  <button
                    onClick={() => setPage(p => Math.max(1, p - 1))}
                    disabled={page === 1}
                    className="px-6 py-3 bg-bg-elevated text-text-primary rounded-full border border-border-secondary hover:border-border-primary disabled:opacity-30 disabled:cursor-not-allowed transition-all duration-300"
                  >
                    上一页
                  </button>
                  <span className="text-text-secondary">
                    第 <span className="text-text-primary font-semibold">{page}</span> / {totalPages} 页
                  </span>
                  <button
                    onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                    disabled={page === totalPages}
                    className="px-6 py-3 bg-bg-elevated text-text-primary rounded-full border border-border-secondary hover:border-border-primary disabled:opacity-30 disabled:cursor-not-allowed transition-all duration-300"
                  >
                    下一页
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </section>
    </div>
  );
}
