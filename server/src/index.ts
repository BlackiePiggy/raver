import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
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

dotenv.config();

const app: Express = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
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
app.use('/v1', bffRoutes);
app.use('/v1', bffWebRoutes);

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
  console.log(`🎵 RaveHub API Server running on http://localhost:${port}`);
});
