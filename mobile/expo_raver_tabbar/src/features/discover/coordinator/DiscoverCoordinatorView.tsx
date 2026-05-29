import React, { createContext, useContext } from 'react';

import type { DiscoverRoute } from '../../../application/navigation/routes';

type DiscoverNavigate = (route: DiscoverRoute) => void;

const DiscoverNavigateContext = createContext<DiscoverNavigate>(() => {});

type DiscoverCoordinatorViewProps = {
  push: DiscoverNavigate;
  children: React.ReactNode;
};

export function DiscoverCoordinatorView({
  push,
  children,
}: DiscoverCoordinatorViewProps) {
  return (
    <DiscoverNavigateContext.Provider value={push}>
      {children}
    </DiscoverNavigateContext.Provider>
  );
}

export function useDiscoverNavigate() {
  return useContext(DiscoverNavigateContext);
}
