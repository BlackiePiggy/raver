import { getApiUrl } from '@/lib/config';
import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';

type NotificationChannel = 'in_app' | 'apns' | 'email' | 'sms';
type NotificationCategory =
  | 'chat_message'
  | 'community_interaction'
  | 'event_countdown'
  | 'event_daily_digest'
  | 'route_dj_reminder'
  | 'followed_dj_update'
  | 'followed_brand_update'
  | 'account_enforcement'
  | 'content_review'
  | 'report_decision'
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

export type NotificationCenterDeliverySection =
  | 'event_news'
  | 'event_release'
  | 'followed_dj_news'
  | 'followed_dj_event'
  | 'followed_brand_news'
  | 'followed_brand_event'
  | 'major_news_broadcast'
  | 'event_schedule'
  | 'chat_and_community'
  | 'moderation_and_system'
  | 'other';

export type NotificationAdminPublishTaskType =
  | 'news_release'
  | 'event_release'
  | 'dj_release'
  | 'brand_release';
export type NotificationAdminPublishTaskStatus = 'pending' | 'published' | 'rejected';

export interface NotificationAdminPublishAudienceSummary {
  key: string;
  label: string;
  entityCount: number;
  targetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    targetUserCount: number;
  }>;
}

export interface NotificationAdminPublishTaskContext {
  kind: NotificationAdminPublishTaskType;
  entity: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    occurredAt: string;
    startDate: string | null;
    timeZone: string | null;
  };
  audiences: NotificationAdminPublishAudienceSummary[];
}

export interface NotificationAdminPublishTaskItem {
  id: string;
  taskType: NotificationAdminPublishTaskType;
  entityType: string;
  entityId: string;
  status: NotificationAdminPublishTaskStatus;
  title: string;
  summary: string | null;
  createdBy: string | null;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface NotificationAdminPublishTaskPage {
  items: NotificationAdminPublishTaskItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface NotificationAdminPublishTaskDetailResponse {
  task: NotificationAdminPublishTaskItem | null;
  context: NotificationAdminPublishTaskContext | null;
}

export interface NotificationAdminPublishExecutionResult {
  success: boolean;
  kind: NotificationAdminPublishTaskType;
  entity: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    occurredAt: string;
    startDate: string | null;
    timeZone: string | null;
  };
  audiences: Array<{
    key: string;
    label: string;
    entityCount: number;
    targetUserCount: number;
    dedupeKeys: string[];
    results: Array<{
      entityId: string;
      entityName: string;
      targetUserCount: number;
      publishResult: Array<{
        channel: NotificationChannel | string;
        success: boolean;
        detail?: string;
      }>;
    }>;
  }>;
}

export type NotificationManualAudienceType =
  | 'direct_users'
  | 'followed_dj'
  | 'followed_brand'
  | 'favorited_event';

export type NotificationManualRelatedEntityType =
  | 'news'
  | 'event'
  | 'dj'
  | 'festival'
  | 'label';

export interface NotificationManualAudienceEntityInput {
  id: string;
  name?: string | null;
  entityType?: string | null;
}

export interface NotificationManualRelatedEntityContext {
  type: NotificationManualRelatedEntityType;
  id: string;
  title: string;
  summary: string;
  deeplink: string | null;
  imageUrl: string | null;
}

export interface NotificationManualContentContext {
  headline: string;
  summary: string;
  deeplink: string | null;
  imageUrl: string | null;
  relatedEntity: NotificationManualRelatedEntityContext | null;
}

export interface NotificationManualAudienceSummary {
  type: NotificationManualAudienceType;
  label: string;
  entityCount: number;
  targetUserCount: number;
  uniqueTargetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    entityType?: string | null;
    targetUserCount: number;
  }>;
}

export interface NotificationManualPreview {
  content: NotificationManualContentContext;
  audiences: NotificationManualAudienceSummary[];
  totals: {
    selectedEntityCount: number;
    totalTargetAssignments: number;
    totalUniqueTargetUsers: number;
  };
}

export interface NotificationManualExecutionResult {
  success: boolean;
  content: NotificationManualContentContext;
  audiences: Array<
    NotificationManualAudienceSummary & {
      dedupeKeys: string[];
      results: Array<{
        entityId: string;
        entityName: string;
        entityType?: string | null;
        targetUserCount: number;
        publishResult: Array<{
          channel: NotificationChannel | string;
          success: boolean;
          detail?: string;
        }>;
      }>;
    }
  >;
  totals: {
    selectedEntityCount: number;
    totalTargetAssignments: number;
    totalUniqueTargetUsers: number;
  };
}

export interface NotificationCenterDeliverySectionSummary {
  section: NotificationCenterDeliverySection;
  total: number;
  apnsCount: number;
  inAppCount: number;
  failedCount: number;
  lastDeliveryAt: string | null;
}

export interface NotificationCenterDeliverySectionItem {
  id: string;
  section: NotificationCenterDeliverySection;
  eventId: string;
  userId: string;
  channel: NotificationChannel | string;
  status: string;
  error: string | null;
  attempts: number;
  deliveredAt: string | null;
  createdAt: string;
  updatedAt: string;
  payload: {
    title: string | null;
    body: string | null;
    deeplink: string | null;
  };
  metadata: {
    route: string | null;
    source: string | null;
    newsId: string | null;
    newsTitle: string | null;
    eventId: string | null;
    eventName: string | null;
    djId: string | null;
    djName: string | null;
    brandId: string | null;
    brandName: string | null;
    audience: string | null;
  };
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

export interface NotificationCenterDeliverySectionPage {
  section: NotificationCenterDeliverySection;
  items: NotificationCenterDeliverySectionItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface AdminNewsPublishAudienceSummary {
  key: 'event_news' | 'followed_dj_news' | 'followed_brand_news';
  label: string;
  entityCount: number;
  targetUserCount: number;
  entities: Array<{
    id: string;
    name: string;
    targetUserCount: number;
  }>;
}

export interface AdminNewsPublishContext {
  article: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    publishedAt: string;
  };
  audiences: AdminNewsPublishAudienceSummary[];
}

export interface AdminNewsPublishResult {
  success: boolean;
  article: {
    id: string;
    title: string;
    summary: string;
    coverImageURL: string | null;
    deeplink: string;
    publishedAt: string;
  };
  audiences: Array<{
    key: 'event_news' | 'followed_dj_news' | 'followed_brand_news';
    label: string;
    entityCount: number;
    targetUserCount: number;
    dedupeKeys: string[];
    results: Array<{
      entityId: string;
      entityName: string;
      targetUserCount: number;
      publishResult: Array<{
        channel: NotificationChannel | string;
        success: boolean;
        detail?: string;
      }>;
    }>;
  }>;
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

const request = async <T>(path: string, init?: RequestInit): Promise<T> => {
  return authenticatedJsonFetch<T>(getApiUrl(`/admin/v1${path}`), init);
};

export const notificationCenterAdminApi = {
  async getStatus(windowHours = 24): Promise<NotificationCenterStatusResponse> {
    const query = new URLSearchParams({ windowHours: String(windowHours) });
    const result = await request<{ success: boolean; status: NotificationCenterStatusResponse }>(
      `/notifications/status?${query.toString()}`
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
      `/notifications/deliveries?${query.toString()}`
    );
    return result.items;
  },

  async getDeliverySections(input?: {
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
    query?: string;
  }): Promise<NotificationCenterDeliverySectionSummary[]> {
    const query = new URLSearchParams();
    if (input?.channel) query.set('channel', input.channel);
    if (input?.status) query.set('status', input.status);
    if (input?.userId) query.set('userId', input.userId);
    if (input?.eventId) query.set('eventId', input.eventId);
    if (input?.query) query.set('query', input.query);
    const result = await request<{ success: boolean; items: NotificationCenterDeliverySectionSummary[] }>(
      `/notifications/deliveries/sections${query.toString() ? `?${query.toString()}` : ''}`
    );
    return result.items;
  },

  async getDeliveriesBySection(input: {
    section: NotificationCenterDeliverySection;
    page?: number;
    limit?: number;
    channel?: NotificationChannel;
    status?: string;
    userId?: string;
    eventId?: string;
    query?: string;
  }): Promise<NotificationCenterDeliverySectionPage> {
    const query = new URLSearchParams();
    query.set('section', input.section);
    query.set('page', String(input.page ?? 1));
    query.set('limit', String(input.limit ?? 20));
    if (input.channel) query.set('channel', input.channel);
    if (input.status) query.set('status', input.status);
    if (input.userId) query.set('userId', input.userId);
    if (input.eventId) query.set('eventId', input.eventId);
    if (input.query) query.set('query', input.query);
    const result = await request<{ success: boolean } & NotificationCenterDeliverySectionPage>(
      `/notifications/deliveries/by-section?${query.toString()}`
    );
    return {
      section: result.section,
      items: result.items,
      pagination: result.pagination,
    };
  },

  async getPublishTasks(input?: {
    page?: number;
    limit?: number;
    status?: NotificationAdminPublishTaskStatus;
    taskType?: NotificationAdminPublishTaskType;
    query?: string;
  }): Promise<NotificationAdminPublishTaskPage> {
    const query = new URLSearchParams();
    query.set('page', String(input?.page ?? 1));
    query.set('limit', String(input?.limit ?? 20));
    if (input?.status) query.set('status', input.status);
    if (input?.taskType) query.set('taskType', input.taskType);
    if (input?.query) query.set('query', input.query);
    const result = await request<{ success: boolean } & NotificationAdminPublishTaskPage>(
      `/notifications/publish-tasks?${query.toString()}`
    );
    return {
      items: result.items,
      pagination: result.pagination,
    };
  },

  async getPublishTaskByEntity(input: {
    taskType: NotificationAdminPublishTaskType;
    entityType: string;
    entityId: string;
  }): Promise<NotificationAdminPublishTaskDetailResponse> {
    const query = new URLSearchParams({
      taskType: input.taskType,
      entityType: input.entityType,
      entityId: input.entityId,
    });
    const result = await request<{ success: boolean } & NotificationAdminPublishTaskDetailResponse>(
      `/notifications/publish-tasks/by-entity?${query.toString()}`
    );
    return {
      task: result.task,
      context: result.context,
    };
  },

  async getPublishTask(id: string): Promise<NotificationAdminPublishTaskDetailResponse> {
    const result = await request<{ success: boolean } & NotificationAdminPublishTaskDetailResponse>(
      `/notifications/publish-tasks/${encodeURIComponent(id)}`
    );
    return {
      task: result.task,
      context: result.context,
    };
  },

  async publishTask(input: {
    taskId: string;
    audienceKeys?: string[];
    channels?: Array<'in_app' | 'apns'>;
    dedupeSalt?: string;
  }): Promise<{
    success: boolean;
    task: NotificationAdminPublishTaskItem | null;
    result: NotificationAdminPublishExecutionResult;
  }> {
    const { taskId, ...body } = input;
    return request(`/notifications/publish-tasks/${encodeURIComponent(taskId)}/publish`, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  },

  async rejectTask(input: {
    taskId: string;
    reason?: string;
  }): Promise<{
    success: boolean;
    task: NotificationAdminPublishTaskItem | null;
  }> {
    const { taskId, ...body } = input;
    return request(`/notifications/publish-tasks/${encodeURIComponent(taskId)}/reject`, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  },

  async previewManualPublish(input: {
    content: {
      headline?: string;
      summary?: string;
      deeplink?: string | null;
      imageUrl?: string | null;
      relatedEntity?: {
        type: NotificationManualRelatedEntityType;
        id: string;
      } | null;
    };
    audiences: Array<{
      type: NotificationManualAudienceType;
      entities: NotificationManualAudienceEntityInput[];
    }>;
  }): Promise<NotificationManualPreview> {
    const result = await request<{ success: boolean; preview: NotificationManualPreview }>(
      '/notifications/manual-publish/preview',
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return result.preview;
  },

  async publishManual(input: {
    content: {
      headline?: string;
      summary?: string;
      deeplink?: string | null;
      imageUrl?: string | null;
      relatedEntity?: {
        type: NotificationManualRelatedEntityType;
        id: string;
      } | null;
    };
    audiences: Array<{
      type: NotificationManualAudienceType;
      entities: NotificationManualAudienceEntityInput[];
    }>;
    channels?: Array<'in_app' | 'apns'>;
    dedupeSalt?: string;
  }): Promise<NotificationManualExecutionResult> {
    const result = await request<{ success: boolean; result: NotificationManualExecutionResult }>(
      '/notifications/manual-publish',
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return result.result;
  },

  async getNewsPublishContext(newsId: string): Promise<AdminNewsPublishContext> {
    const result = await request<{ success: boolean; context: AdminNewsPublishContext }>(
      `/notifications/news/${encodeURIComponent(newsId)}/publish-context`
    );
    return result.context;
  },

  async publishNewsNotification(input: {
    newsId: string;
    audienceKeys: Array<'event_news' | 'followed_dj_news' | 'followed_brand_news'>;
    channels?: Array<'in_app' | 'apns'>;
    dedupeSalt?: string;
  }): Promise<AdminNewsPublishResult> {
    const { newsId, ...body } = input;
    return request<AdminNewsPublishResult>(`/notifications/news/${encodeURIComponent(newsId)}/publish`, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  },

  async getConfig(): Promise<NotificationCenterGlobalConfig> {
    const result = await request<{ success: boolean; config: NotificationCenterGlobalConfig }>(
      '/notifications/config'
    );
    return result.config;
  },

  async updateConfig(config: NotificationCenterGlobalConfig): Promise<NotificationCenterGlobalConfig> {
    const result = await request<{ success: boolean; config: NotificationCenterGlobalConfig }>(
      '/notifications/config',
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
      `/notifications/templates?${query.toString()}`
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
      '/notifications/templates',
      {
        method: 'PUT',
        body: JSON.stringify(input),
      }
    );
    return result.item;
  },
};
