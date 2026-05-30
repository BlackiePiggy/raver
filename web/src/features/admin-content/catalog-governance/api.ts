import { adminCatalogApi, CatalogCacheMeta } from '@/features/admin-content/catalog/api';
import { archiveAdminApi } from '@/features/admin-content/archive/api';

export type CatalogGovernanceResourceStatus = {
  key: 'events' | 'djs' | 'archiveYears';
  label: string;
  description: string;
  cache: CatalogCacheMeta | null;
  fetchedAt: string;
};

const nowIso = (): string => new Date().toISOString();

export const catalogGovernanceApi = {
  async inspectAll(): Promise<CatalogGovernanceResourceStatus[]> {
    const [events, djs, archiveYears] = await Promise.all([
      adminCatalogApi.fetchEvents({ page: 1, limit: 1 }),
      adminCatalogApi.fetchDJs({ page: 1, limit: 1 }),
      archiveAdminApi.fetchYearSummary(),
    ]);

    return [
      {
        key: 'events',
        label: '活动目录摘要',
        description: '活动目录中心默认读取的分页摘要缓存。',
        cache: events.cache ?? null,
        fetchedAt: events.cache?.generatedAt || nowIso(),
      },
      {
        key: 'djs',
        label: 'DJ 目录摘要',
        description: 'DJ 目录中心默认读取的分页摘要缓存。',
        cache: djs.cache ?? null,
        fetchedAt: djs.cache?.generatedAt || nowIso(),
      },
      {
        key: 'archiveYears',
        label: 'Archive 年份摘要',
        description: 'Archive 年份中心的低频年份回看摘要缓存。',
        cache: archiveYears.cache ?? null,
        fetchedAt: archiveYears.cache?.generatedAt || nowIso(),
      },
    ];
  },

  async refreshResource(key: CatalogGovernanceResourceStatus['key']): Promise<CatalogGovernanceResourceStatus> {
    if (key === 'events') {
      const response = await adminCatalogApi.fetchEvents({ page: 1, limit: 1, refresh: true });
      return {
        key,
        label: '活动目录摘要',
        description: '活动目录中心默认读取的分页摘要缓存。',
        cache: response.cache ?? null,
        fetchedAt: response.cache?.generatedAt || nowIso(),
      };
    }

    if (key === 'djs') {
      const response = await adminCatalogApi.fetchDJs({ page: 1, limit: 1, refresh: true });
      return {
        key,
        label: 'DJ 目录摘要',
        description: 'DJ 目录中心默认读取的分页摘要缓存。',
        cache: response.cache ?? null,
        fetchedAt: response.cache?.generatedAt || nowIso(),
      };
    }

    const response = await archiveAdminApi.refreshYearSummary();
    return {
      key,
      label: 'Archive 年份摘要',
      description: 'Archive 年份中心的低频年份回看摘要缓存。',
      cache: response.cache ?? null,
      fetchedAt: response.cache?.generatedAt || nowIso(),
    };
  },
};
