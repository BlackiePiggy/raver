export type AuthEnvValidationOptions = {
  nodeEnv?: string;
  env?: NodeJS.ProcessEnv;
};

export type AuthEnvValidationResult = {
  errors: string[];
  warnings: string[];
  summary: {
    nodeEnv: string;
    accessTokenExpiresIn: string;
    refreshTokenExpiresIn: string;
    webAdminRefreshTtlMs: string;
    webAdminIdleTtlMs: string;
  };
};

const DEFAULT_LEGACY_JWT_SECRET = 'your-super-secret-jwt-key-change-in-production';
const DEFAULT_ACCESS_TOKEN_EXPIRES_IN = '7d';
const REQUIRED_REFRESH_TOKEN_EXPIRES_IN = '30d';
const RECOMMENDED_ACCESS_TOKEN_EXPIRES_IN = '15m';

const cleanEnv = (value: unknown): string => String(value || '').trim();

const isProductionLike = (nodeEnv: string): boolean => nodeEnv === 'production';

const isPlaceholderSecret = (value: string): boolean => {
  const normalized = value.trim().toLowerCase();
  return !normalized
    || normalized === DEFAULT_LEGACY_JWT_SECRET
    || normalized.includes('change-in-production')
    || normalized.includes('change_me')
    || normalized.includes('changeme')
    || normalized.includes('your-secret')
    || normalized.includes('super-secret');
};

const read = (env: NodeJS.ProcessEnv, key: string): string => cleanEnv(env[key]);

export const validateAuthEnv = (
  options: AuthEnvValidationOptions = {}
): AuthEnvValidationResult => {
  const env = options.env || process.env;
  const nodeEnv = cleanEnv(options.nodeEnv || env.NODE_ENV || 'development') || 'development';
  const production = isProductionLike(nodeEnv);
  const errors: string[] = [];
  const warnings: string[] = [];

  const jwtSecret = read(env, 'JWT_SECRET');
  const accessTokenSecret = read(env, 'ACCESS_TOKEN_SECRET');
  const accessTokenExpiresIn = read(env, 'ACCESS_TOKEN_EXPIRES_IN') || read(env, 'JWT_EXPIRES_IN') || DEFAULT_ACCESS_TOKEN_EXPIRES_IN;
  const refreshTokenExpiresIn = read(env, 'REFRESH_TOKEN_EXPIRES_IN') || REQUIRED_REFRESH_TOKEN_EXPIRES_IN;
  const webAdminRefreshTtlMs = read(env, 'AUTH_WEB_ADMIN_REFRESH_TTL_MS') || String(12 * 60 * 60 * 1000);
  const webAdminIdleTtlMs = read(env, 'AUTH_WEB_ADMIN_IDLE_TTL_MS') || String(30 * 60 * 1000);

  if (production) {
    if (!accessTokenSecret) {
      errors.push('ACCESS_TOKEN_SECRET is required in production.');
    }
    if (isPlaceholderSecret(accessTokenSecret)) {
      errors.push('ACCESS_TOKEN_SECRET must not be empty or use a placeholder/default value in production.');
    }
    if (jwtSecret && isPlaceholderSecret(jwtSecret)) {
      errors.push('JWT_SECRET must not use the default placeholder value in production.');
    }
    if (!refreshTokenExpiresIn) {
      errors.push('REFRESH_TOKEN_EXPIRES_IN is required in production.');
    }
    if (refreshTokenExpiresIn !== REQUIRED_REFRESH_TOKEN_EXPIRES_IN) {
      errors.push(`REFRESH_TOKEN_EXPIRES_IN must be ${REQUIRED_REFRESH_TOKEN_EXPIRES_IN} for the current iOS commercial session target.`);
    }
    if (!accessTokenExpiresIn) {
      errors.push('ACCESS_TOKEN_EXPIRES_IN is required in production.');
    }
    if (accessTokenExpiresIn !== RECOMMENDED_ACCESS_TOKEN_EXPIRES_IN) {
      warnings.push(`ACCESS_TOKEN_EXPIRES_IN is ${accessTokenExpiresIn}; recommended commercial value is ${RECOMMENDED_ACCESS_TOKEN_EXPIRES_IN}.`);
    }
  } else {
    if (!accessTokenSecret && !jwtSecret) {
      warnings.push('ACCESS_TOKEN_SECRET/JWT_SECRET is not set; development will fall back to the legacy default secret.');
    }
  }

  return {
    errors,
    warnings,
    summary: {
      nodeEnv,
      accessTokenExpiresIn,
      refreshTokenExpiresIn,
      webAdminRefreshTtlMs,
      webAdminIdleTtlMs,
    },
  };
};

export const assertAuthEnvReady = (options: AuthEnvValidationOptions = {}): AuthEnvValidationResult => {
  const result = validateAuthEnv(options);
  if (result.errors.length > 0) {
    const details = result.errors.map((error) => `- ${error}`).join('\n');
    throw new Error(`Auth environment validation failed:\n${details}`);
  }
  return result;
};

export const formatAuthEnvSummary = (result: AuthEnvValidationResult): string => {
  const { summary } = result;
  return [
    `nodeEnv=${summary.nodeEnv}`,
    `ACCESS_TOKEN_EXPIRES_IN=${summary.accessTokenExpiresIn}`,
    `REFRESH_TOKEN_EXPIRES_IN=${summary.refreshTokenExpiresIn}`,
    `AUTH_WEB_ADMIN_REFRESH_TTL_MS=${summary.webAdminRefreshTtlMs}`,
    `AUTH_WEB_ADMIN_IDLE_TTL_MS=${summary.webAdminIdleTtlMs}`,
  ].join(' ');
};
