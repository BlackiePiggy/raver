'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import { EventCatalogItem } from '@/features/admin-content/catalog/api';
import { archiveAdminApi, ArchiveYearSummaryItem } from '@/features/admin-content/archive/api';

const PAGE_SIZE = 24;

const formatDateRange = (startDate: string, endDate: string): string => {
  const formatter = new Intl.DateTimeFormat('zh-CN', {
    month: 'short',
    day: 'numeric',
  });
  return `${formatter.format(new Date(startDate))} - ${formatter.format(new Date(endDate))}`;
};

export default function ArchiveYearCenterPageClient() {
  const [years, setYears] = useState<ArchiveYearSummaryItem[]>([]);
  const [selectedYear, setSelectedYear] = useState<number | null>(null);
  const [items, setItems] = useState<EventCatalogItem[]>([]);
  const [page, setPage] = useState(1);
  const [isLoadingYears, setIsLoadingYears] = useState(true);
  const [isLoadingEvents, setIsLoadingEvents] = useState(false);
  const [error, setError] = useState('');
  const [cacheMessage, setCacheMessage] = useState('年份摘要由服务端缓存层承接，适合低频回看。');

  useEffect(() => {
    const loadYears = async () => {
      try {
        setIsLoadingYears(true);
        const response = await archiveAdminApi.fetchYearSummary();
        setYears(response.items);
        setSelectedYear(response.items[0]?.year ?? null);
        setCacheMessage(
          response.cache?.hit
            ? '年份摘要已命中服务端缓存，适合运营回看。'
            : '年份摘要已从摘要层刷新，避免旧工具式全量加载。'
        );
      } catch (nextError) {
        setError(nextError instanceof Error ? nextError.message : '年份摘要加载失败');
      } finally {
        setIsLoadingYears(false);
      }
    };

    void loadYears();
  }, []);

  const loadEvents = useCallback(async () => {
    if (!selectedYear) return;
    try {
      setIsLoadingEvents(true);
      const response = await archiveAdminApi.fetchEventsByYear({
        year: selectedYear,
        page,
        limit: PAGE_SIZE,
      });
      setItems(response.items);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '年份活动加载失败');
    } finally {
      setIsLoadingEvents(false);
    }
  }, [page, selectedYear]);

  useEffect(() => {
    void loadEvents();
  }, [loadEvents]);

  return (
    <AdminContentLayout
      title="Archive 年份中心"
      eyebrow="Admin / Content Workspace / Archive Center"
      description="这里先把 Festival Viewer 里最常用的年份式活动回看迁回统一后台。先看年份摘要，再按年读取活动摘要，而不是一次性全量加载整个 Archive。"
      actions={
        <>
          <Link href="/admin/content/legacy-tools/archive" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110]">
            返回旧 Archive 桥接页
          </Link>
          <Link href="/admin/content/events/catalog" className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110]">
            活动目录中心
          </Link>
        </>
      }
    >
      <section className="grid gap-5 xl:grid-cols-[0.7fr_1.3fr]">
        <div className="admin-reference-card p-6">
          <div className="text-sm text-black/42">Year Summary</div>
          <h2 className="mt-2 text-2xl font-semibold text-[#071110]">年份总览</h2>
          <p className="mt-3 text-sm leading-6 text-black/48">{cacheMessage}</p>

          <div className="mt-5">
            {isLoadingYears ? (
              <div className="py-10 text-sm text-black/48">年份摘要加载中…</div>
            ) : (
              <div className="space-y-3">
                {years.map((yearItem) => {
                  const active = yearItem.year === selectedYear;
                  return (
                    <button
                      key={yearItem.year}
                      type="button"
                      onClick={() => {
                        setSelectedYear(yearItem.year);
                        setPage(1);
                      }}
                      className={`w-full rounded-2xl border px-4 py-4 text-left transition-colors ${
                        active
                          ? 'border-[#dceabf] bg-[#edf7f2]'
                          : 'border-[#e8eceb] bg-[#f8f9f8]'
                      }`}
                    >
                      <div className="text-lg font-semibold text-[#071110]">{yearItem.year}</div>
                      <div className="mt-1 text-sm text-black/48">{yearItem.count.toLocaleString()} 场活动</div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        <div className="admin-reference-card p-6">
          <div className="flex items-end justify-between gap-4">
            <div>
              <div className="text-sm text-black/42">Year Events</div>
              <h2 className="mt-2 text-2xl font-semibold text-[#071110]">{selectedYear ? `${selectedYear} 年活动摘要` : '选择年份'}</h2>
            </div>
            {selectedYear ? (
              <div className="text-sm text-black/48">当前页：{page}</div>
            ) : null}
          </div>

          {error ? (
            <div className="mt-4 rounded-2xl border border-[#efdad8] bg-[#f7e3e0] px-4 py-3 text-sm text-[#6a3530]">
              {error}
            </div>
          ) : null}

          <div className="mt-5">
            {isLoadingEvents ? (
              <div className="py-20 text-center text-sm text-black/48">年份活动加载中…</div>
            ) : !selectedYear ? (
              <div className="py-20 text-center text-sm text-black/48">先从左侧选择年份。</div>
            ) : items.length === 0 ? (
              <div className="py-20 text-center text-sm text-black/48">这一年暂时没有活动摘要。</div>
            ) : (
              <div className="space-y-4">
                {items.map((item) => (
                  <div key={item.id} className="grid gap-4 rounded-3xl border border-[#e8eceb] bg-[#fcfcfb] p-4 lg:grid-cols-[140px_minmax(0,1fr)_200px]">
                    <div className="relative overflow-hidden rounded-2xl border border-[#e8eceb] bg-[#f5f5f7]">
                      {item.coverImageUrl ? (
                        <Image
                          src={item.coverImageUrl}
                          alt={item.name}
                          width={280}
                          height={180}
                          className="h-full min-h-[110px] w-full object-cover"
                        />
                      ) : (
                        <div className="flex h-full min-h-[110px] items-center justify-center bg-[linear-gradient(135deg,#f7efda,#edf7f2)] text-sm text-black/45">
                          暂无封面
                        </div>
                      )}
                    </div>

                    <div className="min-w-0">
                      <h3 className="text-xl font-semibold text-[#071110]">{item.name}</h3>
                      <p className="mt-2 text-sm leading-6 text-black/48">
                        {item.city || '未知城市'} / {item.country || '未知国家'} · {formatDateRange(item.startDate, item.endDate)}
                      </p>
                      <p className="mt-2 text-sm leading-6 text-black/48">
                        主办方：{item.wikiFestival?.name || item.organizerName || '未绑定正式主办方'}
                      </p>
                    </div>

                    <div className="admin-reference-soft-card grid gap-3 p-4">
                      <Link href={`/admin/content/events/${item.id}/edit`} className="rounded-full bg-[#071110] px-4 py-3 text-center text-sm font-semibold text-white">
                        编辑活动
                      </Link>
                      <Link href={`/events/${item.id}`} className="rounded-full border border-[#e8eceb] bg-white px-4 py-3 text-center text-sm font-semibold text-[#071110]">
                        打开详情
                      </Link>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="mt-6 flex justify-end gap-3 border-t border-white/5 pt-6">
            <button
              type="button"
              disabled={page <= 1}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              上一页
            </button>
            <button
              type="button"
              disabled={items.length < PAGE_SIZE}
              onClick={() => setPage((current) => current + 1)}
              className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-40"
            >
              下一页
            </button>
          </div>
        </div>
      </section>
    </AdminContentLayout>
  );
}
