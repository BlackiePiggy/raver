'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminContentLayout from '@/components/admin/AdminContentLayout';
import {
  catalogGovernanceApi,
  CatalogGovernanceResourceStatus,
} from '@/features/admin-content/catalog-governance/api';

const formatDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(value));
};

const formatDuration = (value?: number): string => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) return '未配置';
  const minutes = Math.round(value / 60000);
  if (minutes < 1) return `${Math.round(value / 1000)} 秒`;
  return `${minutes} 分钟`;
};

const scopeLabel = (scope?: string): string => {
  if (scope === 'memory') return '内存热缓存';
  if (scope === 'disk') return '磁盘快照';
  return '实时摘要';
};

export default function CatalogCacheGovernancePageClient() {
  const [items, setItems] = useState<CatalogGovernanceResourceStatus[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshingKey, setRefreshingKey] = useState<string>('');
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const loadAll = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');
      const nextItems = await catalogGovernanceApi.inspectAll();
      setItems(nextItems);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '目录缓存治理信息加载失败');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const summary = useMemo(() => {
    const cacheHits = items.filter((item) => item.cache?.hit).length;
    const diskBacked = items.filter((item) => item.cache?.scope === 'disk').length;
    return {
      total: items.length,
      cacheHits,
      diskBacked,
    };
  }, [items]);

  const handleRefresh = async (key: CatalogGovernanceResourceStatus['key']) => {
    try {
      setRefreshingKey(key);
      setError('');
      setSuccessMessage('');
      const result = await catalogGovernanceApi.refreshResource(key);
      setItems((current) => current.map((item) => (item.key === key ? result : item)));
      setSuccessMessage(`${result.label} 已完成手动预热刷新。`);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : '手动刷新摘要失败');
    } finally {
      setRefreshingKey('');
    }
  };

  return (
    <AdminContentLayout
      title="目录缓存治理"
      eyebrow="Admin / Content Workspace / Catalog Cache Governance"
      description="这里不是再去直接看全量库，而是管理统一后台目录层的摘要缓存策略。当前采用服务端内存热缓存 + 磁盘快照兜底 + 前端本地 TTL，先把高频后台查询压到一个可控、可观察、可手动预热的层。"
      actions={
        <>
          <Link href="/admin/content/events/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            活动目录中心
          </Link>
          <Link href="/admin/content/djs/catalog" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
            DJ 目录中心
          </Link>
          <button
            type="button"
            onClick={() => void loadAll()}
            className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white"
          >
            刷新治理面板
          </button>
        </>
      }
    >
      {error ? (
        <section className="rounded-3xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-200">
          {error}
        </section>
      ) : null}

      {successMessage ? (
        <section className="rounded-3xl border border-primary-blue/30 bg-primary-blue/10 p-4 text-sm text-text-primary">
          {successMessage}
        </section>
      ) : null}

      <section className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
          <div className="text-sm text-text-secondary">Governance Strategy</div>
          <h2 className="mt-2 text-2xl font-semibold">商用后台更稳的低压目录层</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {[
              '目录页只读分页摘要，不在每次进入后台时直接扫描全量重数据。',
              '服务端先命中内存热缓存，重启后再落回磁盘快照，降低冷启动压力。',
              '管理台可手动预热重点摘要，让运营在活动高峰前先把常用目录加热。',
            ].map((item) => (
              <div key={item} className="rounded-2xl border border-border-secondary bg-bg-tertiary/60 px-4 py-3 text-sm leading-6">
                {item}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-border-secondary bg-[linear-gradient(180deg,rgba(255,255,255,0.05),rgba(255,255,255,0.02)),radial-gradient(circle_at_top_left,rgba(209,171,84,0.16),transparent_35%),radial-gradient(circle_at_bottom_right,rgba(64,147,255,0.14),transparent_45%)] p-6">
          <div className="text-sm text-text-secondary">Governance Snapshot</div>
          <h2 className="mt-2 text-2xl font-semibold">治理快照</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-text-secondary">
            <p>治理资源：{summary.total} 个</p>
            <p>当前命中缓存：{summary.cacheHits} 个</p>
            <p>磁盘快照兜底：{summary.diskBacked} 个</p>
            <p>适用场景：全量目录、年份回看、迁移期后台低频检索</p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-border-secondary bg-bg-secondary p-6">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="text-sm text-text-secondary">Cache Resources</div>
            <h2 className="mt-2 text-2xl font-semibold">摘要缓存资源</h2>
            <p className="mt-2 text-sm leading-6 text-text-secondary">
              当前优先治理活动目录、DJ 目录和 Archive 年份摘要。后续如果接 Redis 或 DB snapshot，也优先在这一层升级，而不是让页面直接加重查询。
            </p>
          </div>
        </div>

        <div className="mt-5 space-y-4">
          {isLoading ? (
            <div className="py-16 text-center text-sm text-text-secondary">治理资源加载中…</div>
          ) : (
            items.map((item) => (
              <div key={item.key} className="grid gap-4 rounded-3xl border border-border-secondary bg-bg-tertiary/35 p-5 xl:grid-cols-[1.2fr_0.9fr_220px]">
                <div>
                  <div className="text-sm text-text-secondary">{item.label}</div>
                  <h3 className="mt-2 text-2xl font-semibold text-text-primary">{scopeLabel(item.cache?.scope)}</h3>
                  <p className="mt-3 text-sm leading-6 text-text-secondary">{item.description}</p>
                </div>

                <div className="rounded-2xl border border-border-secondary bg-bg-secondary/70 px-4 py-4 text-sm leading-6 text-text-secondary">
                  <div>缓存命中：{item.cache?.hit ? '是' : '否'}</div>
                  <div>摘要时间：{formatDateTime(item.cache?.generatedAt || item.fetchedAt)}</div>
                  <div>TTL：{formatDuration(item.cache?.ttlMs)}</div>
                  <div>快照版本：{item.cache?.snapshotVersion || '未标记'}</div>
                </div>

                <div className="grid gap-3">
                  <button
                    type="button"
                    onClick={() => void handleRefresh(item.key)}
                    disabled={refreshingKey === item.key}
                    className="rounded-xl bg-primary-blue px-4 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {refreshingKey === item.key ? '刷新中…' : '手动预热摘要'}
                  </button>
                  <div className="rounded-xl border border-border-secondary px-4 py-3 text-sm text-text-secondary">
                    {item.cache?.scope === 'disk'
                      ? '当前已从磁盘快照回暖，适合服务重启后快速恢复目录浏览。'
                      : item.cache?.scope === 'memory'
                        ? '当前已命中服务端热缓存，可继续承接后台高频目录浏览。'
                        : '当前来自实时摘要生成，后续访问会逐步回暖到缓存层。'}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </section>
    </AdminContentLayout>
  );
}
