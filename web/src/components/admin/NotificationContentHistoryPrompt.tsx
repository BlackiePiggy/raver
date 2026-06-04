'use client';

import Link from 'next/link';

type NotificationContentHistoryPromptProps = {
  entityType: string;
  entityId: string;
  title?: string;
  description?: string;
  secondaryHref: string;
  secondaryLabel: string;
};

export default function NotificationContentHistoryPrompt({
  entityType,
  entityId,
  title = '下一步处理推送',
  description = '这条内容已经保存成功。你可以现在去统一内容历史页预览即将推送的内容并一键发送，也可以稍后再处理。',
  secondaryHref,
  secondaryLabel,
}: NotificationContentHistoryPromptProps) {
  const historyHref = `/admin/notification-center/content-history?entityType=${encodeURIComponent(entityType)}&query=${encodeURIComponent(entityId)}`;

  return (
    <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
      <div className="admin-studio-label">Next Step</div>
      <h3 className="mt-2 text-xl font-semibold text-[#071110]">{title}</h3>
      <p className="mt-3 max-w-3xl text-sm leading-6 text-[#5b6763]">{description}</p>
      <div className="mt-5 flex flex-wrap gap-3">
        <Link
          href={historyHref}
          className="inline-flex min-h-12 items-center justify-center rounded-full bg-[#071110] px-6 py-3 text-sm font-semibold text-white"
        >
          去统一内容历史处理推送
        </Link>
        <Link
          href={secondaryHref}
          className="inline-flex min-h-12 items-center justify-center rounded-full border border-[#d7ddda] bg-white px-6 py-3 text-sm font-semibold text-[#071110]"
        >
          {secondaryLabel}
        </Link>
      </div>
    </section>
  );
}
