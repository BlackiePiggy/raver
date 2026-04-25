import 'dotenv/config';
import { runRouteDJReminderJob } from '../services/notification-center';

const main = async (): Promise<void> => {
  const report = await runRouteDJReminderJob();
  console.log('[notification-route-dj-reminder-run] report');
  console.log(JSON.stringify(report, null, 2));
};

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[notification-route-dj-reminder-run] failed: ${message}`);
  process.exitCode = 1;
});
