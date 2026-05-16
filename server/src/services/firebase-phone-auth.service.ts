import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import fs from 'fs';

type FirebasePhoneAuthConfig = {
  projectId: string | null;
  serviceAccountJson: string | null;
  serviceAccountPath: string | null;
};

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const readConfig = (): FirebasePhoneAuthConfig => ({
  projectId: cleanEnv(process.env.FIREBASE_PROJECT_ID) || cleanEnv(process.env.GOOGLE_CLOUD_PROJECT),
  serviceAccountJson: cleanEnv(process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
  serviceAccountPath: cleanEnv(process.env.FIREBASE_SERVICE_ACCOUNT_PATH),
});

const initializeFirebaseAdmin = (): void => {
  if (getApps().length > 0) return;

  const config = readConfig();
  const serviceAccountJson = config.serviceAccountJson
    ?? (config.serviceAccountPath ? fs.readFileSync(config.serviceAccountPath, 'utf8') : null);
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson) as Record<string, unknown>;
    initializeApp({
      credential: cert(serviceAccount),
      projectId: config.projectId || String(serviceAccount.project_id || ''),
    });
    return;
  }

  initializeApp({
    credential: applicationDefault(),
    ...(config.projectId ? { projectId: config.projectId } : {}),
  });
};

const isFirebasePhoneAuthMockEnabled = (): boolean => {
  if (process.env.NODE_ENV === 'production') return false;

  const raw = String(process.env.AUTH_FIREBASE_PHONE_MOCK || '').trim().toLowerCase();
  if (['0', 'false', 'no', 'off'].includes(raw)) return false;
  return true;
};

export const verifyFirebasePhoneIdToken = async (idToken: string): Promise<{ uid: string; phoneNumber: string }> => {
  if (isFirebasePhoneAuthMockEnabled()) {
    const [prefix, phoneNumber, uid] = idToken.split(':');
    if (prefix === 'mock-firebase-phone' && phoneNumber) {
      return { uid: uid || `mock:${phoneNumber}`, phoneNumber };
    }
    throw new Error('firebase_phone_mock_token_invalid');
  }

  initializeFirebaseAdmin();
  const decoded = await getAuth().verifyIdToken(idToken, true);
  const phoneNumber = typeof decoded.phone_number === 'string' ? decoded.phone_number : '';
  if (!phoneNumber) {
    throw new Error('firebase_phone_number_missing');
  }
  return {
    uid: decoded.uid,
    phoneNumber,
  };
};

export const getFirebasePhoneAuthStatus = () => {
  const config = readConfig();
  return {
    configured: Boolean(config.projectId || config.serviceAccountJson || process.env.GOOGLE_APPLICATION_CREDENTIALS),
    projectIdConfigured: Boolean(config.projectId),
    serviceAccountJsonConfigured: Boolean(config.serviceAccountJson),
    serviceAccountPathConfigured: Boolean(config.serviceAccountPath),
    googleApplicationCredentialsConfigured: Boolean(cleanEnv(process.env.GOOGLE_APPLICATION_CREDENTIALS)),
    mockEnabled: isFirebasePhoneAuthMockEnabled(),
  };
};
