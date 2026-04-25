import 'dotenv/config';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import path from 'path';
import authRoutes from './routes/auth.routes';
import eventRoutes from './routes/event.routes';
import djRoutes from './routes/dj.routes';
import checkinRoutes from './routes/checkin.routes';
import followRoutes from './routes/follow.routes';
import djSetRoutes from './routes/djset.routes';
import djAggregatorRoutes from './routes/dj-aggregator.routes';
import musicRoutes from './routes/music.routes';
import commentRoutes from './routes/comment.routes';
import squadRoutes from './routes/squad.routes';
import notificationRoutes from './routes/notification.routes';
import labelRoutes from './routes/label.routes';
import bffRoutes from './routes/bff.routes';
import bffWebRoutes from './routes/bff.web.routes';
import openIMRoutes from './routes/openim.routes';
import preRegistrationRoutes from './routes/pre-registration.routes';
import notificationCenterRoutes from './routes/notification-center.routes';
import { openIMSyncJobService } from './services/openim/openim-sync-job.service';
import {
  registerNotificationCenterAPNSHandler,
  startNotificationEventCountdownScheduler,
  startNotificationEventDailyDigestScheduler,
  startNotificationRouteDJReminderScheduler,
  startNotificationFollowedDJUpdateScheduler,
  startNotificationFollowedBrandUpdateScheduler,
  startNotificationOutboxWorker,
} from './services/notification-center';

const app: Express = express();
const port = process.env.PORT || 3901;

const detectProxyEnv = (): string | null => {
  const keys = [
    'HTTPS_PROXY',
    'https_proxy',
    'HTTP_PROXY',
    'http_proxy',
    'ALL_PROXY',
    'all_proxy',
  ] as const;
  for (const key of keys) {
    const value = process.env[key];
    if (typeof value === 'string' && value.trim()) {
      return `${key}=${value.trim()}`;
    }
  }
  return null;
};

const hasUseEnvProxyFlag = (): boolean => {
  const nodeOptions = String(process.env.NODE_OPTIONS || '');
  return process.execArgv.includes('--use-env-proxy') || nodeOptions.includes('--use-env-proxy');
};

const captureRawBody = (req: Request, _res: Response, buf: Buffer): void => {
  if (!buf || buf.length === 0) {
    return;
  }
  (req as Request & { rawBody?: Buffer }).rawBody = Buffer.from(buf);
};

// Middleware
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '512kb', verify: captureRawBody }));
app.use(express.urlencoded({ extended: true, limit: '512kb', verify: captureRawBody }));
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/djs', djRoutes);
app.use('/api/checkins', checkinRoutes);
app.use('/api/follows', followRoutes);
app.use('/api/dj-sets', djSetRoutes);
app.use('/api/dj-sets', commentRoutes);
app.use('/api', commentRoutes);
app.use('/api/dj-aggregator', djAggregatorRoutes);
app.use('/api/music', musicRoutes);
app.use('/api/squads', squadRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/labels', labelRoutes);
app.use('/api', preRegistrationRoutes);
app.use('/v1', bffRoutes);
app.use('/v1', bffWebRoutes);
app.use('/v1/openim', openIMRoutes);
app.use('/v1/notification-center', notificationCenterRoutes);
registerNotificationCenterAPNSHandler();

app.get('/api', (_req: Request, res: Response) => {
  res.json({
    message: 'RaveHub API Server',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      api: '/api',
      auth: '/api/auth',
      events: '/api/events',
      djs: '/api/djs',
      checkins: '/api/checkins',
      follows: '/api/follows',
      djSets: '/api/dj-sets',
      djAggregator: '/api/dj-aggregator',
      squads: '/api/squads',
      notifications: '/api/notifications',
      labels: '/api/labels',
      preRegistrations: '/api/pre-registrations',
      preRegistrationAdmin: '/api/admin/pre-registrations',
      bffV1: '/v1',
    },
  });
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not Found' });
});

// Error handler
app.use((err: Error, _req: Request, res: Response) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal Server Error' });
});

app.listen(port, () => {
  const proxyHint = detectProxyEnv();
  if (proxyHint) {
    if (hasUseEnvProxyFlag()) {
      console.log(`🌐 Proxy enabled via --use-env-proxy (${proxyHint})`);
    } else {
      console.warn(`⚠️ Proxy env detected but --use-env-proxy is not enabled (${proxyHint})`);
    }
  }
  console.log(`🎵 RaveHub API Server running on http://localhost:${port}`);
  openIMSyncJobService.startWorker();
  startNotificationEventCountdownScheduler();
  startNotificationEventDailyDigestScheduler();
  startNotificationRouteDJReminderScheduler();
  startNotificationFollowedDJUpdateScheduler();
  startNotificationFollowedBrandUpdateScheduler();
  startNotificationOutboxWorker();
});
