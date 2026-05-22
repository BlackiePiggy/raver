import 'dotenv/config';
import {
  assertAuthEnvReady,
  formatAuthEnvSummary,
} from '../config/auth-env';

const main = (): void => {
  try {
    const result = assertAuthEnvReady();
    console.log(`Auth env lint passed: ${formatAuthEnvSummary(result)}`);
    for (const warning of result.warnings) {
      console.warn(`Auth env warning: ${warning}`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(message);
    process.exitCode = 1;
  }
};

main();
