import 'dotenv/config';
import { accountDeletionService } from '../services/account-deletion.service';

const parseLimit = (): number => {
  const raw = Number(process.env.ACCOUNT_DELETION_RUN_LIMIT || process.argv[2] || 20);
  if (!Number.isFinite(raw) || raw <= 0) return 20;
  return Math.min(Math.floor(raw), 100);
};

void accountDeletionService
  .processDueRequests(parseLimit())
  .then((results) => {
    const failures = results.filter((item) => !item.ok).length;
    console.log('[account-deletion] processed', {
      total: results.length,
      failures,
    });
    if (failures > 0) {
      process.exitCode = 1;
    }
  })
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[account-deletion] failed: ${message}`);
    process.exitCode = 1;
  });
