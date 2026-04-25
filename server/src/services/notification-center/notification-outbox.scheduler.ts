import { notificationCenterService } from './notification-center.service';

const readBoolEnv = (key: string, fallback: boolean): boolean => {
  const raw = process.env[key];
  if (typeof raw !== 'string') return fallback;
  const normalized = raw.trim().toLowerCase();
  if (normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on') return true;
  if (normalized === '0' || normalized === 'false' || normalized === 'no' || normalized === 'off') return false;
  return fallback;
};

const readIntEnv = (key: string, fallback: number, min: number, max: number): number => {
  const raw = process.env[key];
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  const normalized = Math.floor(parsed);
  if (normalized < min) return min;
  if (normalized > max) return max;
  return normalized;
};

const OUTBOX_CONFIG = {
  asyncModeEnabled: readBoolEnv('NOTIFICATION_OUTBOX_ASYNC_ENABLED', false),
  workerEnabled: readBoolEnv('NOTIFICATION_OUTBOX_WORKER_ENABLED', false),
  intervalMs: readIntEnv('NOTIFICATION_OUTBOX_WORKER_INTERVAL_MS', 5000, 1000, 10 * 60 * 1000),
  eventLimit: readIntEnv('NOTIFICATION_OUTBOX_WORKER_EVENT_LIMIT', 20, 1, 200),
};

let timer: NodeJS.Timeout | null = null;
let inFlight = false;

export const runNotificationOutboxWorkerOnce = async () => {
  return notificationCenterService.dispatchQueuedEvents({
    eventLimit: OUTBOX_CONFIG.eventLimit,
  });
};

const tick = async (): Promise<void> => {
  if (inFlight) {
    return;
  }
  inFlight = true;
  try {
    const report = await runNotificationOutboxWorkerOnce();
    if (report.processedEvents > 0 || report.scannedEvents > 0 || report.errors.length > 0) {
      console.log(
        `[notification-center][outbox-worker] run completed enabled=${report.enabled} scanned=${report.scannedEvents} processed=${report.processedEvents} sent=${report.sentDeliveries} failed=${report.failedDeliveries} skipped=${report.skippedEvents} errors=${report.errors.length}`
      );
      for (const error of report.errors) {
        console.error(`[notification-center][outbox-worker] ${error}`);
      }
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[notification-center][outbox-worker] run failed: ${message}`);
  } finally {
    inFlight = false;
  }
};

export const startNotificationOutboxWorker = (): void => {
  if (!OUTBOX_CONFIG.asyncModeEnabled) {
    console.log('[notification-center][outbox-worker] async mode disabled');
    return;
  }
  if (!OUTBOX_CONFIG.workerEnabled) {
    console.log('[notification-center][outbox-worker] worker disabled');
    return;
  }
  if (timer) {
    return;
  }

  timer = setInterval(() => {
    void tick();
  }, OUTBOX_CONFIG.intervalMs);
  timer.unref();

  console.log(
    `[notification-center][outbox-worker] started intervalMs=${OUTBOX_CONFIG.intervalMs} eventLimit=${OUTBOX_CONFIG.eventLimit}`
  );

  void tick();
};

export const stopNotificationOutboxWorker = (): void => {
  if (!timer) {
    return;
  }
  clearInterval(timer);
  timer = null;
  console.log('[notification-center][outbox-worker] stopped');
};
