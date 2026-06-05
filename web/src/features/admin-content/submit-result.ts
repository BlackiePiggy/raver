import type { NotificationAdminPublishTaskType } from '@/lib/api/notification-center-admin';

export type AdminContentSubmitEntityType = 'label' | 'dj' | 'festival' | 'news_article';
export type AdminContentSubmitFlow = 'create' | 'edit';
export type AdminContentSubmitOutcome = 'created' | 'submitted';

export type AdminContentSubmitResultState = {
  entityType: AdminContentSubmitEntityType;
  flow: AdminContentSubmitFlow;
  outcome: AdminContentSubmitOutcome;
  entityId?: string | null;
  entityName?: string | null;
  submissionId?: string | null;
  message?: string | null;
};

export type AdminContentSubmitResultContent = {
  entityType: AdminContentSubmitEntityType;
  entityLabel: string;
  title: string;
  message: string;
  catalogHref: string;
  catalogLabel: string;
  primaryHref: string;
  primaryLabel: string;
  secondaryHref: string;
  secondaryLabel: string;
  historyPrompt:
    | {
        entityType: string;
        entityId: string;
        secondaryHref: string;
        secondaryLabel: string;
        description: string;
      }
    | null;
  publishTask:
    | {
        taskType: NotificationAdminPublishTaskType;
        entityType: string;
        entityId: string;
        mode: AdminContentSubmitFlow;
      }
    | null;
  supplementaryAction:
    | {
        href: string;
        label: string;
        description: string;
      }
    | null;
};

type AdminContentSubmitEntityConfig = {
  label: string;
  catalogHref: string;
  catalogLabel: string;
  editHref: (entityId: string | null) => string;
  createdMessage: string;
  updatedMessage: string;
  historyEntityType: string;
  historySecondaryLabel: string;
  historyCreateDescription: string;
  historyEditDescription: string;
  publishTaskType?: NotificationAdminPublishTaskType;
};

const IOS_PROCESSING_MESSAGE =
  '当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。';

const ENTITY_CONFIG: Record<AdminContentSubmitEntityType, AdminContentSubmitEntityConfig> = {
  label: {
    label: '厂牌',
    catalogHref: '/admin/content/labels',
    catalogLabel: '返回厂牌目录',
    editHref: (entityId) => (entityId ? `/admin/content/labels/${entityId}/edit` : '/admin/content/labels'),
    createdMessage: '厂牌资料已经成功入库，你可以继续完善内容，也可以返回目录继续处理其它对象。',
    updatedMessage: '厂牌更新已经保存成功。你可以继续检查资料，也可以返回目录继续管理。',
    historyEntityType: 'label',
    historySecondaryLabel: '稍后处理，先回到厂牌目录',
    historyCreateDescription:
      '这条厂牌资料已经直接保存成功。你可以现在去统一内容历史页预览推送内容并一键发送，也可以稍后再处理。',
    historyEditDescription:
      '这次厂牌资料更新已经保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以先返回目录稍后处理。',
    publishTaskType: 'brand_release',
  },
  dj: {
    label: 'DJ',
    catalogHref: '/admin/content/djs/catalog',
    catalogLabel: '返回 DJ 目录',
    editHref: (entityId) => (entityId ? `/admin/content/djs/${entityId}/edit` : '/admin/content/djs/catalog'),
    createdMessage: 'DJ 资料已经成功入库，你可以继续补充资料，也可以返回目录继续管理。',
    updatedMessage: 'DJ 更新已经保存成功。你可以继续核对资料，也可以返回目录稍后处理。',
    historyEntityType: 'dj',
    historySecondaryLabel: '稍后处理，先回到 DJ 目录',
    historyCreateDescription:
      '这条 DJ 资料已经直接保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以先回目录稍后处理。',
    historyEditDescription:
      '这次 DJ 资料更新已经保存成功。你可以现在去统一内容历史页继续决定是否推送给用户，也可以稍后再处理。',
    publishTaskType: 'dj_release',
  },
  festival: {
    label: '主办方',
    catalogHref: '/admin/content/organizers/catalog',
    catalogLabel: '返回主办方目录',
    editHref: (entityId) =>
      entityId ? `/admin/content/organizers/${entityId}/edit` : '/admin/content/organizers/catalog',
    createdMessage: '主办方资料已经成功入库，你可以继续完善绑定与资料，也可以返回目录继续管理。',
    updatedMessage: '主办方更新已经保存成功。你可以继续检查变更，也可以返回目录稍后处理。',
    historyEntityType: 'festival',
    historySecondaryLabel: '稍后处理，先回到主办方目录',
    historyCreateDescription:
      '这条主办方资料已经直接保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以先回目录稍后处理。',
    historyEditDescription:
      '这次主办方资料更新已经直接保存成功。你可以现在去统一内容历史页继续决定是否推送，也可以稍后再处理。',
  },
  news_article: {
    label: '资讯',
    catalogHref: '/admin/content/news',
    catalogLabel: '返回资讯目录',
    editHref: (entityId) => (entityId ? `/admin/content/news/${entityId}/edit` : '/admin/content/news'),
    createdMessage: '资讯已经成功入库，你可以继续补正文和绑定关系，也可以返回目录继续管理。',
    updatedMessage: '资讯更新已经保存成功。你可以继续检查正文与资源，也可以返回目录稍后处理。',
    historyEntityType: 'news_article',
    historySecondaryLabel: '稍后处理，先回到资讯目录',
    historyCreateDescription:
      '这条资讯已经保存成功。你可以现在去统一内容历史页预览推送内容并继续处理，也可以先回目录稍后再决定。',
    historyEditDescription:
      '这次资讯更新已经保存成功。你可以现在去统一内容历史页预览推送内容并继续处理，也可以先回目录稍后再决定。',
    publishTaskType: 'news_release',
  },
};

export const isAdminContentSubmitEntityType = (
  value: string | null
): value is AdminContentSubmitEntityType =>
  value === 'label' || value === 'dj' || value === 'festival' || value === 'news_article';

export const buildAdminContentSubmitResultHref = (
  state: AdminContentSubmitResultState
): string => {
  const params = new URLSearchParams({
    entityType: state.entityType,
    flow: state.flow,
    outcome: state.outcome,
  });

  if (state.entityId?.trim()) params.set('entityId', state.entityId.trim());
  if (state.entityName?.trim()) params.set('entityName', state.entityName.trim());
  if (state.submissionId?.trim()) params.set('submissionId', state.submissionId.trim());
  if (state.message?.trim()) params.set('message', state.message.trim());

  return `/admin/content/result?${params.toString()}`;
};

export const resolveAdminContentSubmitResultContent = (
  state: AdminContentSubmitResultState
): AdminContentSubmitResultContent => {
  const config = ENTITY_CONFIG[state.entityType];
  const entityId = state.entityId?.trim() || null;
  const editHref = config.editHref(entityId);
  const messageOverride = state.message?.trim() || null;

  const historyPrompt = entityId
    ? {
        entityType: config.historyEntityType,
        entityId,
        secondaryHref: config.catalogHref,
        secondaryLabel: config.historySecondaryLabel,
        description:
          state.flow === 'create' ? config.historyCreateDescription : config.historyEditDescription,
      }
    : null;

  const publishTask =
    entityId && config.publishTaskType
      ? {
          taskType: config.publishTaskType,
          entityType: config.historyEntityType,
          entityId,
          mode: state.flow,
        }
      : null;

  const supplementaryAction =
    state.entityType === 'dj' && entityId
      ? {
          href: `/admin/content/reviews/dj-bindings?djId=${encodeURIComponent(entityId)}`,
          label: state.flow === 'create' ? '去处理活动绑定' : '查看新的绑定候选',
          description:
            state.flow === 'create'
              ? '系统只会生成同名或近似名候选，不会自动绑定；请在绑定审核台手动勾选后再一键导入。'
              : '如这次资料变更产生了新的候选，也仍然需要你手动勾选确认后再导入。',
        }
      : null;

  if (state.outcome === 'created' && state.flow === 'create') {
    return {
      entityType: state.entityType,
      entityLabel: config.label,
      title: `${config.label}已创建`,
      message: messageOverride || config.createdMessage,
      catalogHref: config.catalogHref,
      catalogLabel: config.catalogLabel,
      primaryHref: editHref,
      primaryLabel: entityId ? `继续编辑${config.label}` : config.catalogLabel,
      secondaryHref: config.catalogHref,
      secondaryLabel: config.catalogLabel,
      historyPrompt,
      publishTask,
      supplementaryAction,
    };
  }

  if (state.outcome === 'created' && state.flow === 'edit') {
    return {
      entityType: state.entityType,
      entityLabel: config.label,
      title: `${config.label}已更新`,
      message: messageOverride || config.updatedMessage,
      catalogHref: config.catalogHref,
      catalogLabel: config.catalogLabel,
      primaryHref: editHref,
      primaryLabel: entityId ? `继续编辑${config.label}` : config.catalogLabel,
      secondaryHref: config.catalogHref,
      secondaryLabel: config.catalogLabel,
      historyPrompt,
      publishTask,
      supplementaryAction,
    };
  }

  if (state.outcome === 'submitted' && state.flow === 'create') {
    return {
      entityType: state.entityType,
      entityLabel: config.label,
      title: '任务已提交',
      message: messageOverride || IOS_PROCESSING_MESSAGE,
      catalogHref: config.catalogHref,
      catalogLabel: config.catalogLabel,
      primaryHref: '/admin/content/reviews/submissions',
      primaryLabel: '查看提交任务',
      secondaryHref: config.catalogHref,
      secondaryLabel: config.catalogLabel,
      historyPrompt: null,
      publishTask: null,
      supplementaryAction: null,
    };
  }

  return {
    entityType: state.entityType,
    entityLabel: config.label,
    title: '编辑任务已提交',
    message: messageOverride || IOS_PROCESSING_MESSAGE,
    catalogHref: config.catalogHref,
    catalogLabel: config.catalogLabel,
    primaryHref: '/admin/content/reviews/submissions',
    primaryLabel: '查看提交任务',
    secondaryHref: editHref,
    secondaryLabel: entityId ? `返回${config.label}编辑页` : config.catalogLabel,
    historyPrompt: null,
    publishTask: null,
    supplementaryAction: null,
  };
};
