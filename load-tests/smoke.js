import { sleep } from 'k6';
import { defaultThresholds, profileOptions } from './lib/config.js';
import { expectOk, request } from './lib/http.js';
import { handleSummary } from './lib/summary.js';

export const options = {
  ...profileOptions('smoke'),
  thresholds: defaultThresholds,
};

export default function () {
  expectOk(request('GET', '/health'), 'health');
  expectOk(request('GET', '/api'), 'api index');
  sleep(1);
}

export { handleSummary };
