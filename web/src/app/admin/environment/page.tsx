'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import {
  adminEnvironmentApi,
  type EnvironmentConfigResponse,
  type EnvironmentConfigSectionTestResult,
} from '@/lib/api/admin-environment';

export default function AdminEnvironmentPage() {
  const { user, isLoading } = useAuth();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const [data, setData] = useState<EnvironmentConfigResponse | null>(null);
  const [draftValues, setDraftValues] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [testingSectionId, setTestingSectionId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [testResults, setTestResults] = useState<Record<string, EnvironmentConfigSectionTestResult>>({});

  const load = useCallback(async () => {
    if (user?.role !== 'admin') return;
    try {
      setLoading(true);
      setError(null);
      const result = await adminEnvironmentApi.fetchConfig();
      setData(result);
      setDraftValues(
        Object.fromEntries(
          result.sections.flatMap((section) =>
            section.fields.map((field) => [field.key, field.secret ? '' : field.value])
          )
        )
      );
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载环境配置失败');
    } finally {
      setLoading(false);
    }
  }, [user?.role]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    if (!data) return;
    try {
      setSaving(true);
      setError(null);
      setNotice(null);
      const values = Object.fromEntries(
        data.sections.flatMap((section) =>
          section.fields.map((field) => {
            const nextValue = draftValues[field.key] ?? '';
            return [field.key, field.secret && !nextValue.trim() ? field.value : nextValue];
          })
        )
      );
      const result = await adminEnvironmentApi.saveConfig({ values });
      setData(result);
      setDraftValues(
        Object.fromEntries(
          result.sections.flatMap((section) =>
            section.fields.map((field) => [field.key, field.secret ? '' : field.value])
          )
        )
      );
      setNotice('环境配置已保存。新的 Coze 请求会读取你刚保存的值。');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存环境配置失败');
    } finally {
      setSaving(false);
    }
  };

  const testSection = async (sectionId: string) => {
    if (!data) return;
    try {
      setTestingSectionId(sectionId);
      setError(null);
      setNotice(null);
      const section = data.sections.find((item) => item.id === sectionId);
      if (!section) return;
      const values = Object.fromEntries(
        section.fields.map((field) => {
          const nextValue = draftValues[field.key] ?? '';
          return [field.key, field.secret && !nextValue.trim() ? field.value : nextValue];
        })
      );
      const result = await adminEnvironmentApi.testSection({
        sectionId,
        values,
      });
      setTestResults((current) => ({ ...current, [sectionId]: result }));
      setNotice(result.ok ? `${section.title} 测试通过。` : `${section.title} 测试已完成，请查看结果。`);
    } catch (testError) {
      setError(testError instanceof Error ? testError.message : '测试连接失败');
    } finally {
      setTestingSectionId(null);
    }
  };

  if (isLoading) {
    return (
      <AdminAppShell title="环境管理配置" description="加载中...">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (user?.role !== 'admin') {
    return (
      <AdminAppShell title="环境管理配置" description="仅管理员可访问环境配置。">
        <div className="admin-shell-panel p-8 text-sm text-black/55">当前账号无权限访问该页面。</div>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="环境管理配置"
      eyebrow="Raver Admin / Environment"
      description="集中查看和替换 Coze 相关环境配置，区分服务端工作流、Web 辅助工具与公共链接。"
      actions={(
        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading || saving}
            className="rounded-full border border-[#e8eceb] bg-white px-5 py-3 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? '刷新中...' : '刷新配置'}
          </button>
          <button
            type="button"
            onClick={() => void save()}
            disabled={saving || loading || !data}
            className="rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          >
            {saving ? '保存中...' : '保存环境'}
          </button>
        </div>
      )}
    >
      <section className="space-y-5">
        {error ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#f7e3e0_0%,#ffffff_100%)] px-4 py-3 text-sm text-[#6a3530]">
            {error}
          </div>
        ) : null}
        {notice ? (
          <div className="admin-reference-pastel-card bg-[linear-gradient(180deg,#edf7f2_0%,#ffffff_100%)] px-4 py-3 text-sm text-[#2f4027]">
            {notice}
          </div>
        ) : null}

        <div className="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
          <div className="admin-reference-card p-5">
            <div className="text-sm font-semibold text-[#071110]">生效方式</div>
            <div className="mt-3 space-y-2 text-sm leading-6 text-black/55">
              {data?.summary.immediateEffect.map((item) => (
                <p key={item}>{item}</p>
              ))}
            </div>
          </div>
          <div className="admin-reference-card p-5">
            <div className="text-sm font-semibold text-[#071110]">重启说明</div>
            <div className="mt-3 space-y-2 text-sm leading-6 text-black/55">
              {data?.summary.restartRecommended.map((item) => (
                <p key={item}>{item}</p>
              ))}
            </div>
          </div>
        </div>

        {data?.sections.map((section) => (
          <section key={section.id} className="admin-reference-card p-5">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-[22px] font-semibold tracking-[-0.04em] text-[#071110]">{section.title}</div>
                <div className="mt-2 max-w-3xl text-sm leading-6 text-black/48">{section.description}</div>
              </div>
              <button
                type="button"
                onClick={() => void testSection(section.id)}
                disabled={testingSectionId !== null}
                className="rounded-full border border-[#e8eceb] bg-white px-4 py-2 text-sm font-semibold text-[#071110] disabled:cursor-not-allowed disabled:opacity-60"
              >
                {testingSectionId === section.id ? '测试中...' : '测试连接'}
              </button>
            </div>

            {testResults[section.id] ? (
              <div className={`mt-4 rounded-[20px] border px-4 py-4 ${testResults[section.id].ok ? 'border-[#d8eadf] bg-[#f4fbf6]' : 'border-[#f2dbd6] bg-[#fff7f5]'}`}>
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="text-sm font-semibold text-[#071110]">
                    {testResults[section.id].message}
                  </div>
                  <div className="text-xs text-black/42">{testResults[section.id].checkedAt}</div>
                </div>
                <div className="mt-3 grid gap-3 md:grid-cols-2">
                  {testResults[section.id].checks.map((check) => (
                    <div key={check.label} className="rounded-[16px] border border-black/6 bg-white px-3 py-3">
                      <div className="flex items-center justify-between gap-3">
                        <div className="text-sm font-semibold text-[#071110]">{check.label}</div>
                        <span className={`rounded-full px-2 py-1 text-[11px] font-semibold ${check.ok ? 'bg-[#e8f7ee] text-[#1d6b3f]' : 'bg-[#fdeceb] text-[#b42318]'}`}>
                          {check.ok ? '正常' : '异常'}
                        </span>
                      </div>
                      <div className="mt-2 break-all text-xs leading-5 text-black/48">{check.detail}</div>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            <div className="mt-5 grid gap-4 lg:grid-cols-2">
              {section.fields.map((field) => (
                <label key={field.key} className="admin-reference-soft-card p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-[#071110]">{field.label}</div>
                    <div className="text-[11px] font-semibold uppercase tracking-[0.12em] text-black/38">
                      {field.envFile}
                    </div>
                  </div>
                  <div className="mt-1 text-xs leading-5 text-black/42">
                    {field.immediateEffect ? '保存后新请求立即生效' : '保存后建议重启'}
                  </div>
                  <div className="mt-3">
                    {field.multiline ? (
                      <textarea
                        value={draftValues[field.key] ?? ''}
                        onChange={(event) => setDraftValues((current) => ({ ...current, [field.key]: event.target.value }))}
                        placeholder={field.placeholder || field.key}
                        className="admin-studio-textarea min-h-[120px]"
                        spellCheck={false}
                      />
                    ) : (
                      <input
                        value={draftValues[field.key] ?? ''}
                        onChange={(event) => setDraftValues((current) => ({ ...current, [field.key]: event.target.value }))}
                        placeholder={field.secret ? '留空表示保持当前值不变' : field.placeholder || field.key}
                        className="admin-studio-input"
                        spellCheck={false}
                        autoCapitalize="off"
                        autoCorrect="off"
                      />
                    )}
                  </div>
                  <div className="mt-3 break-all text-[12px] leading-5 text-black/38">
                    当前值：{field.displayValue || '未配置'}
                  </div>
                </label>
              ))}
            </div>
          </section>
        ))}
      </section>
    </AdminAppShell>
  );
}
