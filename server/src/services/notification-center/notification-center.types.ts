export type NotificationChannel = 'in_app' | 'apns' | 'openim';

export type NotificationCategory =
  | 'chat_message'
  | 'community_interaction'
  | 'event_countdown'
  | 'event_daily_digest'
  | 'route_dj_reminder'
  | 'followed_dj_update'
  | 'followed_brand_update'
  | 'major_news';

export interface NotificationTarget {
  userId: string;
}

export interface NotificationPayload {
  title: string;
  body: string;
  deeplink?: string | null;
  badgeDelta?: number;
  metadata?: Record<string, unknown>;
}

export interface NotificationEvent {
  id: string;
  category: NotificationCategory;
  targets: NotificationTarget[];
  channels: NotificationChannel[];
  payload: NotificationPayload;
  dedupeKey?: string;
  createdAt: Date;
}

export interface NotificationPublishInput {
  category: NotificationCategory;
  targets: NotificationTarget[];
  channels: NotificationChannel[];
  payload: NotificationPayload;
  dedupeKey?: string;
}

export interface NotificationDeliveryResult {
  channel: NotificationChannel;
  success: boolean;
  detail?: string;
  targetResults?: Array<{
    userId: string;
    success: boolean;
    detail?: string;
    attempts?: number;
    deliveredAt?: Date;
  }>;
}

export interface RegisterDevicePushTokenInput {
  userId: string;
  deviceId: string;
  platform: string;
  pushToken: string;
  appVersion?: string;
  locale?: string;
}

export interface NotificationChannelHandler {
  deliver(event: NotificationEvent): Promise<NotificationDeliveryResult>;
}
