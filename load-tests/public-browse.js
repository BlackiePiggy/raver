import { sleep } from 'k6';
import { defaultThresholds, profileOptions } from './lib/config.js';
import { expectOk, request } from './lib/http.js';
import { handleSummary } from './lib/summary.js';

export const options = {
  ...profileOptions('baseline'),
  thresholds: defaultThresholds,
};

export default function () {
  expectOk(request('GET', '/health'), 'health');
  expectOk(request('GET', '/api/events?limit=20'), 'events list');
  expectOk(request('GET', '/api/djs?limit=20'), 'djs list');
  expectOk(request('GET', '/api/dj-sets?limit=20'), 'dj sets list');
  expectOk(request('GET', '/v1/feed?limit=20'), 'feed');
  expectOk(request('GET', '/v1/search?q=festival'), 'search');
  sleep(Math.random() * 2 + 0.5);
}

export { handleSummary };
