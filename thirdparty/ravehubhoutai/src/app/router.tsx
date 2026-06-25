import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';

// ── context ──────────────────────────────────────────────────────────────────
const LocationCtx = createContext('/');

export function Router({ children }: { children: React.ReactNode }) {
  const [path, setPath] = useState(() => window.location.pathname);

  useEffect(() => {
    const onPop = () => setPath(window.location.pathname);
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  // expose navigate globally so Link can call it
  (window as any).__navigate = useCallback((to: string) => {
    const [pathname, hash] = to.split('#');
    const nextPath = pathname || window.location.pathname;
    const targetHash = hash ? `#${hash}` : '';

    window.history.pushState(null, '', `${nextPath}${targetHash}`);
    setPath(nextPath);

    if (targetHash) {
      requestAnimationFrame(() => {
        const target = document.getElementById(hash);
        target?.scrollIntoView({ behavior: 'auto' });
      });
    }
  }, []);

  return <LocationCtx.Provider value={path}>{children}</LocationCtx.Provider>;
}

// ── hooks ─────────────────────────────────────────────────────────────────────
export function useLocation(): [string, (to: string) => void] {
  const path = useContext(LocationCtx);
  const navigate = (to: string) => (window as any).__navigate?.(to);
  return [path, navigate];
}

export function useParams<T extends Record<string, string>>(): T {
  // params are injected by the nearest matching Route
  return (useContext(ParamsCtx) as T) ?? ({} as T);
}

const ParamsCtx = createContext<Record<string, string>>({});

// ── Route / Switch ────────────────────────────────────────────────────────────
function matchPath(pattern: string, path: string): Record<string, string> | null {
  const keys: string[] = [];
  const regexStr = pattern
    .replace(/:([^/]+)/g, (_: string, key: string) => { keys.push(key); return '([^/]+)'; })
    .replace(/\*/g, '.*');
  const match = path.match(new RegExp(`^${regexStr}$`));
  if (!match) return null;
  return Object.fromEntries(keys.map((k, i) => [k, match[i + 1]]));
}

interface RouteProps {
  path: string;
  component: React.ComponentType<any>;
}

export function Switch({ children }: { children: React.ReactElement<RouteProps>[] }) {
  const [path] = useLocation();
  for (const child of React.Children.toArray(children) as React.ReactElement<RouteProps>[]) {
    const params = matchPath(child.props.path, path);
    if (params !== null) {
      const Comp = child.props.component;
      return <ParamsCtx.Provider value={params}><Comp /></ParamsCtx.Provider>;
    }
  }
  return null;
}

export function Route(props: RouteProps) {
  return null; // rendered by Switch
}

// ── Link ──────────────────────────────────────────────────────────────────────
interface LinkProps extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  to: string;
}

export function Link({ to, onClick, children, ...rest }: LinkProps) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault();
    onClick?.(e);
    (window as any).__navigate?.(to);
    if (!to.includes('#')) {
      window.scrollTo(0, 0);
    }
  };
  return <a href={to} onClick={handleClick} {...rest}>{children}</a>;
}
