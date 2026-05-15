export type RegionalComplianceRegion = 'GLOBAL' | 'JP';

export type RegionalCompliancePolicy = {
  region: RegionalComplianceRegion;
  enabled: boolean;
  ageDeclarationRequired: boolean;
  minimumAge: number;
  minorAgeThreshold: number;
  minorRestrictions: {
    strangerDirectMessages: boolean;
    locationSharing: boolean;
    // External organizer/provider links only; Raver does not sell tickets or process ticket payments.
    lateNightEventTicketLinks: boolean;
    adultContentExposure: boolean;
  };
  reportPriority: {
    highestReasons: string[];
  };
  reviewNotes: {
    guardianContactUrl: string;
    minorSafetyUrl: string;
  };
};

export type RegionalComplianceUser = {
  regionCode?: string | null;
  ageBand?: string | null;
};

const normalizeRegion = (value: unknown): RegionalComplianceRegion => {
  const normalized = String(value || '').trim().toUpperCase();
  if (normalized === 'JP' || normalized === 'JAPAN') return 'JP';
  return 'GLOBAL';
};

const parseEnabledRegions = (): Set<RegionalComplianceRegion> => {
  const raw = process.env.RAVER_COMPLIANCE_REGIONS || 'JP';
  return new Set(
    raw
      .split(',')
      .map((item) => normalizeRegion(item))
      .filter((item) => item !== 'GLOBAL')
  );
};

const enabledRegions = parseEnabledRegions();

const policies: Record<RegionalComplianceRegion, RegionalCompliancePolicy> = {
  GLOBAL: {
    region: 'GLOBAL',
    enabled: true,
    ageDeclarationRequired: false,
    minimumAge: 13,
    minorAgeThreshold: 18,
    minorRestrictions: {
      strangerDirectMessages: false,
      locationSharing: false,
      lateNightEventTicketLinks: false,
      adultContentExposure: false,
    },
    reportPriority: {
      highestReasons: [],
    },
    reviewNotes: {
      guardianContactUrl: '/legal/contact',
      minorSafetyUrl: '/legal/minor-safety',
    },
  },
  JP: {
    region: 'JP',
    enabled: enabledRegions.has('JP'),
    ageDeclarationRequired: true,
    minimumAge: 13,
    minorAgeThreshold: 18,
    minorRestrictions: {
      strangerDirectMessages: true,
      locationSharing: true,
      lateNightEventTicketLinks: true,
      adultContentExposure: true,
    },
    reportPriority: {
      highestReasons: ['minor_safety'],
    },
    reviewNotes: {
      guardianContactUrl: '/legal/contact',
      minorSafetyUrl: '/legal/minor-safety',
    },
  },
};

export const regionalCompliance = {
  defaultRegion: normalizeRegion(process.env.RAVER_COMPLIANCE_DEFAULT_REGION || 'JP'),

  resolveRegion(value?: unknown): RegionalComplianceRegion {
    const region = normalizeRegion(value);
    return region === 'GLOBAL' ? this.defaultRegion : region;
  },

  policyFor(value?: unknown): RegionalCompliancePolicy {
    const region = this.resolveRegion(value);
    const policy = policies[region] ?? policies.GLOBAL;
    return policy.enabled ? policy : policies.GLOBAL;
  },

  isHighestPriorityReportReason(reason: string, region?: unknown): boolean {
    const policy = this.policyFor(region);
    return policy.reportPriority.highestReasons.includes(reason);
  },

  ageBandForBirthYear(birthYear: number, now: Date = new Date()): 'under_13' | 'minor' | 'adult' {
    const currentYear = now.getUTCFullYear();
    const age = currentYear - birthYear;
    if (age < 13) return 'under_13';
    if (age < 18) return 'minor';
    return 'adult';
  },

  isRestrictedMinor(user: RegionalComplianceUser | null | undefined, restriction: keyof RegionalCompliancePolicy['minorRestrictions']): boolean {
    const policy = this.policyFor(user?.regionCode);
    return user?.ageBand === 'minor' && policy.minorRestrictions[restriction];
  },

  shouldHideLateNightTicketLink(user: RegionalComplianceUser | null | undefined, eventStartAt: Date | string | null | undefined): boolean {
    if (!this.isRestrictedMinor(user, 'lateNightEventTicketLinks')) return false;
    if (!eventStartAt) return false;
    const start = eventStartAt instanceof Date ? eventStartAt : new Date(eventStartAt);
    if (Number.isNaN(start.getTime())) return false;
    const hour = start.getUTCHours();
    return hour >= 20 || hour < 5;
  },
};
