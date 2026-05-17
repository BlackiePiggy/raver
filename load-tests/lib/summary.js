function metricValue(data, name, key) {
  return data.metrics?.[name]?.values?.[key];
}

function format(value, suffix = '') {
  if (value === undefined || value === null || Number.isNaN(value)) return 'n/a';
  return `${Number(value).toFixed(2)}${suffix}`;
}

export function handleSummary(data) {
  const lines = [
    '# Raver Load Test Summary',
    '',
    `- Requests: ${format(metricValue(data, 'http_reqs', 'count'))}`,
    `- Request rate: ${format(metricValue(data, 'http_reqs', 'rate'), '/s')}`,
    `- Failed request rate: ${format(metricValue(data, 'http_req_failed', 'rate') * 100, '%')}`,
    `- Duration avg: ${format(metricValue(data, 'http_req_duration', 'avg'), 'ms')}`,
    `- Duration p90: ${format(metricValue(data, 'http_req_duration', 'p(90)'), 'ms')}`,
    `- Duration p95: ${format(metricValue(data, 'http_req_duration', 'p(95)'), 'ms')}`,
    `- Duration p99: ${format(metricValue(data, 'http_req_duration', 'p(99)'), 'ms')}`,
    `- Duration max: ${format(metricValue(data, 'http_req_duration', 'max'), 'ms')}`,
    `- Checks pass rate: ${format(metricValue(data, 'checks', 'rate') * 100, '%')}`,
    `- Raver API errors: ${format(metricValue(data, 'raver_api_errors', 'count'))}`,
    '',
    '## Sizing Notes',
    '',
    '- If p95 exceeds 500ms while CPU is below 70%, inspect PostgreSQL slow queries and connection pool waits.',
    '- If CPU is above 80% and p95 rises with VUs, increase vCPU first.',
    '- If memory climbs throughout a soak run, inspect Node heap, uploads, and Prisma connection churn.',
    '- If failures are mostly 429/401, adjust test data or rate limits before changing server size.',
    '',
  ];

  return {
    stdout: `${lines.join('\n')}\n`,
    [__ENV.K6_SUMMARY_JSON || 'load-tests/results/summary.json']: JSON.stringify(data, null, 2),
    [__ENV.K6_SUMMARY_MD || 'load-tests/results/summary.md']: `${lines.join('\n')}\n`,
  };
}
