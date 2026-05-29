import React, { createContext, useContext, useMemo, useState } from 'react';

import type { AppRoute, MainTabKey } from './routes';

type AppRouterValue = {
  currentTab: MainTabKey;
  routeStack: AppRoute[];
  setCurrentTab: (tab: MainTabKey) => void;
  push: (route: AppRoute) => void;
  pop: () => void;
  reset: () => void;
};

const AppRouterContext = createContext<AppRouterValue | null>(null);

type AppRouterProviderProps = {
  children: React.ReactNode;
};

export function AppRouterProvider({ children }: AppRouterProviderProps) {
  const [currentTab, setCurrentTab] = useState<MainTabKey>('discover');
  const [routeStack, setRouteStack] = useState<AppRoute[]>([]);

  const value = useMemo<AppRouterValue>(
    () => ({
      currentTab,
      routeStack,
      setCurrentTab,
      push: route => {
        setRouteStack(current => [...current, route]);
      },
      pop: () => {
        setRouteStack(current => current.slice(0, -1));
      },
      reset: () => {
        setRouteStack([]);
      },
    }),
    [currentTab, routeStack],
  );

  return (
    <AppRouterContext.Provider value={value}>
      {children}
    </AppRouterContext.Provider>
  );
}

export function useAppRouter() {
  const context = useContext(AppRouterContext);
  if (!context) {
    throw new Error('useAppRouter must be used inside AppRouterProvider');
  }
  return context;
}
