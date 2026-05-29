import React, { createContext, useContext, useMemo } from 'react';

import {
  createLiveRecommendEventsRepository,
  type RecommendEventsRepository,
} from '../../features/discover/recommend/data/recommendEventsRepository';

type RepositoryFlavor = 'mock' | 'live';

export type ExpoAppContainer = {
  eventListRepository: { flavor: RepositoryFlavor };
  eventRecommendationRepository: RecommendEventsRepository & {
    flavor: RepositoryFlavor;
  };
  eventReadRepository: { flavor: RepositoryFlavor };
  discoverNewsRepository: { flavor: RepositoryFlavor };
  djListRepository: { flavor: RepositoryFlavor };
  djReadRepository: { flavor: RepositoryFlavor };
  discoverWikiRepository: { flavor: RepositoryFlavor };
};

const AppContainerContext = createContext<ExpoAppContainer | null>(null);

type AppContainerProviderProps = {
  children: React.ReactNode;
};

export function AppContainerProvider({
  children,
}: AppContainerProviderProps) {
  const container = useMemo<ExpoAppContainer>(
    () => ({
      eventListRepository: { flavor: 'mock' },
      eventRecommendationRepository: {
        flavor: 'live',
        ...createLiveRecommendEventsRepository(),
      },
      eventReadRepository: { flavor: 'mock' },
      discoverNewsRepository: { flavor: 'mock' },
      djListRepository: { flavor: 'mock' },
      djReadRepository: { flavor: 'mock' },
      discoverWikiRepository: { flavor: 'mock' },
    }),
    [],
  );

  return (
    <AppContainerContext.Provider value={container}>
      {children}
    </AppContainerContext.Provider>
  );
}

export function useAppContainer() {
  const context = useContext(AppContainerContext);
  if (!context) {
    throw new Error('useAppContainer must be used inside AppContainerProvider');
  }
  return context;
}
