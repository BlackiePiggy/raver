import React from 'react';

import { AppCoordinatorView } from './src/application/coordinator/AppCoordinatorView';
import { AppErrorBoundary } from './src/application/errors/AppErrorBoundary';

export default function App() {
  return (
    <AppErrorBoundary>
      <AppCoordinatorView />
    </AppErrorBoundary>
  );
}
