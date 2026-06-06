'use client';
 
import { useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import {
  adminEnvironmentApi,
  type EnvironmentConfigResponse,
  type EnvironmentConfigSection,
  type EnvironmentConfigSectionTestResult,
} from '@/lib/api/admin-environment';
 
// ─── Icons ────────────────────────────────────────────────────────────────────
 
function IconRefresh({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
      <path d="M23 4v6h-6M1 20v-6h6" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
 
function IconSave({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
      <path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" strokeLinecap="round" strokeLinejoin="round" />
      <polyline points="17 21 17 13 7 13 7 21" />
      <polyline points="7 3 7 8 15 8" />
    </svg>
  );
}
 
function IconEdit({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
      <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
 
function IconEye({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx={12} cy={12} r={3} />
    </svg>
  );
}
 
function IconEyeOff({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
      <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" strokeLinecap="round" strokeLinejoin="round" />
      <line x1={1} y1={1} x2={23} y2={23} strokeLinecap="round" />
    </svg>
  );
}
 
function IconChevronDown({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
      <path d="M6 9l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
 
function IconChevronUp({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
      <path d="M18 15l-6-6-6 6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
 
function IconCheck({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.5}>
      <polyline points="20 6 9 17 4 12" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
 
// ─── Helper: derive sub-modules from fields ───────────────────────────────────
// Fields in a section may share a common prefix (e.g. "TIMETABLE_RUN_URL",
// "TIMETABLE_TOKEN"). We group them by the first segment before "_" to form
// visual sub-module rows.  If a section has no clear grouping, we treat the
// whole section as one sub-module.
 
type SubModule = {
  id: string;
  label: string;
  fieldKeys: string[];
};

const COMMON_FIELD_LABEL_SUFFIX = /\s+(Run URL|Token|Timeout \(ms\)|Base URL)$/i;

const deriveGroupLabel = (field: EnvironmentConfigSection['fields'][number]): string => {
  const fromApi = (field as { groupLabel?: string }).groupLabel?.trim();
  if (fromApi) return fromApi;
  const compactLabel = field.label.replace(COMMON_FIELD_LABEL_SUFFIX, '').trim();
  return compactLabel || field.label;
};

function deriveSubModules(section: EnvironmentConfigSection): SubModule[] {
  const groups = new Map<string, SubModule>();
  for (const field of section.fields) {
    const groupLabel = deriveGroupLabel(field);
    const groupId = (field as { groupId?: string }).groupId
      ?.trim()
      .toUpperCase()
      || groupLabel.toUpperCase().replace(/[^A-Z0-9]+/g, '_');
    const existing = groups.get(groupId);
    if (existing) {
      existing.fieldKeys.push(field.key);
      continue;
    }
    groups.set(groupId, {
      id: groupId,
      label: groupLabel,
      fieldKeys: [field.key],
    });
  }

  return Array.from(groups.values());
}

// ─── Inline edit modal / inline row ──────────────────────────────────────────

const getSavedFieldValue = (
  field: EnvironmentConfigSection['fields'][number]
): string => String(field.value || '').trim();

const getDraftFieldValue = (
  field: EnvironmentConfigSection['fields'][number],
  draftValues: Record<string, string>
): string | undefined =>
  Object.prototype.hasOwnProperty.call(draftValues, field.key)
    ? String(draftValues[field.key] ?? '')
    : undefined;

const getEffectiveFieldValue = (
  field: EnvironmentConfigSection['fields'][number],
  draftValues: Record<string, string>
): string => {
  const draftValue = getDraftFieldValue(field, draftValues);
  if (field.secret) {
    return draftValue && draftValue.trim() ? draftValue : getSavedFieldValue(field);
  }
  return draftValue ?? getSavedFieldValue(field);
};

const isFieldDirty = (
  field: EnvironmentConfigSection['fields'][number],
  draftValues: Record<string, string>
): boolean => {
  const draftValue = getDraftFieldValue(field, draftValues);
  if (draftValue === undefined) return false;
  if (field.secret) return Boolean(draftValue.trim());
  return draftValue !== getSavedFieldValue(field);
};

const formatFieldTableValue = (
  field: EnvironmentConfigSection['fields'][number],
  draftValues: Record<string, string>,
  revealed: boolean
): string => {
  const savedValue = getSavedFieldValue(field);
  const draftValue = getDraftFieldValue(field, draftValues) ?? '';

  if (field.secret) {
    if (draftValue.trim()) {
      return revealed ? draftValue : `${'*'.repeat(Math.min(Math.max(draftValue.length, 8), 16))}（待保存）`;
    }
    return field.displayValue || (savedValue ? '已配置' : '—');
  }

  const effectiveValue = getEffectiveFieldValue(field, draftValues);
  return effectiveValue || '—';
};

function EditFieldModal({
  fieldLabel,
  fieldKey,
  isSecret,
  isMultiline,
  placeholder,
  currentDisplayValue,
  initialValue,
  onConfirm,
  onClose,
}: {
  fieldLabel: string;
  fieldKey: string;
  isSecret: boolean;
  isMultiline: boolean;
  placeholder: string;
  currentDisplayValue: string;
  initialValue: string;
  onConfirm: (v: string) => void;
  onClose: () => void;
}) {
  const [localValue, setLocalValue] = useState(initialValue);

  useEffect(() => {
    setLocalValue(initialValue);
  }, [initialValue, fieldKey]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="w-full max-w-lg rounded-xl border border-gray-200 bg-white p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <div>
            <div className="text-base font-semibold text-gray-900">{fieldLabel}</div>
            <div className="mt-0.5 font-mono text-[11px] text-gray-400">{fieldKey}</div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 bg-white text-gray-400 hover:bg-gray-50"
          >
            <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path d="M18 6L6 18M6 6l12 12" strokeLinecap="round" />
            </svg>
          </button>
        </div>
 
        {isMultiline ? (
          <textarea
            value={localValue}
            onChange={(e) => setLocalValue(e.target.value)}
            placeholder={isSecret ? '留空表示保持当前值不变' : placeholder}
            rows={6}
            className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 font-mono text-sm text-gray-800 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10 resize-none"
            spellCheck={false}
            autoCapitalize="off"
            autoCorrect="off"
          />
        ) : (
          <input
            type={isSecret ? 'password' : 'text'}
            value={localValue}
            onChange={(e) => setLocalValue(e.target.value)}
            placeholder={isSecret ? '留空表示保持当前值不变' : placeholder}
            className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 font-mono text-sm text-gray-800 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900/10"
            spellCheck={false}
            autoCapitalize="off"
            autoCorrect="off"
          />
        )}
 
        <div className="mt-2 break-all font-mono text-[11px] text-gray-400">
          当前值：{currentDisplayValue || '未配置'}
        </div>
 
        <div className="mt-4 flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
          >
            取消
          </button>
          <button
            type="button"
            onClick={() => {
              onConfirm(localValue);
              onClose();
            }}
            className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-800"
          >
            确认
          </button>
        </div>
      </div>
    </div>
  );
}
 
// ─── Section table ─────────────────────────────────────────────────────────────
 
function SectionTable({
  section,
  draftValues,
  onDraftChange,
  testResult,
  onTest,
  testingSectionId,
}: {
  section: EnvironmentConfigSection;
  draftValues: Record<string, string>;
  onDraftChange: (key: string, value: string) => void;
  testResult?: EnvironmentConfigSectionTestResult;
  onTest: (sectionId: string) => void;
  testingSectionId: string | null;
}) {
  const [collapsed, setCollapsed] = useState(false);
  const [revealedKeys, setRevealedKeys] = useState<Set<string>>(new Set());
  const [editingKey, setEditingKey] = useState<string | null>(null);
 
  const subModules = useMemo(() => deriveSubModules(section), [section]);
 
  const toggleReveal = (key: string) => {
    setRevealedKeys((prev) => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });
  };
 
  const editingField = editingKey
    ? section.fields.find((f) => f.key === editingKey) ?? null
    : null;
 
  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      {/* Section header */}
      <div className="flex items-start justify-between gap-4 px-6 py-5">
        <div className="min-w-0">
          <h2 className="text-xl font-bold text-gray-900">{section.title}</h2>
          <p className="mt-1 text-sm leading-relaxed text-gray-500">{section.description}</p>
        </div>
        <div className="flex flex-shrink-0 items-center gap-2">
          <button
            type="button"
            onClick={() => onTest(section.id)}
            disabled={testingSectionId !== null}
            className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50 disabled:opacity-40"
          >
            {testingSectionId === section.id ? '测试中…' : '测试连接'}
          </button>
          <button
            type="button"
            onClick={() => setCollapsed((v) => !v)}
            className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
          >
            {collapsed ? '展开全部' : '收起全部'}
            {collapsed ? <IconChevronDown className="h-3.5 w-3.5" /> : <IconChevronUp className="h-3.5 w-3.5" />}
          </button>
        </div>
      </div>
 
      {/* Test result */}
      {testResult && (
        <div className={`mx-6 mb-4 rounded-lg border px-4 py-3 ${testResult.ok ? 'border-emerald-200 bg-emerald-50' : 'border-red-200 bg-red-50'}`}>
          <div className="flex items-center justify-between gap-3">
            <span className={`text-sm font-semibold ${testResult.ok ? 'text-emerald-800' : 'text-red-800'}`}>
              {testResult.message}
            </span>
            <span className="text-xs text-gray-400">{testResult.checkedAt}</span>
          </div>
          {testResult.checks.length > 0 && (
            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              {testResult.checks.map((check) => (
                <div key={check.label} className="rounded-lg border border-gray-100 bg-white px-3 py-2.5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-gray-800">{check.label}</span>
                    <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${check.ok ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'}`}>
                      {check.ok ? '正常' : '异常'}
                    </span>
                  </div>
                  <div className="mt-1 break-all text-[11px] leading-relaxed text-gray-400">{check.detail}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
 
      {!collapsed && (
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            {/* Table header */}
            <thead>
              <tr className="border-y border-gray-100 bg-gray-50/80">
                <th className="w-[220px] px-6 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                  模块 / 功能
                </th>
                <th className="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                  配置项
                </th>
                <th className="px-4 py-2.5 text-left text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                  当前值
                </th>
                <th className="w-16 px-4 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wide text-gray-400">
                  操作
                </th>
              </tr>
            </thead>
 
            <tbody>
              {subModules.map((subModule, subModuleIdx) => {
                const subFields = section.fields.filter((f) => subModule.fieldKeys.includes(f.key));
                const isLastSubModule = subModuleIdx === subModules.length - 1;
                const subModuleConnected = subFields.some((field) =>
                  Boolean(getEffectiveFieldValue(field, draftValues).trim())
                );

                return subFields.map((field, fieldIdx) => {
                  const isFirstField = fieldIdx === 0;
                  const isLastField = fieldIdx === subFields.length - 1;
                  const revealed = revealedKeys.has(field.key);
                  const displayValue = formatFieldTableValue(field, draftValues, revealed);
                  const dirty = isFieldDirty(field, draftValues);
                  const hasVisibleValue = displayValue !== '—';

                  return (
                    <tr
                      key={field.key}
                      className={`align-middle transition-colors hover:bg-gray-50/60 ${
                        isLastField && !isLastSubModule ? 'border-b border-gray-100' : 'border-b border-gray-50'
                      }`}
                    >
                      {/* Sub-module cell – only rendered on first field of each group */}
                      {isFirstField ? (
                        <td
                          rowSpan={subFields.length}
                          className="border-r border-gray-100 px-6 py-4 align-top"
                        >
                          <div className="flex items-center gap-2">
                            {/* Generic icon placeholder – could be customized per sub-module type */}
                            <div className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-lg bg-gray-100 text-gray-500">
                              <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}>
                                <circle cx={12} cy={12} r={9} />
                                <path d="M12 8v4m0 4h.01" strokeLinecap="round" />
                              </svg>
                            </div>
                            <span className="text-sm font-semibold text-gray-800">
                              {subModule.label}
                            </span>
                          </div>
                          {/* Connection status badge */}
                          <div className="mt-2 pl-9">
                            {subModuleConnected ? (
                              <span className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-600">
                                <IconCheck className="h-3 w-3" />
                                已连接
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 text-xs font-semibold text-amber-600">
                                <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                                  <circle cx={12} cy={12} r={9} />
                                  <path d="M12 8v4m0 4h.01" strokeLinecap="round" />
                                </svg>
                                未连接
                              </span>
                            )}
                          </div>
                        </td>
                      ) : null}
 
                      {/* Field label */}
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {field.label}
                      </td>
 
                      {/* Current value */}
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className={`min-w-0 truncate font-mono text-sm ${hasVisibleValue ? 'text-gray-800' : 'text-gray-300'}`}>
                            {displayValue}
                          </span>
                          {dirty && (
                            <span className="inline-flex flex-shrink-0 items-center rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
                              待保存
                            </span>
                          )}
                          {field.secret && field.displayValue && (
                            <button
                              type="button"
                              onClick={() => toggleReveal(field.key)}
                              className="flex-shrink-0 text-gray-400 transition hover:text-gray-600"
                              title={revealed ? '隐藏本次输入' : '显示本次输入'}
                            >
                              {revealed
                                ? <IconEyeOff className="h-3.5 w-3.5" />
                                : <IconEye className="h-3.5 w-3.5" />
                              }
                            </button>
                          )}
                        </div>
                      </td>
 
                      {/* Edit action */}
                      <td className="px-4 py-3 text-right">
                        <button
                          type="button"
                          onClick={() => setEditingKey(field.key)}
                          className="inline-flex h-7 w-7 items-center justify-center rounded-lg border border-gray-200 bg-white text-gray-400 transition hover:border-gray-300 hover:text-gray-700"
                          title="编辑"
                        >
                          <IconEdit className="h-3.5 w-3.5" />
                        </button>
                      </td>
                    </tr>
                  );
                });
              })}
            </tbody>
          </table>
        </div>
      )}
 
      {/* Edit field modal */}
      {editingField && (
        <EditFieldModal
          fieldLabel={editingField.label}
          fieldKey={editingField.key}
          isSecret={editingField.secret ?? false}
          isMultiline={editingField.multiline ?? false}
          placeholder={editingField.placeholder || editingField.key}
          currentDisplayValue={editingField.displayValue || editingField.value || ''}
          initialValue={getDraftFieldValue(editingField, draftValues) ?? (editingField.secret ? '' : editingField.value)}
          onConfirm={(v) => onDraftChange(editingField.key, v)}
          onClose={() => setEditingKey(null)}
        />
      )}
    </div>
  );
}
 
// ─── Summary accordion row ────────────────────────────────────────────────────
 
function SummaryAccordionRow({ label, items }: { label: string; items: string[] }) {
  const [open, setOpen] = useState(false);
  const preview = items[0] ?? '';
 
  return (
    <button
      type="button"
      onClick={() => setOpen((v) => !v)}
      className="w-full rounded-xl border border-gray-200 bg-white px-5 py-3.5 text-left shadow-sm transition hover:bg-gray-50/60"
    >
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-4 min-w-0">
          <span className="flex-shrink-0 text-sm font-semibold text-gray-800">{label}</span>
          {!open && (
            <span className="truncate text-sm text-gray-500">{preview}</span>
          )}
        </div>
        <IconChevronDown className={`h-4 w-4 flex-shrink-0 text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </div>
      {open && (
        <div className="mt-3 space-y-1.5 border-t border-gray-100 pt-3">
          {items.map((item) => (
            <p key={item} className="text-sm leading-relaxed text-gray-600">{item}</p>
          ))}
        </div>
      )}
    </button>
  );
}
 
// ─── Main page ────────────────────────────────────────────────────────────────
 
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载环境配置失败');
    } finally {
      setLoading(false);
    }
  }, [user?.role]);
 
  useEffect(() => { void load(); }, [load]);
 
  const save = async () => {
    if (!data) return;
    try {
      setSaving(true);
      setError(null);
      setNotice(null);
      const values = Object.fromEntries(
        data.sections.flatMap((section) =>
          section.fields.map((field) => {
            const next = draftValues[field.key] ?? '';
            return [field.key, field.secret && !next.trim() ? field.value : next];
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存环境配置失败');
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
      const section = data.sections.find((s) => s.id === sectionId);
      if (!section) return;
      const values = Object.fromEntries(
        section.fields.map((field) => {
          const next = draftValues[field.key] ?? '';
          return [field.key, field.secret && !next.trim() ? field.value : next];
        })
      );
      const result = await adminEnvironmentApi.testSection({ sectionId, values });
      setTestResults((cur) => ({ ...cur, [sectionId]: result }));
      setNotice(result.ok ? `${section.title} 测试通过。` : `${section.title} 测试已完成，请查看结果。`);
    } catch (e) {
      setError(e instanceof Error ? e.message : '测试连接失败');
    } finally {
      setTestingSectionId(null);
    }
  };
 
  const handleDraftChange = (key: string, value: string) =>
    setDraftValues((cur) => ({ ...cur, [key]: value }));
 
  // ── Guards ───────────────────────────────────────────────────────────────────
 
  if (isLoading) {
    return (
      <AdminAppShell title="环境管理配置" description="加载中...">
        <div className="py-16 text-center text-sm text-gray-400">加载中…</div>
      </AdminAppShell>
    );
  }
 
  if (user?.role !== 'admin') {
    return (
      <AdminAppShell title="环境管理配置" description="仅管理员可访问环境配置。">
        <div className="rounded-xl border border-gray-200 bg-white p-8 text-sm text-gray-500">
          当前账号无权限访问该页面。
        </div>
      </AdminAppShell>
    );
  }
 
  return (
    <AdminAppShell
      title="环境管理配置"
      eyebrow="Raver Admin / Environment"
      description="集中查看和替换 Coze 相关环境配置，区分服务端工作流、Web 辅助工具与公共链接。"
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading || saving}
            className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 transition hover:bg-gray-50 disabled:opacity-50"
          >
            <IconRefresh className="h-4 w-4" />
            {loading ? '刷新中…' : '刷新配置'}
          </button>
          <button
            type="button"
            onClick={() => void save()}
            disabled={saving || loading || !data}
            className="flex items-center gap-2 rounded-lg bg-gray-900 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-gray-800 disabled:opacity-50"
          >
            <IconSave className="h-4 w-4" />
            {saving ? '保存中…' : '保存环境'}
          </button>
        </div>
      }
    >
      <div className="space-y-3">
        {/* Alerts */}
        {error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}
        {notice && (
          <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
            {notice}
          </div>
        )}
 
        {/* Summary accordion rows */}
        {data?.summary && (
          <div className="space-y-2">
            {data.summary.immediateEffect?.length > 0 && (
              <SummaryAccordionRow
                label="生效方式"
                items={data.summary.immediateEffect}
              />
            )}
            {data.summary.restartRecommended?.length > 0 && (
              <SummaryAccordionRow
                label="重点说明"
                items={data.summary.restartRecommended}
              />
            )}
          </div>
        )}
 
        {/* Loading state */}
        {loading && !data && (
          <div className="py-16 text-center text-sm text-gray-400">正在加载环境配置…</div>
        )}
 
        {/* Section tables */}
        {data?.sections.map((section) => (
          <SectionTable
            key={section.id}
            section={section}
            draftValues={draftValues}
            onDraftChange={handleDraftChange}
            testResult={testResults[section.id]}
            onTest={testSection}
            testingSectionId={testingSectionId}
          />
        ))}
      </div>
    </AdminAppShell>
  );
}
