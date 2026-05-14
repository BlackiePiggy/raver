export type RuntimeMode = 'mock' | 'live';

const defaultBffBaseURL = 'http://localhost:8787';

export const appEnv = {
  runtimeMode: 'mock' as RuntimeMode,
  bffBaseURL: defaultBffBaseURL,
  appName: 'Raver',
};
