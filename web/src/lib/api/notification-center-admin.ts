const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';
const V1_BASE_URL = API_URL.endsWith('/api') ? `${API_URL.slice(0, -4)}/v1` : `${API_URL}/v1`;

type NotificationChannel = 'in_app' | 'apns' | 'openim';
type NotificationCategory =
  | 'chat_message'
  | 'community_interaction'
  | 'event_countdown'
  | 'event_daily_digest'
  | 'route_dj_reminder'
  | 'followed_dj_update'
  | 'followed_brand_update'
  | 'major_news';

export interface NotificationCenterGlobalConfig {
  categorySwitches: Record<NotificationCategory, boolean>;
  channelSwitches: Record<NotificationChannel, boolean>;
  grayRelease: {
    enabled: boolean;
    percentage: number;
    allowUserIDs: string[];
  };
  governance: {
    rateLimit: {
      enabled: boolean;
      windowSeconds: number;
      maxPerUser: number;
      exemptCategories: NotificationCategory[];
    };
    quietHours: {
      enabled: boolean;
      startHour: number;
      endHour: number;
      timezone: string;
      muteChannels: NotificationChannel[];
      exemptCategories: NotificationCategory[];
    };
  };
}

export interface NotificationCenterAPNSStatus {
  enabled: boolean;
  configured: boolean;
  providerHost: string;
  useSandbox: boolean;
  bundleId: string | null;
  keyIdMasked: string | null;
  teamIdMasked: string | null;
  privateKeySource: 'inline' | 'base64' | 'path' | 'none';
  privateKeyPath: string | null;
  missingConfig: string[];
  tokenCache: {
    active: boolean;
    expiresAt: string | null;
  };
}

export interface NotificationCenterDeliveryStats {
  since: string;
  windowHours: number;
  byChannel: Record<
    string,
    {
      sent: number;
      failed: number;
      queued: number;
      total: number;
    }
  >;
  totals: {
    sent: number;
    failed: number;
    queued: number;
    total: number;
  };
  rates: {
    deliverySuccessRate: number;
    deliveryFailureRate: number;
  };
  engagement: {
    inboxCreated: number;
    inboxRead: number;
    inboxUnread: number;
    openRate: number;
  };
  subscriptions: {
    total: number;
    disabled: number;
    disabledUpdatedInWindow: number;
    unsubscribeRate: number;
  };
  alerts: {
    triggeredCount: number;
    queueStuckThresholdMinutes: number;
    retryHighThreshold: number;
    failedRateAlertThreshold: number;
    items: Array<{
      code: string;
      severity: 'info' | 'medium' | 'high' | string;
      triggered: boolean;
      value: number;
      threshold: number;
      message: string;
    }>;
  };
}

export interface NotificationCenterStatusResponse {
  apns: NotificationCenterAPNSStatus;
  delivery: NotificationCenterDeliveryStats;
  config: NotificationCenterGlobalConfig;
}

export interface NotificationCenterDeliveryItem {
  id: string;
  eventId: string;
  userId: string;
  channel: NotificationChannel | string;
  status: string;
  error: string | null;
  attempts: number;
  deliveredAt: string | null;
  createdAt: string;
  updatedAt: string;
  event: {
    id: string;
    category: string;
    status: string;
    dedupeKey: string | null;
    createdAt: string;
    dispatchedAt: string | null;
  };
  user: {
    id: string;
    username: string;
    displayName: string | null;
  };
}

export interface NotificationCenterTemplateItem {
  id: string;
  category: NotificationCategory;
  locale: string;
  channel: NotificationChannel;
  titleTemplate: string;
  bodyTemplate: string;
  deeplinkTemplate: string | null;
  variables: unknown;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

const getToken = (): string => {
  const token = localStorage.getItem('token');
  if (!token) {
    throw new Error('请先登录');
  }
  return token;
};

const request = async <T>(path: string, init?: RequestInit): Promise<T> => {
  const token = getToken();
  const response = await fetch(`${V1_BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init?.headers || {}),
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.error || `Notification center admin request failed (${response.status})`);
  }
  return response.json();
};

export const notificationCenterAdminApi = {
  async getStatus(windowHours = 24): Promise<NotificationCenterStatusResponse> {
    const query = new URLSearchParams({ windowHours: String(windowHours) });
    const result = await request<{ success: boolean; status: NotificationCenterStatusResponse }>(
      `/notification-center/admin/status?${query.toString()}`
    );
    return result.status;
  },

  async getDeliveries(input?: {
    limit?: number;
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
  }): Promise<NotificationCenterDeliveryItem[]> {
    const query = new URLSearchParams();
    query.set('limit', String(input?.limit ?? 50));
    if (input?.channel) query.set('channel', input.channel);
    if (input?.status) query.set('status', input.status);
    if (input?.userId) query.set('userId', input.userId);
    if (input?.eventId) query.set('eventId', input.eventId);

    const result = await request<{ success: boolean; items: NotificationCenterDeliveryItem[] }>(
      `/notification-center/admin/deliveries?${query.toString()}`
    );
    return result.items;
  },

  async getConfig(): Promise<NotificationCenterGlobalConfig> {
    const result = await request<{ success: boolean; config: NotificationCenterGlobalConfig }>(
      '/notification-center/admin/config'
    );
    return result.config;
  },

  async updateConfig(config: NotificationCenterGlobalConfig): Promise<NotificationCenterGlobalConfig> {
    const result = await request<{ success: boolean; config: NotificationCenterGlobalConfig }>(
      '/notification-center/admin/config',
      {
        method: 'PUT',
        body: JSON.stringify({ config }),
      }
    );
    return result.config;
  },

  async getTemplates(input?: {
    limit?: number;
    category?: NotificationCategory;
    locale?: string;
    channel?: NotificationChannel;
    isActive?: boolean;
  }): Promise<NotificationCenterTemplateItem[]> {
    const query = new URLSearchParams();
    query.set('limit', String(input?.limit ?? 50));
    if (input?.category) query.set('category', input.category);
    if (input?.locale) query.set('locale', input.locale);
    if (input?.channel) query.set('channel', input.channel);
    if (typeof input?.isActive === 'boolean') query.set('isActive', String(input.isActive));
    const result = await request<{ success: boolean; items: NotificationCenterTemplateItem[] }>(
      `/notification-center/admin/templates?${query.toString()}`
    );
    return result.items;
  },

  async upsertTemplate(input: {
    category: NotificationCategory;
    locale: string;
    channel: NotificationChannel;
    titleTemplate: string;
    bodyTemplate: string;
    deeplinkTemplate?: string | null;
    variables?: string[];
    isActive?: boolean;
  }): Promise<NotificationCenterTemplateItem> {
    const result = await request<{ success: boolean; item: NotificationCenterTemplateItem }>(
      '/notification-center/admin/templates',
      {
        method: 'PUT',
        body: JSON.stringify(input),
      }
    );
    return result.item;
  },
};
