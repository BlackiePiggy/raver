import { mediaAssetService } from './media-asset.service';

let timer: NodeJS.Timeout | null = null;
let running = false;

const parseIntervalMs = (): number => {
  const value = Number(process.env.MEDIA_ASSET_PURGE_INTERVAL_MS);
  if (Number.isFinite(value) && value >= 60_000) {
    return Math.floor(value);
  }
  return 10 * 60 * 1000;
};

const parseBatchSize = (): number => {
  const value = Number(process.env.MEDIA_ASSET_PURGE_BATCH_SIZE);
  if (Number.isFinite(value) && value >= 1 && value <= 100) {
    return Math.floor(value);
  }
  return 20;
};

const runOnce = async (): Promise<void> => {
  if (running) return;
  running = true;
  try {
    const result = await mediaAssetService.purgePendingAssets(parseBatchSize());
    if (result.scannedCount > 0) {
      console.info('[media-assets] purge completed', result);
    }
  } catch (error) {
    console.error('[media-assets] purge failed:', error);
  } finally {
    running = false;
  }
};

export const startMediaAssetPurgeScheduler = (): void => {
  if (timer) return;
  if (process.env.MEDIA_ASSET_PURGE_DISABLED === 'true') return;

  const intervalMs = parseIntervalMs();
  timer = setInterval(() => {
    void runOnce();
  }, intervalMs);
  timer.unref?.();

  setTimeout(() => {
    void runOnce();
  }, 15_000).unref?.();
};
