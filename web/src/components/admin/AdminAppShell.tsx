'use client';

import Link from 'next/link';
import {
  ChevronDown,
  Command,
  PanelLeftClose,
  Search,
  Settings,
  Sparkles,
  Triangle,
  X,
} from 'lucide-react';
import { clsx } from 'clsx';
import { ReactNode, useEffect, useMemo, useState } from 'react';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import { getVisibleAdminNavGroups, isAdminHrefActive } from '@/lib/admin/navigation';

type AdminAppShellProps = {
  title: string;
  description: string;
  eyebrow?: string;
  actions?: ReactNode;
  children: ReactNode;
};

const SIDEBAR_STATE_KEY = 'raver-admin-shell-collapsed';

const initialsFromName = (value?: string | null): string =>
  value
    ?.split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((item) => item.slice(0, 1).toUpperCase())
    .join('') || 'RA';


function Sidebar({
  collapsed,
  setCollapsed,
  mobileOpen,
  setMobileOpen,
}: {
  collapsed: boolean;
  setCollapsed: (next: boolean) => void;
  mobileOpen: boolean;
  setMobileOpen: (next: boolean) => void;
}) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const groups = useMemo(() => getVisibleAdminNavGroups(policy), [policy]);

  return (
    <>
      <aside
        className={clsx(
          'admin-shell-sidebar fixed inset-y-0 left-0 z-30 flex h-screen shrink-0 flex-col transition-all duration-500 ease-[cubic-bezier(.22,1,.36,1)] md:relative',
          collapsed ? 'w-[92px] px-[14px]' : 'w-[246px] px-[18px]',
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
        )}
      >
        <div className={clsx('mb-[28px] flex items-center', collapsed ? 'justify-center' : 'gap-3')}>
          <Triangle className="size-[24px] fill-[#071110] text-[#071110]" />
          {!collapsed && <b className="text-[18px] tracking-[-0.03em] text-[#071110]">RaveHub Admin</b>}
        </div>

        <div className={clsx('mb-[18px] flex shrink-0 items-center', collapsed ? 'justify-center' : 'justify-between px-1')}>
          <span className={clsx('text-[18px] font-bold tracking-[-0.03em] text-[#071110]', collapsed && 'hidden')}>Menu</span>
          <button
            type="button"
            onClick={() => setCollapsed(!collapsed)}
            className="grid size-8 place-items-center rounded-full transition hover:bg-white/60 active:scale-95"
          >
            <PanelLeftClose className={clsx('size-4 transition-transform duration-500', collapsed && 'rotate-180')} />
          </button>
        </div>

        <div className="relative min-h-0 flex-1">
          <div className="absolute inset-0 overflow-y-auto px-1 py-2 admin-shell-scrollbar">
            {groups.map((group) => (
              <div key={group.id} className="mb-6">
                {!collapsed && group.id !== 'menu' && (
                  <div className="mb-3 flex items-center justify-between px-1 text-[13px] font-bold text-[#071110]">
                    <span>{group.label}</span>
                    <ChevronDown className="size-4" />
                  </div>
                )}
                <nav className="space-y-[7px]">
                  {group.items.map((item) => {
                    const active = isAdminHrefActive(pathname, item.href);
                    const Icon = item.icon;
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        onClick={() => setMobileOpen(false)}
                        className={clsx(
                          'group flex h-[44px] w-full items-center rounded-full text-[13px] font-semibold transition-all duration-300 hover:-translate-y-0.5',
                          collapsed ? 'justify-center px-0' : 'gap-4 px-[15px]',
                          active
                            ? 'bg-[#071110] text-white shadow-[0_0_28px_rgba(91,245,255,.24)]'
                            : 'text-[#18211f] hover:bg-white/60'
                        )}
                      >
                        <span
                          className={clsx(
                            'grid place-items-center',
                            active ? 'text-white' : 'rounded-full bg-white/45 text-[#121b19] group-hover:bg-white/80',
                            collapsed ? 'size-9' : 'size-7'
                          )}
                        >
                          <Icon className="size-[15px]" />
                        </span>
                        {!collapsed && <span>{item.label}</span>}
                      </Link>
                    );
                  })}
                </nav>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-shell-profile mt-4 shrink-0 rounded-[24px] p-3">
          <div className={clsx('mb-3 flex items-center', collapsed ? 'justify-center' : 'justify-between')}>
            {[Sparkles, Command, Settings].map((Icon, index) => (
              <span
                key={index}
                className="relative grid size-9 place-items-center rounded-full bg-[#f4f6f5] text-[#15221f] transition hover:bg-white"
              >
                <Icon className="size-[15px]" />
                {index === 1 && (
                  <em className="absolute -right-0.5 -top-0.5 size-4 rounded-full bg-[#25bb72] text-center text-[9px] not-italic leading-4 text-white">
                    3
                  </em>
                )}
              </span>
            ))}
          </div>

          <div className={clsx('flex items-center', collapsed ? 'justify-center' : 'gap-3')}>
            <span className="grid size-10 shrink-0 place-items-center rounded-full bg-[#071110] text-[12px] font-extrabold text-white">
              {initialsFromName(user?.displayName || user?.username || user?.email)}
            </span>
            {!collapsed && (
              <>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-extrabold text-[#071110]">{user?.displayName || user?.username || 'Admin User'}</p>
                  <p className="truncate text-[10px] text-black/45">{user?.email || '未登录'}</p>
                </div>
                {user ? (
                  <button
                    type="button"
                    onClick={logout}
                    className="rounded-full bg-[#071110] px-3 py-1.5 text-[10px] font-bold uppercase tracking-[0.12em] text-white"
                  >
                    Sign out
                  </button>
                ) : null}
              </>
            )}
          </div>
        </div>
      </aside>
      {mobileOpen && <div onClick={() => setMobileOpen(false)} className="fixed inset-0 z-20 bg-black/20 md:hidden" />}
    </>
  );
}

function Topbar({
  title,
  eyebrow,
  description,
  actions,
  setMobileOpen,
}: Pick<AdminAppShellProps, 'title' | 'eyebrow' | 'description' | 'actions'> & {
  setMobileOpen: (next: boolean) => void;
}) {
  const [query, setQuery] = useState('');

  return (
    <>
      <div className="flex h-[72px] shrink-0 items-center gap-3 pr-3 pt-[18px] md:gap-6 md:pr-[26px]">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="ml-3 grid size-10 place-items-center rounded-full bg-white/60 transition hover:bg-white/80 active:scale-95 md:hidden"
        >
          <PanelLeftClose className="size-4 rotate-180" />
        </button>
        <label className="mx-auto flex h-[42px] w-full max-w-[470px] items-center rounded-full border border-[#ececec] bg-[#f5f5f7] px-3 transition-all duration-300 md:px-4">
          <Search className="mr-2 size-4 shrink-0 md:mr-3" />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="min-w-0 flex-1 bg-transparent text-[12px] text-[#071110] outline-none placeholder:text-black/40"
            placeholder="Search modules, queues, records"
          />
          {query ? (
            <button type="button" onClick={() => setQuery('')}>
              <X className="size-4" />
            </button>
          ) : (
            <Command className="size-4 max-md:hidden" />
          )}
        </label>
        <div className="hidden items-center gap-3 md:flex">
          <button className="admin-shell-pill h-[42px] px-7 text-[12px] font-bold">Integration</button>
          <div className="flex items-center -space-x-2">
            {['RB', 'OP', 'CM'].map((label, index) => (
              <span
                key={label}
                className={clsx(
                  'grid size-[42px] place-items-center rounded-full text-[11px] font-bold text-white ring-2 ring-white',
                  index === 0 && 'bg-[#0f766e]',
                  index === 1 && 'bg-[#071110]',
                  index === 2 && 'bg-[#f97316]'
                )}
              >
                {label}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="mb-5 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-[0.22em] text-black/35">{eyebrow || 'Raver Admin'}</p>
          <h1 className="mt-2 text-[32px] font-extrabold tracking-[-0.04em] text-[#071110]">{title}</h1>
          <p className="mt-3 max-w-3xl text-[14px] leading-7 text-black/48">{description}</p>
        </div>
        {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
      </div>
    </>
  );
}

export default function AdminAppShell({
  title,
  description,
  eyebrow = 'Raver Admin',
  actions,
  children,
}: AdminAppShellProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const nextCollapsed = window.localStorage.getItem(SIDEBAR_STATE_KEY) === '1';
    setCollapsed(nextCollapsed);
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem(SIDEBAR_STATE_KEY, collapsed ? '1' : '0');
  }, [collapsed]);

  return (
    <main className="admin-ravehub-shell h-screen">
      <div className="admin-ravehub-bg" />
      <div className="relative flex h-screen overflow-hidden">
        <Sidebar collapsed={collapsed} setCollapsed={setCollapsed} mobileOpen={mobileOpen} setMobileOpen={setMobileOpen} />
        <div className="flex min-w-0 flex-1 overflow-hidden px-3 pb-4 md:px-4 md:pb-5">
          <section className="min-w-0 flex-1 overflow-y-auto admin-shell-scrollbar">
            <Topbar
              title={title}
              eyebrow={eyebrow}
              description={description}
              actions={actions}
              setMobileOpen={setMobileOpen}
            />
            <div className="admin-shell-page pb-8">
              {children}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
