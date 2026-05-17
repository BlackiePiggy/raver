import { Container, getContainer } from '@cloudflare/containers';

export class RaverBackendContainer extends Container {
  defaultPort = 3901;
  requiredPorts = [3901];
  sleepAfter = '10m';
  enableInternet = true;
  pingEndpoint = '/health';
  envVars = {
    NODE_ENV: 'production',
    PORT: '3901',
  };
}

interface Env {
  RAVER_BACKEND: DurableObjectNamespace<RaverBackendContainer>;
}

const INSTANCE_NAME = 'raver-backend-primary';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return getContainer(env.RAVER_BACKEND, INSTANCE_NAME).fetch(request);
  },
};
