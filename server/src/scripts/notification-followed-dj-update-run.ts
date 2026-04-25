import 'dotenv/config';
import { runFollowedDJUpdateJob } from '../services/notification-center';

const main = async (): Promise<void> => {
  const report = await runFollowedDJUpdateJob();
  console.log('[notification-followed-dj-update-run] report');
  console.log(JSON.stringify(report, null, 2));
};

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[notification-followed-dj-update-run] failed: ${message}`);
  process.exitCode = 1;
});
