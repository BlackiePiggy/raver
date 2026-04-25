import 'dotenv/config';
import assert from 'node:assert/strict';

type AuthLoginResponse = {
  token?: string;
  accessToken?: string;
  user?: {
    id: string;
    username: string;
  };
  error?: string;
};

type PublishResultTarget = {
  userId: string;
  success: boolean;
  detail?: string;
  attempts?: number;
  deliveredAt?: string;
};

type PublishResultChannel = {
  channel: 'in_app' | 'apns' | 'openim' | string;
  success: boolean;
  detail?: string;
  targetResults?: PublishResultTarget[];
};

type PublishTestResponse = {
  success: boolean;
  results: PublishResultChannel[];
};

type DeliveryItem = {
  id: string;
  eventId: string;
  userId: string;
  channel: 'in_app' | 'apns' | 'openim' | string;
  status: 'queued' | 'sent' | 'failed' | string;
  error: string | null;
  attempts: number;
  createdAt: string;
  updatedAt: string;
  deliveredAt: string | null;
  event?: {
    id: string;
    category: string;
    status: string;
    createdAt: string;
    dispatchedAt: string | null;
  };
};

type DeliveriesResponse = {
  success: boolean;
  items: DeliveryItem[];
};

type AdminStatusResponse = {
  success: boolean;
  status: {
    delivery: {
      byChannel?: Record<string, { sent: number; failed: number; queued: number; total: number }>;
      totals?: { sent: number; failed: number; queued: number; total: number };
      alerts?: {
        triggeredCount?: number;
        items?: Array<{ code: string; triggered: boolean; message?: string }>;
      };
    };
  };
};

type VerifyConfig = {
  baseUrl: string;
  username: string;
  password: string;
  targetUserId?: string;
  channels: Array<'in_app' | 'apns' | 'openim'>;
  rounds: number;
  timeoutMs: number;
  pollIntervalMs: number;
  requireQueuedDetail: boolean;
  maxQueuedDrift: number;
  category: string;
};

const readBool = (raw: string | undefined, fallback: boolean): boolean => {
  if (typeof raw !== 'string') return fallback;
  const normalized = raw.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
};

const readInt = (raw: string | undefined, fallback: number, min: number, max: number): number => {
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  const normalized = Math.floor(parsed);
  if (normalized < min) return min;
  if (normalized > max) return max;
  return normalized;
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const isoNow = (): string => new Date().toISOString();

const toMs = (value: string): number => {
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const buildConfig = (): VerifyConfig => {
  const baseUrl = (process.env.NOTIFICATION_GRAY_BASE_URL || 'http://localhost:3901').replace(/\/+$/, '');
  const username = (process.env.NOTIFICATION_GRAY_ADMIN_USERNAME || 'uploadtester').trim();
  const password = process.env.NOTIFICATION_GRAY_ADMIN_PASSWORD || '123456';
  const targetUserId = process.env.NOTIFICATION_GRAY_TARGET_USER_ID?.trim() || undefined;

  const channelsRaw: Array<'in_app' | 'apns' | 'openim'> = (process.env.NOTIFICATION_GRAY_CHANNELS || 'in_app,apns')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter((item): item is 'in_app' | 'apns' | 'openim' => item === 'in_app' || item === 'apns' || item === 'openim');
  const channels: Array<'in_app' | 'apns' | 'openim'> = channelsRaw.length > 0 ? channelsRaw : ['in_app', 'apns'];

  return {
    baseUrl,
    username,
    password,
    targetUserId,
    channels,
    rounds: readInt(process.env.NOTIFICATION_GRAY_ROUNDS, 3, 1, 20),
    timeoutMs: readInt(process.env.NOTIFICATION_GRAY_TIMEOUT_MS, 60_000, 10_000, 10 * 60 * 1000),
    pollIntervalMs: readInt(process.env.NOTIFICATION_GRAY_POLL_INTERVAL_MS, 2_000, 500, 60_000),
    requireQueuedDetail: readBool(process.env.NOTIFICATION_GRAY_REQUIRE_QUEUED_DETAIL, true),
    maxQueuedDrift: readInt(process.env.NOTIFICATION_GRAY_MAX_QUEUED_DRIFT, 0, 0, 100),
    category: (process.env.NOTIFICATION_GRAY_CATEGORY || 'major_news').trim() || 'major_news',
  };
};

const requestJSON = async <T>(params: {
  baseUrl: string;
  path: string;
  method?: string;
  token?: string;
  body?: Record<string, unknown>;
}): Promise<T> => {
  const response = await fetch(`${params.baseUrl}${params.path}`, {
    method: params.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(params.token ? { Authorization: `Bearer ${params.token}` } : {}),
    },
    body: params.body ? JSON.stringify(params.body) : undefined,
  });

  const text = await response.text();
  let json: unknown = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = text;
  }

  if (!response.ok) {
    throw new Error(`[${params.method || 'GET'} ${params.path}] status=${response.status} body=${JSON.stringify(json)}`);
  }

  return json as T;
};

const login = async (config: VerifyConfig): Promise<{ token: string; userId?: string; username?: string }> => {
  const data = await requestJSON<AuthLoginResponse>({
    baseUrl: config.baseUrl,
    path: '/v1/auth/login',
    method: 'POST',
    body: {
      username: config.username,
      password: config.password,
    },
  });

  const token = data.token || data.accessToken;
  assert.ok(token, 'admin login failed: missing token/accessToken');
  return {
    token,
    userId: data.user?.id,
    username: data.user?.username,
  };
};

const fetchStatus = async (config: VerifyConfig, token: string): Promise<AdminStatusResponse> => {
  return requestJSON<AdminStatusResponse>({
    baseUrl: config.baseUrl,
    path: '/v1/notification-center/admin/status?windowHours=1',
    token,
  });
};

const fetchDeliveries = async (config: VerifyConfig, token: string, userId: string, limit = 200): Promise<DeliveryItem[]> => {
  const data = await requestJSON<DeliveriesResponse>({
    baseUrl: config.baseUrl,
    path: `/v1/notification-center/admin/deliveries?limit=${limit}&userId=${encodeURIComponent(userId)}`,
    token,
  });
  return Array.isArray(data.items) ? data.items : [];
};

const publishRound = async (config: VerifyConfig, token: string, targetUserId: string, round: number): Promise<PublishTestResponse> => {
  const stamp = Date.now();
  return requestJSON<PublishTestResponse>({
    baseUrl: config.baseUrl,
    path: '/v1/notification-center/admin/publish-test',
    method: 'POST',
    token,
    body: {
      category: config.category,
      title: `[outbox-gray][r${round}] ${stamp}`,
      message: `gray verify round ${round} @ ${new Date(stamp).toISOString()}`,
      channels: config.channels,
      targetUserIds: [targetUserId],
    },
  });
};

const checkQueuedDetail = (publish: PublishTestResponse, config: VerifyConfig): string[] => {
  const failures: string[] = [];

  const resultMap = new Map(publish.results.map((item) => [item.channel, item]));
  for (const channel of config.channels) {
    const row = resultMap.get(channel);
    if (!row) {
      failures.push(`publish result missing channel=${channel}`);
      continue;
    }

    if (!row.success) {
      failures.push(`publish channel=${channel} success=false detail=${row.detail || 'n/a'}`);
      continue;
    }

    if (config.requireQueuedDetail && channel !== 'in_app') {
      const detail = (row.detail || '').toLowerCase();
      if (!detail.includes('queued-for-worker')) {
        failures.push(
          `channel=${channel} did not return queued-for-worker (detail=${row.detail || 'n/a'}), async mode may be disabled`
        );
      }
    }
  }

  return failures;
};

const evaluateRoundDeliveries = (input: {
  deliveries: DeliveryItem[];
  channels: Array<'in_app' | 'apns' | 'openim'>;
  roundStartMs: number;
}): {
  done: boolean;
  detail: string;
  byChannel: Record<string, { total: number; queued: number; sent: number; failed: number; failedWithoutError: number }>;
} => {
  const relevant = input.deliveries.filter((item) => {
    if (!input.channels.includes(item.channel as 'in_app' | 'apns' | 'openim')) return false;
    return toMs(item.createdAt) >= input.roundStartMs - 2000;
  });

  const byChannel: Record<string, { total: number; queued: number; sent: number; failed: number; failedWithoutError: number }> = {};
  for (const channel of input.channels) {
    byChannel[channel] = { total: 0, queued: 0, sent: 0, failed: 0, failedWithoutError: 0 };
  }

  for (const item of relevant) {
    const bucket = byChannel[item.channel] || (byChannel[item.channel] = { total: 0, queued: 0, sent: 0, failed: 0, failedWithoutError: 0 });
    bucket.total += 1;
    if (item.status === 'queued' || item.status === 'dispatching') {
      bucket.queued += 1;
    } else if (item.status === 'sent') {
      bucket.sent += 1;
    } else if (item.status === 'failed') {
      bucket.failed += 1;
      if (!item.error || !item.error.trim()) {
        bucket.failedWithoutError += 1;
      }
    }
  }

  const channelMissing = input.channels.filter((channel) => (byChannel[channel]?.total || 0) === 0);
  const hasQueued = input.channels.some((channel) => (byChannel[channel]?.queued || 0) > 0);
  const failedWithoutError = input.channels.some((channel) => (byChannel[channel]?.failedWithoutError || 0) > 0);
  const inAppSentOk = !input.channels.includes('in_app') || (byChannel.in_app?.sent || 0) > 0;
  const apnsTerminalOk =
    !input.channels.includes('apns') ||
    ((byChannel.apns?.sent || 0) > 0 || (byChannel.apns?.failed || 0) > 0);

  const done = channelMissing.length === 0 && !hasQueued && !failedWithoutError && inAppSentOk && apnsTerminalOk;
  const detail = [
    `channels=${input.channels.join(',')}`,
    `missing=${channelMissing.join(',') || 'none'}`,
    `queued=${input.channels.map((c) => `${c}:${byChannel[c]?.queued || 0}`).join('|')}`,
    `sent=${input.channels.map((c) => `${c}:${byChannel[c]?.sent || 0}`).join('|')}`,
    `failed=${input.channels.map((c) => `${c}:${byChannel[c]?.failed || 0}`).join('|')}`,
    `failedWithoutError=${failedWithoutError}`,
    `inAppSentOk=${inAppSentOk}`,
    `apnsTerminalOk=${apnsTerminalOk}`,
  ].join(' ');

  return {
    done,
    detail,
    byChannel,
  };
};

const verifyOneRound = async (input: {
  config: VerifyConfig;
  token: string;
  targetUserId: string;
  round: number;
}): Promise<{ passed: boolean; summary: string; roundDurationMs: number }> => {
  const { config, token, targetUserId, round } = input;
  const roundStartMs = Date.now();

  const publish = await publishRound(config, token, targetUserId, round);
  if (!publish.success) {
    return {
      passed: false,
      summary: `round=${round} publish success=false`,
      roundDurationMs: Date.now() - roundStartMs,
    };
  }

  const queuedDetailFailures = checkQueuedDetail(publish, config);
  if (queuedDetailFailures.length > 0) {
    return {
      passed: false,
      summary: `round=${round} publish check failed: ${queuedDetailFailures.join('; ')}`,
      roundDurationMs: Date.now() - roundStartMs,
    };
  }

  const deadline = roundStartMs + config.timeoutMs;
  let lastDetail = 'no-deliveries-yet';

  while (Date.now() <= deadline) {
    const deliveries = await fetchDeliveries(config, token, targetUserId);
    const verdict = evaluateRoundDeliveries({
      deliveries,
      channels: config.channels,
      roundStartMs,
    });
    lastDetail = verdict.detail;

    if (verdict.done) {
      return {
        passed: true,
        summary: `round=${round} passed ${verdict.detail}`,
        roundDurationMs: Date.now() - roundStartMs,
      };
    }

    await sleep(config.pollIntervalMs);
  }

  return {
    passed: false,
    summary: `round=${round} timeout after ${config.timeoutMs}ms, ${lastDetail}`,
    roundDurationMs: Date.now() - roundStartMs,
  };
};

const verifyGlobalHealth = (input: {
  before: AdminStatusResponse;
  after: AdminStatusResponse;
  config: VerifyConfig;
}): { passed: boolean; details: string[] } => {
  const details: string[] = [];

  const beforeByChannel = input.before.status.delivery.byChannel || {};
  const afterByChannel = input.after.status.delivery.byChannel || {};
  const beforeQueued = beforeByChannel.apns?.queued || 0;
  const afterQueued = afterByChannel.apns?.queued || 0;

  if (afterQueued > beforeQueued + input.config.maxQueuedDrift) {
    details.push(`apns queued drift too high: before=${beforeQueued} after=${afterQueued} allowedDrift=${input.config.maxQueuedDrift}`);
  }

  const alerts = input.after.status.delivery.alerts?.items || [];
  const stuckAlerts = alerts.filter((item) =>
    item.triggered && (item.code === 'event_queue_stuck' || item.code === 'delivery_queue_stuck')
  );
  if (stuckAlerts.length > 0) {
    details.push(
      `queue stuck alerts triggered: ${stuckAlerts.map((item) => `${item.code}:${item.message || 'triggered'}`).join('; ')}`
    );
  }

  return {
    passed: details.length === 0,
    details,
  };
};

const main = async (): Promise<void> => {
  const config = buildConfig();

  console.log(`[${isoNow()}] outbox gray verify start`);
  console.log(
    JSON.stringify(
      {
        baseUrl: config.baseUrl,
        username: config.username,
        targetUserId: config.targetUserId || '(auto-from-login)',
        channels: config.channels,
        rounds: config.rounds,
        timeoutMs: config.timeoutMs,
        pollIntervalMs: config.pollIntervalMs,
        requireQueuedDetail: config.requireQueuedDetail,
        maxQueuedDrift: config.maxQueuedDrift,
        category: config.category,
      },
      null,
      2
    )
  );

  const auth = await login(config);
  const token = auth.token;
  const targetUserId = config.targetUserId || auth.userId;
  assert.ok(targetUserId, 'target user id is required (set NOTIFICATION_GRAY_TARGET_USER_ID or ensure login response includes user.id)');

  const beforeStatus = await fetchStatus(config, token);
  const roundResults: Array<{ passed: boolean; summary: string; roundDurationMs: number }> = [];

  for (let round = 1; round <= config.rounds; round += 1) {
    console.log(`[${isoNow()}] round ${round}/${config.rounds} start`);
    const roundResult = await verifyOneRound({
      config,
      token,
      targetUserId,
      round,
    });
    roundResults.push(roundResult);
    console.log(`[${isoNow()}] ${roundResult.summary} durationMs=${roundResult.roundDurationMs}`);

    if (!roundResult.passed) {
      break;
    }
  }

  const afterStatus = await fetchStatus(config, token);
  const globalHealth = verifyGlobalHealth({
    before: beforeStatus,
    after: afterStatus,
    config,
  });

  const failedRounds = roundResults.filter((item) => !item.passed);
  const passedRounds = roundResults.filter((item) => item.passed).length;
  const overallPassed = failedRounds.length === 0 && passedRounds === config.rounds && globalHealth.passed;

  console.log('\n===== OUTBOX GRAY VERIFY REPORT =====');
  console.log(`targetUserId=${targetUserId}`);
  console.log(`roundsPassed=${passedRounds}/${config.rounds}`);
  if (failedRounds.length > 0) {
    for (const failed of failedRounds) {
      console.log(`roundFailure=${failed.summary}`);
    }
  }
  if (!globalHealth.passed) {
    for (const detail of globalHealth.details) {
      console.log(`globalFailure=${detail}`);
    }
  }

  if (!overallPassed) {
    console.log('result=FAIL');
    process.exit(1);
  }

  console.log('result=PASS');
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
