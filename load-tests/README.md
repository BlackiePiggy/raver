# Raver Backend Load Tests

These k6 scripts estimate backend capacity for the iOS-facing API.

## Quick Start

Run a smoke load against local backend:

```bash
BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh smoke
```

Run an iOS-like mixed load:

```bash
BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh ios-mixed
```

Run with an existing test account:

```bash
BASE_URL=https://api.example.com \
LOAD_AUTH_USER=test_user \
LOAD_AUTH_PASSWORD='Passw0rd!' \
./load-tests/run.sh ios-mixed
```

Results are written to `load-tests/results/`:

- `summary.json`: aggregated k6 metrics
- `summary.md`: readable report
- `samples.json`: raw k6 metric samples

## Profiles

Set `PROFILE` to control pressure:

```bash
PROFILE=baseline BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh ios-mixed
PROFILE=step     BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh ios-mixed
PROFILE=stress   BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh ios-mixed
PROFILE=soak     BASE_URL=http://127.0.0.1:3901 ./load-tests/run.sh ios-mixed
```

Suggested meaning:

- `smoke`: verify script and endpoint availability.
- `baseline`: small production-like load.
- `step`: ramp through several concurrency levels to find the knee point.
- `stress`: push until latency/error thresholds break.
- `soak`: long run for memory leaks and DB connection leaks.

## Important Environment Variables

- `BASE_URL`: backend origin, for example `http://127.0.0.1:3901`.
- `LOAD_AUTH_USER`: existing username/email/phone for login.
- `LOAD_AUTH_PASSWORD`: password for `LOAD_AUTH_USER`.
- `LOAD_REGISTER_USERS=1`: allow setup to create one throwaway test user if no login is provided.
- `K6_PROXY`: optional proxy for k6 HTTP traffic.

## What To Watch On The Server

During each run, collect these on the backend host:

```bash
top -pid $(pgrep -f 'node dist/index.js' | head -1)
```

For Docker:

```bash
docker stats
```

For PostgreSQL:

```sql
select count(*) from pg_stat_activity;
select query, calls, mean_exec_time, max_exec_time
from pg_stat_statements
order by mean_exec_time desc
limit 20;
```

Capacity target for an early production sizing pass:

- `http_req_failed < 1%`
- `p95 < 500ms`
- `p99 < 1200ms`
- backend CPU stable below 70%
- memory does not continuously climb during a soak test
- PostgreSQL connections do not hit the pool/database limit
