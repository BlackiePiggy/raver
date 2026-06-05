'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { contributionModuleApi } from './api';
import { trackContributionModuleEvent } from './telemetry';
import type {
  ContributionEntityType,
  ContributionListItem,
  ContributionListResponse,
  ContributionSummary,
  ContributionUserLite,
} from './types';

const emptySummary: ContributionSummary = {
  totalCount: 0,
  creator: null,
  previewUsers: [],
  displayName: null,
};

const displayContributorName = (user?: ContributionUserLite | null): string =>
  user?.displayName || user?.username || user?.id || '未知用户';

const formatUtcDateTime = (value?: string | null): string => {
  if (!value) return '未记录';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '未记录';
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const hours = String(date.getUTCHours()).padStart(2, '0');
  const minutes = String(date.getUTCMinutes()).padStart(2, '0');
  const seconds = String(date.getUTCSeconds()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds} UTC`;
};

const roleLabel = (role: ContributionListItem['role']): string => (role === 'creator' ? '创建者' : '贡献者');

function ContributionAvatar({
  user,
  size = 44,
}: {
  user: ContributionUserLite;
  size?: number;
}) {
  const name = displayContributorName(user);
  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-full bg-[#eef1f3]"
      style={{ width: size, height: size }}
      aria-hidden="true"
    >
      {user.avatarUrl ? (
        <Image src={user.avatarUrl} alt={name} fill className="object-cover" sizes={`${size}px`} />
      ) : (
        <div className="flex h-full w-full items-center justify-center text-xs font-semibold text-[#6b7280]">
          {name.slice(0, 1).toUpperCase()}
        </div>
      )}
    </div>
  );
}

function ContributionPreviewStack({ users }: { users: ContributionUserLite[] }) {
  if (!users.length) {
    return (
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[#eef1f3] text-xs font-semibold text-[#6b7280]">
        0
      </div>
    );
  }

  return (
    <div className="flex items-center">
      {users.slice(0, 3).map((user, index) => (
        <div
          key={`${user.id}-${index}`}
          className={index === 0 ? '' : '-ml-3'}
        >
          <div className="rounded-full ring-2 ring-[#f7f5ef]">
            <ContributionAvatar user={user} size={48} />
          </div>
        </div>
      ))}
    </div>
  );
}

function ContributionListRow({
  entityType,
  entityId,
  item,
}: {
  entityType: ContributionEntityType;
  entityId: string;
  item: ContributionListItem;
}) {
  const user = item.user;
  const userName = displayContributorName(user);

  return (
    <Link
      href={`/users/${user.id}`}
      onClick={() => {
        trackContributionModuleEvent('contributor_list_profile_tapped', {
          entityType,
          entityId,
          targetUserId: user.id,
        });
      }}
      className="flex gap-4 rounded-[20px] border border-[#edf0f2] bg-[#fafbfb] p-4 transition hover:bg-white"
    >
      <ContributionAvatar user={user} size={52} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <div className="truncate text-sm font-semibold text-[#111827]">{userName}</div>
          <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#4b5563]">
            {roleLabel(item.role)}
          </span>
          <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#4b5563]">
            {item.contributionCount} 次贡献
          </span>
        </div>
        <div className="mt-1 text-xs text-[#8b93a1]">
          @{user.username || user.id}
        </div>
        <div className="mt-3 grid gap-2 text-xs text-[#4b5563] lg:grid-cols-2">
          <div>
            <span className="font-semibold text-[#111827]">首次贡献：</span>
            {formatUtcDateTime(item.firstContributedAt)}
          </div>
          <div>
            <span className="font-semibold text-[#111827]">最近修改：</span>
            {formatUtcDateTime(item.lastContributedAt)}
          </div>
          <div>
            <span className="font-semibold text-[#111827]">记录创建：</span>
            {formatUtcDateTime(item.createdAt)}
          </div>
          <div>
            <span className="font-semibold text-[#111827]">记录更新：</span>
            {formatUtcDateTime(item.updatedAt)}
          </div>
        </div>
      </div>
    </Link>
  );
}

export default function ContributionTabPanel({
  entityType,
  entityId,
  initialData,
}: {
  entityType: ContributionEntityType;
  entityId: string;
  initialData?: ContributionListResponse | null;
}) {
  const [data, setData] = useState<ContributionListResponse | null>(initialData ?? null);
  const [loading, setLoading] = useState(!initialData);
  const [error, setError] = useState('');

  useEffect(() => {
    setData(initialData ?? null);
    setLoading(!initialData);
    setError('');
  }, [entityId, entityType, initialData]);

  useEffect(() => {
    trackContributionModuleEvent('contribution_tab_exposure', {
      entityType,
      entityId,
    });
  }, [entityId, entityType]);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      if (!initialData) {
        setLoading(true);
      }
      setError('');
      try {
        const next = await contributionModuleApi.fetchEntityContributors(entityType, entityId);
        if (cancelled) return;
        setData(next);
      } catch (nextError) {
        if (cancelled) return;
        if (!initialData) {
          setError(nextError instanceof Error ? nextError.message : '贡献列表加载失败');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [entityId, entityType, initialData]);

  if (loading) {
    return (
      <div className="rounded-[24px] border border-[#e8eceb] bg-white px-5 py-10 text-sm text-[#6b7280]">
        正在加载贡献记录...
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-[24px] border border-red-200 bg-red-50 px-5 py-4 text-sm text-[#7a2d29]">
        {error}
      </div>
    );
  }

  const items = data?.items ?? [];
  const summary = data?.summary ?? emptySummary;
  const creatorName = displayContributorName(summary.creator);

  return (
    <div className="space-y-5">
      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-4">
            <ContributionPreviewStack users={summary.previewUsers} />
            <div>
              <div className="text-sm font-semibold text-[#111827]">贡献者总览</div>
              <div className="mt-1 text-sm text-[#4b5563]">
                {summary.totalCount > 0 ? `${creatorName} 等 ${summary.totalCount} 人` : '暂无贡献记录'}
              </div>
            </div>
          </div>
          <div className="rounded-[18px] border border-[#edf0f2] bg-[#fafbfb] px-4 py-3 text-right">
            <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[#9aa1ad]">Contributions</div>
            <div className="mt-2 text-2xl font-semibold tracking-[-0.03em] text-[#111827]">{summary.totalCount}</div>
          </div>
        </div>
      </section>

      <section className="rounded-[24px] border border-[#e8eceb] bg-white p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-[#111827]">贡献列表</div>
            <div className="mt-1 text-xs text-[#9aa1ad]">按最近修改时间倒序，时间统一展示为 UTC。</div>
          </div>
          <span className="rounded-full bg-[#f4f5f7] px-3 py-1 text-xs font-semibold text-[#6b7280]">
            {items.length} 人
          </span>
        </div>

        {items.length ? (
          <div className="mt-4 space-y-3">
            {items.map((item) => (
              <ContributionListRow
                entityType={entityType}
                entityId={entityId}
                key={`${item.user.id}-${item.role}-${item.lastContributedAt}`}
                item={item}
              />
            ))}
          </div>
        ) : (
          <div className="mt-4 rounded-[20px] border border-dashed border-[#d8dfdc] bg-[#fafbfb] px-5 py-8 text-center text-sm text-[#6b7280]">
            暂无贡献记录
          </div>
        )}
      </section>
    </div>
  );
}
