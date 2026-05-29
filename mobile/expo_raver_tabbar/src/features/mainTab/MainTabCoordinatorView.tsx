import React from 'react';

import { useAppRouter } from '../../application/navigation/AppRouter';
import type { DiscoverRoute } from '../../application/navigation/routes';
import { DiscoverCoordinatorView } from '../discover/coordinator/DiscoverCoordinatorView';
import { DiscoverHomeView } from '../discover/views/DiscoverHomeView';

export function MainTabCoordinatorView() {
  const router = useAppRouter();

  const pushDiscoverRoute = (route: DiscoverRoute) => {
    router.push({ type: 'discover', route });
  };

  return (
    <DiscoverCoordinatorView push={pushDiscoverRoute}>
      <DiscoverHomeView
        mainTab={router.currentTab}
        onMainTabChange={router.setCurrentTab}
      />
    </DiscoverCoordinatorView>
  );
}
