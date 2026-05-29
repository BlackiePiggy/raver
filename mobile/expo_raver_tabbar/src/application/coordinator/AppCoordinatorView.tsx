import React from 'react';

import { AppContainerProvider } from '../di/AppContainer';
import { AppRouterProvider } from '../navigation/AppRouter';
import { MainTabCoordinatorView } from '../../features/mainTab/MainTabCoordinatorView';

export function AppCoordinatorView() {
  return (
    <AppContainerProvider>
      <AppRouterProvider>
        <MainTabCoordinatorView />
      </AppRouterProvider>
    </AppContainerProvider>
  );
}
