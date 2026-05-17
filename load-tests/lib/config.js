export const BASE_URL = (__ENV.BASE_URL || 'http://127.0.0.1:3901').replace(/\/+$/, '');

export function profileOptions(defaultProfile = 'baseline') {
  const profile = (__ENV.PROFILE || defaultProfile).toLowerCase();
  const profiles = {
    smoke: {
      scenarios: {
        smoke: {
          executor: 'constant-vus',
          vus: 2,
          duration: '30s',
        },
      },
    },
    baseline: {
      scenarios: {
        baseline: {
          executor: 'ramping-vus',
          stages: [
            { duration: '1m', target: 10 },
            { duration: '3m', target: 30 },
            { duration: '1m', target: 0 },
          ],
        },
      },
    },
    step: {
      scenarios: {
        step: {
          executor: 'ramping-vus',
          stages: [
            { duration: '2m', target: 25 },
            { duration: '5m', target: 25 },
            { duration: '2m', target: 50 },
            { duration: '5m', target: 50 },
            { duration: '2m', target: 100 },
            { duration: '5m', target: 100 },
            { duration: '2m', target: 0 },
          ],
        },
      },
    },
    stress: {
      scenarios: {
        stress: {
          executor: 'ramping-vus',
          stages: [
            { duration: '2m', target: 50 },
            { duration: '4m', target: 100 },
            { duration: '4m', target: 200 },
            { duration: '4m', target: 300 },
            { duration: '2m', target: 0 },
          ],
        },
      },
    },
    soak: {
      scenarios: {
        soak: {
          executor: 'constant-vus',
          vus: Number(__ENV.SOAK_VUS || 50),
          duration: __ENV.SOAK_DURATION || '45m',
        },
      },
    },
  };

  return profiles[profile] || profiles.baseline;
}

export const defaultThresholds = {
  http_req_failed: ['rate<0.01'],
  http_req_duration: ['p(95)<500', 'p(99)<1200'],
  checks: ['rate>0.98'],
};
