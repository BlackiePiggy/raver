import { Resend } from 'resend';

type SendAuthCodeInput = {
  email: string;
  code: string;
  scene: 'login' | 'register';
};

interface EmailProvider {
  sendAuthCode(input: SendAuthCodeInput): Promise<void>;
}

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const emailProviderType = (cleanEnv(process.env.AUTH_EMAIL_PROVIDER) || 'mock').toLowerCase();
const resendApiKey = cleanEnv(process.env.RESEND_API_KEY);
const resendFromEmail = cleanEnv(process.env.RESEND_FROM_EMAIL);

const ensureResendConfig = (): void => {
  const missing: string[] = [];
  if (!resendApiKey) missing.push('RESEND_API_KEY');
  if (!resendFromEmail) missing.push('RESEND_FROM_EMAIL');
  if (missing.length > 0) {
    throw new Error(`Resend config missing: ${missing.join(', ')}`);
  }
};

const maskEmail = (email: string): string => {
  const trimmed = email.trim().toLowerCase();
  const [localPart, domain] = trimmed.split('@');
  if (!localPart || !domain) return '***';
  const visible = localPart.slice(0, Math.min(2, localPart.length));
  return `${visible}***@${domain}`;
};

class ResendEmailProvider implements EmailProvider {
  private readonly client: Resend;

  constructor() {
    ensureResendConfig();
    this.client = new Resend(resendApiKey!);
  }

  async sendAuthCode(input: SendAuthCodeInput): Promise<void> {
    const actionText = input.scene === 'register' ? '注册' : '登录';
    const startedAt = Date.now();
    let result;
    try {
      result = await this.client.emails.send({
        from: resendFromEmail!,
        to: input.email,
        subject: `Raver ${actionText}验证码`,
        text: `你的 Raver ${actionText}验证码是 ${input.code}，5 分钟内有效。如果这不是你的操作，请忽略这封邮件。`,
      });
    } finally {
      console.info('[perf]', {
        scope: 'auth.email_send',
        step: 'resend.emails.send',
        durationMs: Date.now() - startedAt,
        email: maskEmail(input.email),
        scene: input.scene,
      });
    }

    if (result.error) {
      throw new Error(`Resend email error: ${result.error.message}`);
    }

    console.info('[email] resend send success', {
      email: maskEmail(input.email),
      scene: input.scene,
      id: result.data?.id || null,
    });
  }
}

class MockEmailProvider implements EmailProvider {
  async sendAuthCode(input: SendAuthCodeInput): Promise<void> {
    console.info('[email] mock send code', {
      email: maskEmail(input.email),
      scene: input.scene,
      code: input.code,
    });
  }
}

const buildProvider = (): EmailProvider => {
  if (emailProviderType === 'resend') {
    try {
      return new ResendEmailProvider();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (process.env.NODE_ENV === 'production') {
        throw new Error(`[email] resend provider unavailable in production: ${message}`);
      }
      console.error(`[email] resend provider unavailable, fallback to mock: ${message}`);
      return new MockEmailProvider();
    }
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('AUTH_EMAIL_PROVIDER=resend is required in production');
  }
  return new MockEmailProvider();
};

export const emailProvider: EmailProvider = buildProvider();

export const emailService = {
  async sendAuthCode(email: string, code: string, scene: 'login' | 'register'): Promise<void> {
    await emailProvider.sendAuthCode({ email, code, scene });
  },
};
