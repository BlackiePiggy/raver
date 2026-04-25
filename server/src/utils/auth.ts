import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';

const LEGACY_JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
const LEGACY_JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';
const ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET || LEGACY_JWT_SECRET;
const ACCESS_TOKEN_EXPIRES_IN = process.env.ACCESS_TOKEN_EXPIRES_IN || LEGACY_JWT_EXPIRES_IN;
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || '30d';

const toDurationMs = (input: string | number, fallbackMs: number): number => {
  if (typeof input === 'number' && Number.isFinite(input) && input > 0) {
    return input * 1000;
  }

  const text = String(input || '').trim().toLowerCase();
  const matched = text.match(/^(\d+)(ms|s|m|h|d)?$/);
  if (!matched) return fallbackMs;

  const amount = Number(matched[1]);
  if (!Number.isFinite(amount) || amount <= 0) return fallbackMs;
  const unit = matched[2] || 's';

  switch (unit) {
    case 'ms':
      return amount;
    case 's':
      return amount * 1000;
    case 'm':
      return amount * 60 * 1000;
    case 'h':
      return amount * 60 * 60 * 1000;
    case 'd':
      return amount * 24 * 60 * 60 * 1000;
    default:
      return fallbackMs;
  }
};

export const ACCESS_TOKEN_TTL_MS = toDurationMs(ACCESS_TOKEN_EXPIRES_IN, 15 * 60 * 1000);
export const REFRESH_TOKEN_TTL_MS = toDurationMs(REFRESH_TOKEN_EXPIRES_IN, 30 * 24 * 60 * 60 * 1000);
export const ACCESS_TOKEN_TTL_SECONDS = Math.max(1, Math.floor(ACCESS_TOKEN_TTL_MS / 1000));
export const REFRESH_TOKEN_TTL_SECONDS = Math.max(1, Math.floor(REFRESH_TOKEN_TTL_MS / 1000));

export interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

export const hashPassword = async (password: string): Promise<string> => {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};

export const comparePassword = async (
  password: string,
  hashedPassword: string
): Promise<boolean> => {
  return bcrypt.compare(password, hashedPassword);
};

export const generateAccessToken = (payload: JWTPayload): string => {
  return jwt.sign(payload, ACCESS_TOKEN_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRES_IN } as jwt.SignOptions);
};

export const verifyAccessToken = (token: string): JWTPayload => {
  return jwt.verify(token, ACCESS_TOKEN_SECRET) as JWTPayload;
};

// Backward-compatible aliases.
export const generateToken = generateAccessToken;
export const verifyToken = verifyAccessToken;

export const generateRefreshToken = (): string => {
  return crypto.randomBytes(48).toString('base64url');
};

export const hashToken = (token: string): string => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

export const isTokenHashMatch = (rawToken: string, storedHash: string): boolean => {
  const rawHashBuffer = Buffer.from(hashToken(rawToken), 'utf8');
  const storedHashBuffer = Buffer.from(storedHash, 'utf8');
  if (rawHashBuffer.length !== storedHashBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(rawHashBuffer, storedHashBuffer);
};
