import 'dotenv/config';
import { runEventCountdownJob } from '../services/notification-center';

const main = async (): Promise<void> => {
  const report = await runEventCountdownJob();
  console.log('[notification-event-countdown-run] report');
  console.log(JSON.stringify(report, null, 2));
};

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[notification-event-countdown-run] failed: ${message}`);
  process.exitCode = 1;
});
