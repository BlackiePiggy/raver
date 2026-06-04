'use client';

import { useCallback, useEffect, useState } from 'react';
import NotificationCenterWorkspaceLayout from '@/components/admin/NotificationCenterWorkspaceLayout';
import {
  CATEGORY_OPTIONS,
  CHANNEL_OPTIONS,
  DEFAULT_TEMPLATE_FORM,
  formatTime,
  toVariablesArray,
  trimValue,
} from '@/components/admin/notification-center/shared';
import {
  notificationCenterAdminApi,
  type NotificationCenterTemplateItem,
} from '@/lib/api/notification-center-admin';

export default function NotificationCenterTemplatesPage() {
  const [templates, setTemplates] = useState<NotificationCenterTemplateItem[]>([]);
  const [templateForm, setTemplateForm] = useState(DEFAULT_TEMPLATE_FORM);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadTemplates = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const items = await notificationCenterAdminApi.getTemplates({ limit: 200 });
      setTemplates(items);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载通知模板失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadTemplates();
  }, [loadTemplates]);

  const loadTemplateToForm = (template: NotificationCenterTemplateItem) => {
    setTemplateForm({
      category: template.category,
      locale: template.locale,
      channel: template.channel,
      titleTemplate: template.titleTemplate,
      bodyTemplate: template.bodyTemplate,
      deeplinkTemplate: template.deeplinkTemplate || '',
      variablesText: toVariablesArray(template.variables).join(','),
      isActive: template.isActive,
    });
  };

  const handleSaveTemplate = async () => {
    try {
      setSaving(true);
      setError(null);
      const variables = Array.from(
        new Set(
          templateForm.variablesText
            .split(',')
            .map((item) => item.trim())
            .filter(Boolean)
        )
      );
      await notificationCenterAdminApi.upsertTemplate({
        category: templateForm.category,
        locale: trimValue(templateForm.locale) || 'zh-CN',
        channel: templateForm.channel,
        titleTemplate: trimValue(templateForm.titleTemplate),
        bodyTemplate: trimValue(templateForm.bodyTemplate),
        deeplinkTemplate: trimValue(templateForm.deeplinkTemplate) || null,
        variables,
        isActive: templateForm.isActive,
      });
      setTemplateForm(DEFAULT_TEMPLATE_FORM);
      await loadTemplates();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存通知模板失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <NotificationCenterWorkspaceLayout
      title="通知模板"
      description="统一维护通知模板文案，按分类、语言、渠道组织，避免业务方各自拼消息。"
      actions={
        <button
          type="button"
          onClick={() => void handleSaveTemplate()}
          disabled={saving}
          className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:opacity-45"
        >
          {saving ? '保存中...' : '保存模板'}
        </button>
      }
    >
      {error ? (
        <section className="rounded-[24px] border border-[#f0d7d5] bg-[#fff7f6] px-4 py-3 text-sm text-[#8b3a3a]">
          {error}
        </section>
      ) : null}

      <section className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="admin-studio-label">Template Editor</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">编辑模板</h2>

          <div className="mt-5 grid gap-4 md:grid-cols-3">
            <label className="text-sm text-[#5b6763]">
              分类
              <select
                value={templateForm.category}
                onChange={(event) =>
                  setTemplateForm((prev) => ({ ...prev, category: event.target.value as typeof prev.category }))
                }
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              >
                {CATEGORY_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="text-sm text-[#5b6763]">
              语言
              <input
                value={templateForm.locale}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, locale: event.target.value }))}
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              />
            </label>

            <label className="text-sm text-[#5b6763]">
              渠道
              <select
                value={templateForm.channel}
                onChange={(event) =>
                  setTemplateForm((prev) => ({ ...prev, channel: event.target.value as typeof prev.channel }))
                }
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              >
                {CHANNEL_OPTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="text-sm text-[#5b6763] md:col-span-3">
              标题模板
              <input
                value={templateForm.titleTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, titleTemplate: event.target.value }))}
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              />
            </label>

            <label className="text-sm text-[#5b6763] md:col-span-3">
              内容模板
              <textarea
                value={templateForm.bodyTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, bodyTemplate: event.target.value }))}
                className="mt-2 h-28 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              />
            </label>

            <label className="text-sm text-[#5b6763] md:col-span-3">
              Deeplink 模板
              <input
                value={templateForm.deeplinkTemplate}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, deeplinkTemplate: event.target.value }))}
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              />
            </label>

            <label className="text-sm text-[#5b6763] md:col-span-2">
              变量列表（逗号分隔）
              <input
                value={templateForm.variablesText}
                onChange={(event) => setTemplateForm((prev) => ({ ...prev, variablesText: event.target.value }))}
                className="mt-2 w-full rounded-[18px] border border-[#d9e1de] bg-[#fbfcfb] px-4 py-3 text-sm text-[#071110]"
              />
            </label>

            <label className="text-sm text-[#5b6763]">
              启用
              <div className="mt-4">
                <input
                  type="checkbox"
                  checked={templateForm.isActive}
                  onChange={(event) => setTemplateForm((prev) => ({ ...prev, isActive: event.target.checked }))}
                />
              </div>
            </label>
          </div>
        </section>

        <section className="rounded-[28px] border border-[#e7ece8] bg-white p-5">
          <div className="admin-studio-label">Template List</div>
          <h2 className="mt-2 text-xl font-semibold text-[#071110]">已有模板</h2>

          <div className="mt-5 overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b border-[#edf1ef] text-[#5b6763]">
                  <th className="px-3 py-3">分类</th>
                  <th className="px-3 py-3">语言</th>
                  <th className="px-3 py-3">渠道</th>
                  <th className="px-3 py-3">标题</th>
                  <th className="px-3 py-3">启用</th>
                  <th className="px-3 py-3">更新时间</th>
                  <th className="px-3 py-3">操作</th>
                </tr>
              </thead>
              <tbody>
                {templates.map((item) => (
                  <tr key={item.id} className="border-b border-[#f1f4f2]">
                    <td className="px-3 py-4">{item.category}</td>
                    <td className="px-3 py-4">{item.locale}</td>
                    <td className="px-3 py-4">{item.channel}</td>
                    <td className="px-3 py-4">{item.titleTemplate}</td>
                    <td className="px-3 py-4">{item.isActive ? 'true' : 'false'}</td>
                    <td className="px-3 py-4">{formatTime(item.updatedAt)}</td>
                    <td className="px-3 py-4">
                      <button
                        type="button"
                        onClick={() => loadTemplateToForm(item)}
                        className="rounded-full border border-[#d9e1de] px-4 py-2 text-xs font-semibold text-[#071110]"
                      >
                        编辑
                      </button>
                    </td>
                  </tr>
                ))}
                {!loading && !templates.length ? (
                  <tr>
                    <td colSpan={7} className="px-3 py-10 text-center text-sm text-[#5b6763]">
                      当前还没有通知模板。
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </NotificationCenterWorkspaceLayout>
  );
}
