import crypto from 'crypto';
import { openIMConfig } from './openim-config';

export interface OpenIMWebhookVerifyInput {
  rawBody: Buffer;
  signature: string | null;
  timestamp: string | null;
  nonce: string | null;
}

export interface OpenIMWebhookVerifyResult {
  valid: boolean;
  reason: string;
}

const normalizeSignature = (signature: string): string => {
  const trimmed = signature.trim();
  if (trimmed.toLowerCase().startsWith('sha256=')) {
    return trimmed.slice(7).trim();
  }
  return trimmed;
};

const parseTimestampMillis = (timestamp: string | null): number | null => {
  if (!timestamp) {
    return null;
  }
  const trimmed = timestamp.trim();
  if (!trimmed) {
    return null;
  }
  const numeric = Number(trimmed);
  if (!Number.isFinite(numeric)) {
    return null;
  }
  if (numeric > 1_000_000_000_000) {
    return Math.floor(numeric);
  }
  return Math.floor(numeric * 1000);
};

const timingSafeCompare = (left: string, right: string): boolean => {
  const leftBuffer = Buffer.from(left, 'utf8');
  const rightBuffer = Buffer.from(right, 'utf8');
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
};

const buildSignatureCandidates = (secret: string, rawBody: Buffer, timestamp: string, nonce: string): string[] => {
  const rawText = rawBody.toString('utf8');
  const messages = [
    rawText,
    `${timestamp}.${rawText}`,
    `${timestamp}.${nonce}.${rawText}`,
  ];

  const outputs = new Set<string>();
  for (const message of messages) {
    const digest = crypto.createHmac('sha256', secret).update(message).digest();
    outputs.add(digest.toString('hex'));
    outputs.add(digest.toString('base64'));
  }
  return Array.from(outputs);
};

export const openIMWebhookService = {
  verifySignature(input: OpenIMWebhookVerifyInput): OpenIMWebhookVerifyResult {
    const secret = openIMConfig.webhookSecret;
    const signatureRequired = openIMConfig.webhookRequireSignature;

    if (!secret) {
      return {
        valid: !signatureRequired,
        reason: signatureRequired ? 'missing-webhook-secret' : 'signature-skipped-no-secret',
      };
    }

    if (!input.signature) {
      return {
        valid: false,
        reason: 'missing-signature',
      };
    }

    if (!input.timestamp) {
      return {
        valid: false,
        reason: 'missing-timestamp',
      };
    }

    const timestampMillis = parseTimestampMillis(input.timestamp);
    if (!timestampMillis) {
      return {
        valid: false,
        reason: 'invalid-timestamp',
      };
    }

    const toleranceSeconds = Math.max(1, openIMConfig.webhookToleranceSeconds);
    const driftMillis = Math.abs(Date.now() - timestampMillis);
    if (driftMillis > toleranceSeconds * 1000) {
      return {
        valid: false,
        reason: 'timestamp-out-of-window',
      };
    }

    const normalizedSignature = normalizeSignature(input.signature);
    if (!normalizedSignature) {
      return {
        valid: false,
        reason: 'empty-signature',
      };
    }

    const nonce = input.nonce?.trim() || '';
    const candidates = buildSignatureCandidates(secret, input.rawBody, input.timestamp, nonce);
    const matched = candidates.some((candidate) => timingSafeCompare(normalizedSignature, candidate));
    return {
      valid: matched,
      reason: matched ? 'ok' : 'signature-mismatch',
    };
  },
};
