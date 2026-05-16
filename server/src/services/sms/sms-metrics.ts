export type SmsMetricOutcome = 'attempted' | 'sent' | 'failed' | 'rate_limited' | 'verify_failed' | 'verify_blocked';

export type SmsMetricReason =
  | 'cooldown'
  | 'phone_hourly_limit'
  | 'ip_hourly_limit'
  | 'provider_error'
  | 'invalid_or_expired_code'
  | 'too_many_verify_failures';

type SmsMetricEvent = {
  at: Date;
  outcome: SmsMetricOutcome;
  reason?: SmsMetricReason;
};

const smsMetricEvents: SmsMetricEvent[] = [];
const maxSmsMetricEvents = 10_000;

const pruneSmsMetricEvents = (now = Date.now()): void => {
  const oldestKeptAt = now - 30 * 24 * 60 * 60 * 1000;
  while (smsMetricEvents.length > 0 && smsMetricEvents[0].at.getTime() < oldestKeptAt) {
    smsMetricEvents.shift();
  }
  if (smsMetricEvents.length > maxSmsMetricEvents) {
    smsMetricEvents.splice(0, smsMetricEvents.length - maxSmsMetricEvents);
  }
};

export const recordSmsMetric = (outcome: SmsMetricOutcome, reason?: SmsMetricReason): void => {
  smsMetricEvents.push({ at: new Date(), outcome, reason });
  pruneSmsMetricEvents();
};

const ratio = (part: number, total: number): number => {
  if (total <= 0) return 0;
  return part / total;
};

export const getSmsMetrics = (windowHours = 24) => {
  const now = Date.now();
  pruneSmsMetricEvents(now);
  const windowMs = Math.max(1, Math.min(Math.floor(windowHours), 24 * 30)) * 60 * 60 * 1000;
  const events = smsMetricEvents.filter((event) => event.at.getTime() >= now - windowMs);
  const count = (outcome: SmsMetricOutcome): number => events.filter((event) => event.outcome === outcome).length;
  const countReason = (reason: SmsMetricReason): number => events.filter((event) => event.reason === reason).length;
  const attempted = count('attempted');
  const sent = count('sent');
  const failed = count('failed');
  const rateLimited = count('rate_limited');
  const verifyFailed = count('verify_failed');
  const verifyBlocked = count('verify_blocked');

  return {
    windowHours,
    processStartedAt: process.uptime() > 0 ? new Date(now - process.uptime() * 1000) : null,
    totals: {
      attempted,
      sent,
      failed,
      rateLimited,
      verifyFailed,
      verifyBlocked,
    },
    reasons: {
      cooldown: countReason('cooldown'),
      phoneHourlyLimit: countReason('phone_hourly_limit'),
      ipHourlyLimit: countReason('ip_hourly_limit'),
      providerError: countReason('provider_error'),
      invalidOrExpiredCode: countReason('invalid_or_expired_code'),
      tooManyVerifyFailures: countReason('too_many_verify_failures'),
    },
    rates: {
      sendFailureRate: ratio(failed, attempted),
      rateLimitRate: ratio(rateLimited, attempted + rateLimited),
      verifyFailureRate: ratio(verifyFailed, verifyFailed + sent),
    },
  };
};
