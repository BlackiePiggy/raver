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
const authEmailHeroImageUrl = cleanEnv(process.env.AUTH_EMAIL_HERO_IMAGE_URL);

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

const escapeHtml = (value: string): string =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const buildAuthCodePlainText = (input: SendAuthCodeInput): string => {
  const actionText = input.scene === 'register' ? 'complete your registration' : 'sign in';
  return [
    `Your RaveHub verification code is ${input.code}.`,
    `Use it to ${actionText}.`,
    'This code will expire in 5 minutes.',
    'For your account security, please do not share this code with anyone.',
    'If you did not request this email, you can safely ignore it.',
  ].join('\n');
};

const buildAuthCodeEmailHtml = (input: SendAuthCodeInput): string => {
  const code = escapeHtml(input.code);
  const title = input.scene === 'register' ? 'Verify your email' : 'Verify your login';
  const intro = input.scene === 'register'
    ? 'Thank you for joining RaveHub.<br>Please use the verification code below to complete your registration.'
    : 'Welcome back to RaveHub.<br>Please use the verification code below to sign in to your account.';
  const hero = authEmailHeroImageUrl
    ? `
    <div class="hero">
      <img src="${escapeHtml(authEmailHeroImageUrl)}" alt="RaveHub Artwork">
    </div>`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RaveHub Email Verification</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;700&display=swap');

  body {
    margin: 0;
    padding: 24px 0;
    background-color: #f7f7f7;
    font-family: 'Rajdhani', Arial, sans-serif;
    color: #333333;
  }

  .email-container {
    max-width: 640px;
    margin: 0 auto;
    background-color: #ffffff;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid #e6e6e6;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  }

  .nav {
    padding: 16px 24px;
    background-color: #ffffff;
    border-bottom: 1px solid #e6e6e6;
    font-size: 14px;
  }

  .nav-table {
    width: 100%;
    border-collapse: collapse;
  }

  .logo {
    font-size: 20px;
    font-weight: 700;
    letter-spacing: 2px;
    color: #222222;
    white-space: nowrap;
  }

  .links {
    text-align: right;
    white-space: nowrap;
  }

  .links a {
    margin-left: 18px;
    text-decoration: none;
    color: #666666;
    font-weight: 500;
  }

  .hero img {
    display: block;
    width: 100%;
    height: auto;
    border-bottom: 1px solid #e6e6e6;
  }

  .content {
    padding: 40px 32px;
    text-align: left;
    line-height: 1.6;
  }

  .welcome {
    font-size: 12px;
    letter-spacing: 2px;
    color: #888888;
    text-transform: uppercase;
    margin-bottom: 8px;
  }

  .title {
    font-size: 28px;
    font-weight: 700;
    margin: 0 0 20px 0;
    color: #222222;
  }

  .content p {
    font-size: 16px;
    margin: 8px 0;
    color: #555555;
  }

  .otp-container {
    margin: 24px 0;
    border: 1px solid #dddddd;
    border-radius: 8px;
    padding: 24px 16px;
    text-align: center;
    background-color: #fdfdfd;
  }

  .otp-label {
    font-size: 12px;
    color: #888888;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 12px;
  }

  .otp {
    font-size: 36px;
    letter-spacing: 12px;
    font-weight: 700;
    color: #222222;
  }

  .otp-note {
    margin-top: 12px;
    font-size: 12px;
    color: #666666;
  }

  .divider {
    height: 1px;
    background-color: #e6e6e6;
    margin: 32px 0;
  }

  .tips {
    font-size: 14px;
    color: #555555;
  }

  .tip {
    margin-bottom: 12px;
  }

  .tip-icon {
    width: 24px;
    vertical-align: top;
    color: #888888;
  }

  .tip-text {
    vertical-align: top;
  }

  .footer {
    padding: 32px 24px;
    font-size: 12px;
    color: #888888;
    text-align: left;
    border-top: 1px solid #e6e6e6;
  }

  .footer .tagline {
    margin-top: 8px;
    font-size: 14px;
    color: #666666;
  }

  .social {
    margin-top: 16px;
  }

  .social a {
    margin-right: 16px;
    text-decoration: none;
    color: #888888;
    font-size: 14px;
  }

  @media screen and (max-width: 480px) {
    body {
      padding: 0;
    }
    .email-container {
      border-radius: 0;
      border-left: 0;
      border-right: 0;
    }
    .links {
      display: none;
    }
    .otp {
      font-size: 28px;
      letter-spacing: 8px;
    }
    .content {
      padding: 24px 16px;
    }
  }
</style>
</head>
<body>
  <div class="email-container">
    <div class="nav">
      <table class="nav-table" role="presentation">
        <tr>
          <td class="logo">RAVEHUB</td>
          <td class="links">
            <a href="#">Community</a>
            <a href="#">Events</a>
            <a href="#">Magazine</a>
            <a href="#">About</a>
          </td>
        </tr>
      </table>
    </div>
${hero}
    <div class="content">
      <div class="welcome">Welcome to RaveHub</div>
      <div class="title">${escapeHtml(title)}</div>
      <p>${intro}</p>

      <div class="otp-container">
        <div class="otp-label">Your verification code</div>
        <div class="otp">${code}</div>
        <div class="otp-note">This code will expire in <strong>5&nbsp;minutes</strong>. Please use it as soon as possible.</div>
      </div>

      <div class="divider"></div>

      <table class="tips" role="presentation">
        <tr class="tip">
          <td class="tip-icon">🔒</td>
          <td class="tip-text">For your account security, please do not share this code with anyone.</td>
        </tr>
        <tr class="tip">
          <td class="tip-icon">❓</td>
          <td class="tip-text">If you did not request this email, please ignore it or reset your password.</td>
        </tr>
        <tr class="tip">
          <td class="tip-icon">📩</td>
          <td class="tip-text">Need help? Reply to this email or contact the RaveHub team.</td>
        </tr>
      </table>
    </div>

    <div class="footer">
      <strong>RaveHub</strong><br>
      <span class="tagline">The community for ravers. Built by ravers.</span>
      <div class="social">
        <a href="#">Instagram</a>
        <a href="#">Discord</a>
        <a href="#">YouTube</a>
        <a href="#">Spotify</a>
      </div>
      <p style="margin-top: 16px;">&copy; 2026 RaveHub Team. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`;
};

class ResendEmailProvider implements EmailProvider {
  private readonly client: Resend;

  constructor() {
    ensureResendConfig();
    this.client = new Resend(resendApiKey!);
  }

  async sendAuthCode(input: SendAuthCodeInput): Promise<void> {
    const actionText = input.scene === 'register' ? 'Registration' : 'Login';
    const startedAt = Date.now();
    let result;
    try {
      result = await this.client.emails.send({
        from: resendFromEmail!,
        to: input.email,
        subject: `RaveHub ${actionText} Verification Code`,
        html: buildAuthCodeEmailHtml(input),
        text: buildAuthCodePlainText(input),
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
