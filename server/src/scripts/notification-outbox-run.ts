import 'dotenv/config';
import { runNotificationOutboxWorkerOnce } from '../services/notification-center';

const main = async (): Promise<void> => {
  const report = await runNotificationOutboxWorkerOnce();
  console.log(JSON.stringify(report, null, 2));
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
