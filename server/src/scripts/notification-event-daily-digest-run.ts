import 'dotenv/config';
import { runEventDailyDigestJob } from '../services/notification-center';

const main = async (): Promise<void> => {
  const report = await runEventDailyDigestJob();
  console.log('[notification-event-daily-digest-run] report');
  console.log(JSON.stringify(report, null, 2));
};

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[notification-event-daily-digest-run] failed: ${message}`);
  process.exitCode = 1;
});
