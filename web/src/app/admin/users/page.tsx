'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import { useAuth } from '@/contexts/AuthContext';
import { authAPI } from '@/lib/api/auth';
import { AdminUser, AdminUserDetail, adminUsersApi } from '@/lib/api/admin-users';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { formatDateTimeWithSystemTimeZoneLabel } from '@/lib/timezone';

const REAUTH_SCOPE = 'account_deletion.write';
const PAGE_SIZE = 24;

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return formatDateTimeWithSystemTimeZoneLabel(value);
};

const statusClassName = (isActive: boolean): string =>
  isActive ? 'border-accent-green/40 bg-accent-green/10 text-accent-green' : 'border-red-500/40 bg-red-500/10 text-red-300';

function StatusBadge({ isActive }: { isActive: boolean }) {
  return <span className={`rounded-md border px-2 py-1 text-xs font-semibold ${statusClassName(isActive)}`}>{isActive ? 'active' : 'inactive'}</span>;
}

function UserIdentity({ item }: { item: AdminUser }) {
  return (
    <div className="min-w-0 space-y-1.5">
      <div className="flex flex-wrap items-center gap-1.5">
        <StatusBadge isActive={item.isActive} />
        <span className="rounded-md border border-border-secondary bg-bg-tertiary px-2 py-0.5 text-[11px] text-text-secondary">{item.role}</span>
      </div>
      <div className="truncate font-semibold leading-5">{item.displayName || item.username}</div>
      <div className="break-all text-[11px] leading-5 text-text-secondary">{item.email}</div>
      <div className="break-all text-[11px] leading-5 text-text-secondary">{item.phoneNumber || '未绑定手机号'}</div>
      <div className="break-all font-mono text-[11px] leading-5 text-text-tertiary">{item.id}</div>
    </div>
  );
}

export default function AdminUsersPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canOperate = rolePolicy.canAccessOperations;
  const canDelete = user?.role === 'admin';

  const [queryInput, setQueryInput] = useState('');
  const [query, setQuery] = useState('');
  const [items, setItems] = useState<AdminUser[]>([]);
  const [role, setRole] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminUserDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [deletingUserId, setDeletingUserId] = useState<string | null>(null);
  const [reauthPassword, setReauthPassword] = useState('');
  const [reauthError, setReauthError] = useState<string | null>(null);
  const [reauthLoading, setReauthLoading] = useState(false);
  const [pendingDeleteUser, setPendingDeleteUser] = useState<AdminUser | null>(null);

  const loadUsers = useCallback(async () => {
    if (!canOperate) return;
    try {
      setLoading(true);
      setError(null);
      const result = await adminUsersApi.list({
        q: query.trim() || undefined,
        role: role || undefined,
        status: status || undefined,
        page,
        limit: PAGE_SIZE,
      });
      setItems(result.items);
      setTotal(result.pagination.total);
      setTotalPages(result.pagination.totalPages);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载用户失败');
    } finally {
      setLoading(false);
    }
  }, [canOperate, page, query, role, status]);

  const loadDetail = useCallback(async (userId: string) => {
    try {
      setDetailLoading(true);
      setDetailError(null);
      setDetail(await adminUsersApi.detail(userId));
    } catch (loadError) {
      setDetailError(loadError instanceof Error ? loadError.message : '加载用户详情失败');
      setDetail(null);
    } finally {
      setDetailLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  useEffect(() => {
    if (selectedUserId) {
      void loadDetail(selectedUserId);
    } else {
      setDetail(null);
    }
  }, [loadDetail, selectedUserId]);

  useEffect(() => {
    if (!selectedUserId) return;
    if (items.some((item) => item.id === selectedUserId)) return;
    setSelectedUserId(null);
  }, [items, selectedUserId]);

  const submitSearch = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSelectedUserId(null);
    setPage(1);
    setQuery(queryInput);
  };

  const openDeleteDialog = (item: AdminUser) => {
    setPendingDeleteUser(item);
    setReauthPassword('');
    setReauthError(null);
  };

  const submitDelete = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!pendingDeleteUser || !canDelete) return;
    const confirmed = window.confirm(`确认删除并匿名化账号 ${pendingDeleteUser.email}？此操作不可撤销。`);
    if (!confirmed) return;

    try {
      setReauthLoading(true);
      setReauthError(null);
      setNotice(null);
      const proof = await authAPI.reauth(reauthPassword, REAUTH_SCOPE);
      setDeletingUserId(pendingDeleteUser.id);
      const result = await adminUsersApi.deleteAccount(pendingDeleteUser.id, proof.reauthProof);
      setNotice(`账号已匿名化删除，删除请求 ID：${result.deletionRequestId || '-'}`);
      setPendingDeleteUser(null);
      setSelectedUserId(null);
      await loadUsers();
    } catch (deleteError) {
      setReauthError(deleteError instanceof Error ? deleteError.message : '删除失败');
    } finally {
      setReauthLoading(false);
      setDeletingUserId(null);
    }
  };

  const visiblePages = useMemo(() => {
    const safeTotalPages = Math.max(1, totalPages);
    const start = Math.max(1, Math.min(safeTotalPages - 4, page - 2));
    const end = Math.min(safeTotalPages, start + 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [page, totalPages]);

  if (isLoading) {
    return (
      <AdminAppShell title="用户管理" description="加载用户检索与账号管理数据中。">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (!user || !canOperate) {
    return (
      <AdminAppShell title="用户管理" description="当前账号暂时不能访问用户管理。">
        <section className="mx-auto max-w-4xl">
          <div className="admin-shell-panel p-6">
            <h1 className="text-2xl font-semibold">用户管理</h1>
            <p className="mt-3 text-sm text-text-secondary">当前账号无权限访问该页面。</p>
            <Link href={user ? '/admin' : '/login'} className="mt-5 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
              {user ? '返回后台' : '去登录'}
            </Link>
          </div>
        </section>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="用户管理"
      eyebrow="Raver Admin / User Admin"
      description="按邮箱、手机号、昵称、用户名或 userId 检索账号，并查看详情、会话和高风险操作入口。"
    >
      <section className="space-y-5">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm text-text-secondary">User Admin</p>
            <h1 className="mt-1 text-3xl font-semibold">用户管理</h1>
            <p className="mt-2 text-sm text-text-secondary">按邮箱、手机号、昵称、用户名或 userId 检索账号。</p>
          </div>
          <button
            type="button"
            onClick={() => void loadUsers()}
            disabled={loading}
            className="rounded-lg bg-primary-blue px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
          >
            {loading ? '刷新中...' : '刷新'}
          </button>
        </div>

        {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div>}
        {notice && <div className="rounded-lg border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div>}

        <form onSubmit={submitSearch} className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
          <div className="grid gap-3 md:grid-cols-[1fr_150px_150px_auto]">
            <input
              value={queryInput}
              onChange={(event) => setQueryInput(event.target.value)}
              placeholder="邮箱 / 手机号 / 昵称 / 用户名 / userId"
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            />
            <select
              value={role}
              onChange={(event) => {
                setRole(event.target.value);
                setPage(1);
                setSelectedUserId(null);
              }}
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            >
              <option value="">全部角色</option>
              <option value="user">user</option>
              <option value="artist">artist</option>
              <option value="organizer">organizer</option>
              <option value="operator">operator</option>
              <option value="admin">admin</option>
            </select>
            <select
              value={status}
              onChange={(event) => {
                setStatus(event.target.value);
                setPage(1);
                setSelectedUserId(null);
              }}
              className="rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
            >
              <option value="">全部状态</option>
              <option value="active">active</option>
              <option value="inactive">inactive</option>
            </select>
            <button type="submit" className="rounded-lg border border-border-secondary px-4 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
              查询
            </button>
          </div>
        </form>

        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
          <section className="overflow-hidden rounded-lg border border-border-secondary bg-bg-secondary">
            <div className="flex items-center justify-between border-b border-border-secondary px-4 py-3 text-xs text-text-secondary">
              <div>
                共 {total.toLocaleString()} 个用户，当前第 {page} / {Math.max(1, totalPages)} 页
              </div>
              <div>
                显示 {total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1} - {Math.min(page * PAGE_SIZE, total)}
              </div>
            </div>
            <div className="grid grid-cols-[1.2fr_0.78fr_0.86fr_130px] gap-3 border-b border-border-secondary px-4 py-2.5 text-[11px] font-semibold uppercase tracking-wide text-text-secondary">
              <div>用户</div>
              <div>数据</div>
              <div>时间</div>
              <div>操作</div>
            </div>
            <div className="divide-y divide-border-secondary">
              {items.map((item) => (
                <div key={item.id} className="grid grid-cols-[1.2fr_0.78fr_0.86fr_130px] gap-3 px-4 py-3 text-[13px]">
                  <UserIdentity item={item} />
                  <div className="space-y-1 text-[12px] leading-5 text-text-secondary">
                    <div>帖子：{item.counts?.posts ?? 0}</div>
                    <div>关注：{item.counts?.follows ?? 0}</div>
                    <div>粉丝：{item.counts?.followers ?? 0}</div>
                    <div>会话：{item.counts?.authSessions ?? 0}</div>
                    <div>处罚：{item.counts?.enforcements ?? 0}</div>
                  </div>
                  <div className="space-y-1 text-[12px] leading-5 text-text-secondary">
                    <div>注册：{formatTime(item.createdAt)}</div>
                    <div>登录：{formatTime(item.lastLoginAt)}</div>
                    <div>更新：{formatTime(item.updatedAt)}</div>
                  </div>
                  <div className="space-y-2">
                    <button
                      type="button"
                      onClick={() => setSelectedUserId(item.id)}
                      className="w-full rounded-lg border border-border-secondary px-3 py-1.5 text-[12px] hover:border-primary-blue hover:text-primary-blue"
                    >
                      查看
                    </button>
                    {canDelete && item.isActive && item.id !== user.id && (
                      <button
                        type="button"
                        onClick={() => openDeleteDialog(item)}
                        disabled={deletingUserId === item.id}
                        className="w-full rounded-lg border border-border-secondary px-3 py-1.5 text-[12px] hover:border-red-500 hover:text-red-300 disabled:opacity-60"
                      >
                        {deletingUserId === item.id ? '删除中...' : '删除账号'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
              {items.length === 0 && <div className="px-4 py-10 text-center text-sm text-text-secondary">暂无用户</div>}
            </div>
            <div className="flex flex-col gap-3 border-t border-border-secondary px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="text-xs text-text-secondary">每页 {PAGE_SIZE} 条</div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={page <= 1}
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                  className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-border-secondary bg-bg-secondary text-text-primary disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronLeft className="h-4 w-4" />
                </button>
                {visiblePages.map((pageNumber) => (
                  <button
                    key={pageNumber}
                    type="button"
                    onClick={() => setPage(pageNumber)}
                    className={`h-9 min-w-9 rounded-full px-3 text-xs font-semibold ${
                      pageNumber === page
                        ? 'bg-[#071110] text-white'
                        : 'border border-border-secondary bg-bg-secondary text-text-primary'
                    }`}
                  >
                    {pageNumber}
                  </button>
                ))}
                <button
                  type="button"
                  disabled={page >= totalPages}
                  onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                  className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-border-secondary bg-bg-secondary text-text-primary disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <ChevronRight className="h-4 w-4" />
                </button>
              </div>
            </div>
          </section>

          <aside className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-sm text-text-secondary">Detail</p>
                <h2 className="mt-1 text-xl font-semibold">账号详情</h2>
              </div>
              {selectedUserId && (
                <button type="button" onClick={() => setSelectedUserId(null)} className="text-sm text-text-secondary hover:text-text-primary">
                  关闭
                </button>
              )}
            </div>

            {!selectedUserId && <p className="mt-6 text-sm text-text-secondary">从左侧选择一个用户查看详情。</p>}
            {detailLoading && <p className="mt-6 text-sm text-text-secondary">加载中...</p>}
            {detailError && <div className="mt-5 rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{detailError}</div>}
            {detail && (
              <div className="mt-5 space-y-4 text-sm">
                <UserIdentity item={detail.user} />
                <div className="grid grid-cols-3 gap-3">
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">有效会话</div>
                    <div className="mt-1 text-xl font-semibold">{detail.stats.activeSessions}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">推送设备</div>
                    <div className="mt-1 text-xl font-semibold">{detail.stats.activePushTokens}</div>
                  </div>
                  <div className="rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                    <div className="text-text-secondary">处罚</div>
                    <div className="mt-1 text-xl font-semibold">{detail.stats.activeEnforcements}</div>
                  </div>
                </div>
                <div className="space-y-2 rounded-lg border border-border-secondary bg-bg-tertiary p-3 text-text-secondary">
                  <div>地区：{detail.user.regionCode || '-'}</div>
                  <div>年龄段：{detail.user.ageBand || '-'}</div>
                  <div>出生年：{detail.user.birthYear || '-'}</div>
                  <div>已验证：{detail.user.isVerified ? 'true' : 'false'}</div>
                </div>
                <div className="space-y-2 rounded-lg border border-border-secondary bg-bg-tertiary p-3">
                  <div className="font-semibold">最近删除请求</div>
                  {detail.latestDeletionRequest ? (
                    <div className="space-y-1 text-text-secondary">
                      <div>{detail.latestDeletionRequest.status}</div>
                      <div>来源：{detail.latestDeletionRequest.requestSource}</div>
                      <div>请求人：{detail.latestDeletionRequest.requestedBy}</div>
                      <div>{formatTime(detail.latestDeletionRequest.createdAt)}</div>
                    </div>
                  ) : (
                    <div className="text-text-secondary">无</div>
                  )}
                </div>
                <div className="flex flex-wrap gap-2">
                  <Link href={`/admin/auth-sessions?userId=${encodeURIComponent(detail.user.id)}`} className="rounded-lg border border-border-secondary px-3 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
                    查看会话
                  </Link>
                  <Link href={`/admin/account-enforcements?userId=${encodeURIComponent(detail.user.id)}`} className="rounded-lg border border-border-secondary px-3 py-2 text-sm hover:border-primary-blue hover:text-primary-blue">
                    查看处罚
                  </Link>
                </div>
              </div>
            )}
          </aside>
        </div>

        {pendingDeleteUser && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-4">
            <form onSubmit={submitDelete} className="w-full max-w-md rounded-lg border border-border-secondary bg-bg-secondary p-5 shadow-2xl">
              <h2 className="text-xl font-semibold">确认删除账号</h2>
              <p className="mt-3 text-sm leading-6 text-text-secondary">
                将匿名化 {pendingDeleteUser.email}，清空手机号、头像、资料，并撤销会话。请输入管理员密码复验。
              </p>
              <input
                type="password"
                value={reauthPassword}
                onChange={(event) => setReauthPassword(event.target.value)}
                placeholder="管理员密码"
                className="mt-4 w-full rounded-md border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm"
              />
              {reauthError && <div className="mt-3 rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-300">{reauthError}</div>}
              <div className="mt-5 flex justify-end gap-3">
                <button type="button" onClick={() => setPendingDeleteUser(null)} className="rounded-lg border border-border-secondary px-4 py-2 text-sm">
                  取消
                </button>
                <button type="submit" disabled={!reauthPassword || reauthLoading} className="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60">
                  {reauthLoading ? '处理中...' : '确认删除'}
                </button>
              </div>
            </form>
          </div>
        )}
      </section>
    </AdminAppShell>
  );
}
