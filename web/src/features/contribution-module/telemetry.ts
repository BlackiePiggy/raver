'use client';

export type ContributionModuleTelemetryEvent =
  | 'contribution_tab_exposure'
  | 'contributor_list_profile_tapped';

type ContributionModuleTelemetryPayload = Record<string, string | number | boolean | null | undefined>;

export function trackContributionModuleEvent(
  event: ContributionModuleTelemetryEvent,
  properties: ContributionModuleTelemetryPayload = {}
): void {
  const payload = {
    event,
    properties,
    at: new Date().toISOString(),
  };

  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('raver:contribution-module-telemetry', { detail: payload }));

    const telemetryWindow = window as typeof window & { dataLayer?: unknown[] };
    if (Array.isArray(telemetryWindow.dataLayer)) {
      telemetryWindow.dataLayer.push(payload);
    }
  }

  if (process.env.NODE_ENV !== 'production') {
    console.info('[contribution-module-telemetry]', payload);
  }
}
