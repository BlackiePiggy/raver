export type EventStudioSubmitFlow = 'create' | 'edit';
export type EventStudioSubmitOutcome = 'created' | 'submitted';

export type EventStudioSubmitResultState = {
  flow: EventStudioSubmitFlow;
  outcome: EventStudioSubmitOutcome;
  eventId?: string | null;
  eventName?: string | null;
  submissionId?: string | null;
  message?: string | null;
};

export type EventStudioSubmitResultContent = {
  title: string;
  message: string;
  primaryHref: string;
  primaryLabel: string;
  secondaryHref: string;
  secondaryLabel: string;
};

const IOS_PROCESSING_MESSAGE =
  '当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。';

export const buildEventStudioSubmitResultHref = (state: EventStudioSubmitResultState): string => {
  const params = new URLSearchParams({
    flow: state.flow,
    outcome: state.outcome,
  });

  if (state.eventId?.trim()) params.set('eventId', state.eventId.trim());
  if (state.eventName?.trim()) params.set('eventName', state.eventName.trim());
  if (state.submissionId?.trim()) params.set('submissionId', state.submissionId.trim());
  if (state.message?.trim()) params.set('message', state.message.trim());

  return `/admin/content/events/result?${params.toString()}`;
};

export const resolveEventStudioSubmitResultContent = (
  state: EventStudioSubmitResultState
): EventStudioSubmitResultContent => {
  const eventId = state.eventId?.trim() || null;
  const fallbackPrimaryHref = '/admin/content/events/catalog';
  const eventEditHref = eventId ? `/admin/content/events/${eventId}/edit` : fallbackPrimaryHref;

  if (state.outcome === 'created' && state.flow === 'create') {
    return {
      title: '活动已发布',
      message: '活动已经出现在活动页，也可以在我的发布里继续管理。',
      primaryHref: eventEditHref,
      primaryLabel: eventId ? '继续查看活动' : '返回活动工作区',
      secondaryHref: '/admin/content/events/catalog',
      secondaryLabel: '返回活动工作区',
    };
  }

  if (state.outcome === 'created' && state.flow === 'edit') {
    return {
      title: '活动已更新',
      message: '更新已保存。你可以返回活动页查看最新内容，也可以在我的发布里继续管理。',
      primaryHref: eventEditHref,
      primaryLabel: eventId ? '继续查看活动' : '返回活动工作区',
      secondaryHref: '/admin/content/events/catalog',
      secondaryLabel: '返回活动工作区',
    };
  }

  if (state.outcome === 'submitted' && state.flow === 'create') {
    return {
      title: '任务已提交',
      message: IOS_PROCESSING_MESSAGE,
      primaryHref: '/admin/content/reviews/submissions',
      primaryLabel: '查看提交任务',
      secondaryHref: '/admin/content/events/catalog',
      secondaryLabel: '返回活动工作区',
    };
  }

  return {
    title: '编辑任务已提交',
    message: IOS_PROCESSING_MESSAGE,
    primaryHref: '/admin/content/reviews/submissions',
    primaryLabel: '查看提交任务',
    secondaryHref: eventEditHref,
    secondaryLabel: eventId ? '返回活动编辑页' : '返回活动工作区',
  };
};
