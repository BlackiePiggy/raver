import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';

type CacheScope = 'memory' | 'disk';

type CacheEnvelope<T> = {
  expiresAt: number;
  payload: T;
  snapshotVersion: string;
  storedAt: string;
};

type MemoryEntry = {
  expiresAt: number;
  payload: unknown;
  snapshotVersion: string;
};

type GetInput = {
  namespace: string;
  key: string;
  snapshotVersion: string;
};

type SetInput<T> = {
  namespace: string;
  key: string;
  ttlMs: number;
  snapshotVersion: string;
  payload: T;
};

const DEFAULT_CACHE_DIR = path.resolve(process.cwd(), '.cache/admin-summary');

class AdminSummaryCacheService {
  private readonly memory = new Map<string, MemoryEntry>();
  private readonly cacheDir = process.env.RAVER_ADMIN_SUMMARY_CACHE_DIR?.trim() || DEFAULT_CACHE_DIR;
  private readonly diskEnabled = process.env.RAVER_ADMIN_SUMMARY_CACHE_DISABLE_DISK !== '1';

  private buildEntryId(namespace: string, key: string): string {
    return `${namespace}:${key}`;
  }

  private buildFilePath(namespace: string, key: string): string {
    const digest = crypto.createHash('sha1').update(key).digest('hex');
    return path.join(this.cacheDir, namespace, `${digest}.json`);
  }

  private isExpired(expiresAt: number): boolean {
    return !Number.isFinite(expiresAt) || expiresAt <= Date.now();
  }

  async get<T>(input: GetInput): Promise<{ payload: T; scope: CacheScope } | null> {
    const entryId = this.buildEntryId(input.namespace, input.key);
    const memoryEntry = this.memory.get(entryId);
    if (memoryEntry) {
      if (
        memoryEntry.snapshotVersion === input.snapshotVersion &&
        !this.isExpired(memoryEntry.expiresAt)
      ) {
        return {
          payload: memoryEntry.payload as T,
          scope: 'memory',
        };
      }
      this.memory.delete(entryId);
    }

    if (!this.diskEnabled) return null;

    const filePath = this.buildFilePath(input.namespace, input.key);
    try {
      const raw = await fs.readFile(filePath, 'utf-8');
      const parsed = JSON.parse(raw) as CacheEnvelope<T>;
      if (
        parsed.snapshotVersion !== input.snapshotVersion ||
        this.isExpired(parsed.expiresAt)
      ) {
        await fs.rm(filePath, { force: true }).catch(() => undefined);
        return null;
      }

      this.memory.set(entryId, {
        expiresAt: parsed.expiresAt,
        payload: parsed.payload,
        snapshotVersion: parsed.snapshotVersion,
      });

      return {
        payload: parsed.payload,
        scope: 'disk',
      };
    } catch (error) {
      const code =
        error && typeof error === 'object' && 'code' in error
          ? String((error as { code?: unknown }).code || '')
          : '';
      if (code !== 'ENOENT') {
        console.warn('Admin summary cache read failed:', error);
      }
      return null;
    }
  }

  async set<T>(input: SetInput<T>): Promise<void> {
    const entryId = this.buildEntryId(input.namespace, input.key);
    const expiresAt = Date.now() + Math.max(1, input.ttlMs);

    this.memory.set(entryId, {
      expiresAt,
      payload: input.payload,
      snapshotVersion: input.snapshotVersion,
    });

    if (!this.diskEnabled) return;

    const filePath = this.buildFilePath(input.namespace, input.key);
    const envelope: CacheEnvelope<T> = {
      expiresAt,
      payload: input.payload,
      snapshotVersion: input.snapshotVersion,
      storedAt: new Date().toISOString(),
    };

    try {
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(filePath, JSON.stringify(envelope), 'utf-8');
    } catch (error) {
      console.warn('Admin summary cache write failed:', error);
    }
  }
}

export const adminSummaryCache = new AdminSummaryCacheService();
