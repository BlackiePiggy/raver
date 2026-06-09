'use client';

import Link from 'next/link';
import { ChangeEvent, FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import {
  adminQuizApi,
  type AdminQuizConfig,
  type AdminQuizQuestion,
  type AdminQuizQuestionInput,
  type AdminQuizUserOverride,
  type QuizAttemptMode,
  type QuizQuestionStatus,
} from '@/lib/api/admin-quiz';

type TabKey = 'config' | 'questions' | 'overrides';
type EditorMode = 'create' | 'edit';

type QuestionDraftOption = {
  id: string;
  text: string;
  imageUrl: string;
  sortOrder: number;
};

type QuestionDraft = {
  status: QuizQuestionStatus;
  stemText: string;
  stemImageUrl: string;
  correctOptionId: string;
  timeLimitSec: string;
  sortOrder: string;
  tags: string;
  difficulty: string;
  explanation: string;
  options: QuestionDraftOption[];
};

const PAGE_SIZE = 20;

const buildDraftOption = (sortOrder: number, seed?: Partial<QuestionDraftOption>): QuestionDraftOption => ({
  id: seed?.id || `opt_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
  text: seed?.text || '',
  imageUrl: seed?.imageUrl || '',
  sortOrder,
});

const createDefaultQuestionDraft = (): QuestionDraft => ({
  status: 'draft',
  stemText: '',
  stemImageUrl: '',
  correctOptionId: '',
  timeLimitSec: '',
  sortOrder: '0',
  tags: '',
  difficulty: '',
  explanation: '',
  options: [buildDraftOption(0), buildDraftOption(1)],
});

const createDraftFromQuestion = (item: AdminQuizQuestion): QuestionDraft => ({
  status: item.status,
  stemText: item.stemText || '',
  stemImageUrl: item.stemImageUrl || '',
  correctOptionId: item.correctOptionId || item.options[0]?.id || '',
  timeLimitSec: item.timeLimitSec ? String(item.timeLimitSec) : '',
  sortOrder: String(item.sortOrder ?? 0),
  tags: item.tags.join(', '),
  difficulty: item.difficulty || '',
  explanation: item.explanation || '',
  options: item.options
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((option, index) =>
      buildDraftOption(index, {
        id: option.id,
        text: option.text || '',
        imageUrl: option.imageUrl || '',
        sortOrder: option.sortOrder,
      })
    ),
});

const formatTime = (value?: string | null): string => {
  if (!value) return '-';
  return new Date(value).toLocaleString();
};

const statusClassName = (status: QuizQuestionStatus): string => {
  if (status === 'active') return 'border-accent-green/40 bg-accent-green/10 text-accent-green';
  if (status === 'archived') return 'border-red-500/40 bg-red-500/10 text-red-300';
  return 'border-yellow-500/40 bg-yellow-500/10 text-yellow-300';
};

const previewOptionLabel = (text: string, imageUrl: string): string => {
  const normalized = text.trim();
  if (normalized) return normalized;
  return imageUrl.trim() ? '图片选项' : '未填写内容';
};

function SectionCard({
  title,
  description,
  children,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-[28px] border border-border-secondary bg-bg-secondary p-5 md:p-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div>
          <div className="text-xs uppercase tracking-[0.18em] text-text-tertiary">{title}</div>
          {description ? <p className="mt-2 max-w-3xl text-sm leading-6 text-text-secondary">{description}</p> : null}
        </div>
        {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
      </div>
      <div className="mt-5">{children}</div>
    </section>
  );
}

function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="space-y-2">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium text-text-primary">{label}</span>
        {hint ? <span className="text-xs text-text-tertiary">{hint}</span> : null}
      </div>
      {children}
    </label>
  );
}

function inputClassName(multiline = false): string {
  return `w-full rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2.5 text-sm text-text-primary outline-none transition focus:border-primary-blue ${
    multiline ? 'min-h-[104px] resize-y' : ''
  }`;
}

export default function AdminQuizPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canOperate = rolePolicy.canAccessOperations;
  const canWrite = user?.role === 'admin';

  const [tab, setTab] = useState<TabKey>('config');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [config, setConfig] = useState<AdminQuizConfig | null>(null);
  const [configDraft, setConfigDraft] = useState<Partial<AdminQuizConfig>>({});
  const [configLoading, setConfigLoading] = useState(false);
  const [configSaving, setConfigSaving] = useState(false);

  const [questionQueryInput, setQuestionQueryInput] = useState('');
  const [questionQuery, setQuestionQuery] = useState('');
  const [questionStatus, setQuestionStatus] = useState<QuizQuestionStatus | ''>('');
  const [questionPage, setQuestionPage] = useState(1);
  const [questions, setQuestions] = useState<AdminQuizQuestion[]>([]);
  const [questionTotal, setQuestionTotal] = useState(0);
  const [questionLoading, setQuestionLoading] = useState(false);
  const [selectedQuestionId, setSelectedQuestionId] = useState<string | null>(null);
  const [editorMode, setEditorMode] = useState<EditorMode>('create');
  const [questionDraft, setQuestionDraft] = useState<QuestionDraft>(createDefaultQuestionDraft());
  const [questionSaving, setQuestionSaving] = useState(false);
  const [uploadingTarget, setUploadingTarget] = useState<string | null>(null);

  const [overrideQueryInput, setOverrideQueryInput] = useState('');
  const [overrideQuery, setOverrideQuery] = useState('');
  const [overridePage, setOverridePage] = useState(1);
  const [overrides, setOverrides] = useState<AdminQuizUserOverride[]>([]);
  const [overrideTotal, setOverrideTotal] = useState(0);
  const [overrideLoading, setOverrideLoading] = useState(false);
  const [overrideSavingUserId, setOverrideSavingUserId] = useState<string | null>(null);
  const [overrideDrafts, setOverrideDrafts] = useState<
    Record<string, { attemptMode: QuizAttemptMode; dailyAttemptLimitOverride: string; note: string }>
  >({});

  const selectedQuestion = useMemo(
    () => questions.find((item) => item.id === selectedQuestionId) || null,
    [questions, selectedQuestionId]
  );

  const loadConfig = useCallback(async () => {
    if (!canOperate) return;
    try {
      setConfigLoading(true);
      const result = await adminQuizApi.getConfig();
      setConfig(result.config);
      setConfigDraft(result.config);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载答题配置失败');
    } finally {
      setConfigLoading(false);
    }
  }, [canOperate]);

  const loadQuestions = useCallback(async () => {
    if (!canOperate) return;
    try {
      setQuestionLoading(true);
      const result = await adminQuizApi.listQuestions({
        q: questionQuery.trim() || undefined,
        status: questionStatus,
        page: questionPage,
        limit: PAGE_SIZE,
      });
      setQuestions(result.items);
      setQuestionTotal(result.pagination.total);
      setSelectedQuestionId((current) => current && result.items.some((item) => item.id === current) ? current : result.items[0]?.id || null);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载题库失败');
    } finally {
      setQuestionLoading(false);
    }
  }, [canOperate, questionPage, questionQuery, questionStatus]);

  const loadOverrides = useCallback(async () => {
    if (!canOperate) return;
    try {
      setOverrideLoading(true);
      const result = await adminQuizApi.listUserOverrides({
        q: overrideQuery.trim() || undefined,
        page: overridePage,
        limit: PAGE_SIZE,
      });
      setOverrides(result.items);
      setOverrideTotal(result.pagination.total);
      setOverrideDrafts((current) => {
        const next = { ...current };
        for (const item of result.items) {
          next[item.userId] = next[item.userId] || {
            attemptMode: item.attemptMode,
            dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
            note: item.note || '',
          };
        }
        return next;
      });
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载用户覆盖失败');
    } finally {
      setOverrideLoading(false);
    }
  }, [canOperate, overridePage, overrideQuery]);

  useEffect(() => {
    void loadConfig();
  }, [loadConfig]);

  useEffect(() => {
    void loadQuestions();
  }, [loadQuestions]);

  useEffect(() => {
    void loadOverrides();
  }, [loadOverrides]);

  useEffect(() => {
    if (selectedQuestion && editorMode === 'edit') {
      setQuestionDraft(createDraftFromQuestion(selectedQuestion));
    }
  }, [editorMode, selectedQuestion]);

  const totalQuestionPages = Math.max(1, Math.ceil(questionTotal / PAGE_SIZE));
  const totalOverridePages = Math.max(1, Math.ceil(overrideTotal / PAGE_SIZE));

  const submitConfig = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!canWrite || !configDraft) return;
    try {
      setConfigSaving(true);
      setError(null);
      setNotice(null);
      const result = await adminQuizApi.updateConfig({
        isEnabled: Boolean(configDraft.isEnabled),
        questionCount: Number(configDraft.questionCount),
        passCorrectCount: Number(configDraft.passCorrectCount),
        dailyAttemptLimit: Number(configDraft.dailyAttemptLimit),
        defaultTimeLimitSec: Number(configDraft.defaultTimeLimitSec),
        dailyLimitTimeZone: String(configDraft.dailyLimitTimeZone || 'Asia/Shanghai'),
        allowRetakeAfterPass: Boolean(configDraft.allowRetakeAfterPass),
        allowRestartDuringSession: Boolean(configDraft.allowRestartDuringSession),
      });
      setConfig(result.config);
      setConfigDraft(result.config);
      setNotice('答题系统配置已保存');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存答题配置失败');
    } finally {
      setConfigSaving(false);
    }
  };

  const buildQuestionInput = (): AdminQuizQuestionInput => ({
    status: questionDraft.status,
    type: 'single_choice',
    stemText: questionDraft.stemText.trim(),
    stemImageUrl: questionDraft.stemImageUrl.trim() || null,
    correctOptionId: questionDraft.correctOptionId,
    timeLimitSec: questionDraft.timeLimitSec.trim() ? Number(questionDraft.timeLimitSec) : null,
    sortOrder: questionDraft.sortOrder.trim() ? Number(questionDraft.sortOrder) : 0,
    tags: questionDraft.tags
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean),
    difficulty: questionDraft.difficulty.trim() || null,
    explanation: questionDraft.explanation.trim() || null,
    options: questionDraft.options.map((option, index) => ({
      id: option.id,
      text: option.text.trim() || null,
      imageUrl: option.imageUrl.trim() || null,
      sortOrder: Number.isFinite(option.sortOrder) ? option.sortOrder : index,
    })),
  });

  const submitQuestion = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!canWrite) return;
    try {
      setQuestionSaving(true);
      setError(null);
      setNotice(null);
      const payload = buildQuestionInput();
      const result =
        editorMode === 'edit' && selectedQuestionId
          ? await adminQuizApi.updateQuestion(selectedQuestionId, payload)
          : await adminQuizApi.createQuestion(payload);
      setNotice(editorMode === 'edit' ? '题目已更新' : '题目已创建');
      setEditorMode('edit');
      setSelectedQuestionId(result.item.id);
      await loadQuestions();
      setQuestionDraft(createDraftFromQuestion(result.item));
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const archiveQuestion = async () => {
    if (!canWrite || !selectedQuestionId) return;
    const confirmed = window.confirm('确认归档这道题吗？归档后不会参与抽题。');
    if (!confirmed) return;
    try {
      setQuestionSaving(true);
      setError(null);
      setNotice(null);
      await adminQuizApi.archiveQuestion(selectedQuestionId);
      setNotice('题目已归档');
      await loadQuestions();
    } catch (archiveError) {
      setError(archiveError instanceof Error ? archiveError.message : '归档题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const uploadImage = async (event: ChangeEvent<HTMLInputElement>, target: 'stem' | string) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    try {
      setUploadingTarget(target);
      setError(null);
      const uploaded = await adminQuizApi.uploadImage(file);
      if (target === 'stem') {
        setQuestionDraft((current) => ({ ...current, stemImageUrl: uploaded.url }));
      } else {
        setQuestionDraft((current) => ({
          ...current,
          options: current.options.map((option) =>
            option.id === target ? { ...option, imageUrl: uploaded.url } : option
          ),
        }));
      }
      setNotice('图片上传成功');
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : '图片上传失败');
    } finally {
      setUploadingTarget(null);
    }
  };

  const saveOverride = async (userId: string) => {
    if (!canWrite) return;
    const draft = overrideDrafts[userId];
    if (!draft) return;
    try {
      setOverrideSavingUserId(userId);
      setError(null);
      setNotice(null);
      await adminQuizApi.updateUserOverride({
        userId,
        attemptMode: draft.attemptMode,
        dailyAttemptLimitOverride: draft.attemptMode === 'custom_limit' ? Number(draft.dailyAttemptLimitOverride || 0) : null,
        note: draft.note.trim() || null,
      });
      setNotice('用户次数覆盖已保存');
      await loadOverrides();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存用户覆盖失败');
    } finally {
      setOverrideSavingUserId(null);
    }
  };

  if (isLoading) {
    return (
      <AdminAppShell title="答题系统" description="加载答题系统配置中。">
        <div className="admin-shell-panel p-8 text-sm text-black/55">加载中...</div>
      </AdminAppShell>
    );
  }

  if (!user || !canOperate) {
    return (
      <AdminAppShell title="答题系统" description="当前账号暂时不能访问答题系统后台。">
        <section className="mx-auto max-w-4xl">
          <div className="admin-shell-panel p-6">
            <h1 className="text-2xl font-semibold">答题系统</h1>
            <p className="mt-3 text-sm text-text-secondary">当前账号无权限访问该页面。</p>
            <Link href={user ? '/admin' : '/login'} className="mt-5 inline-flex rounded-full bg-[#071110] px-5 py-3 text-sm font-semibold text-white">
              {user ? '返回后台' : '去登录'}
            </Link>
          </div>
        </section>
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell
      title="答题系统"
      eyebrow="Raver Admin / Quiz"
      description="围绕主线维护题库、全局配置与用户级答题次数覆盖。"
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => {
              void loadConfig();
              void loadQuestions();
              void loadOverrides();
            }}
            className="rounded-full border border-border-secondary px-4 py-2 text-sm font-semibold text-text-primary"
          >
            刷新
          </button>
        </div>
      }
    >
      <section className="space-y-5">
        <div className="flex flex-wrap gap-2">
          {([
            ['config', '配置'],
            ['questions', '题库'],
            ['overrides', '用户次数覆盖'],
          ] as Array<[TabKey, string]>).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setTab(key)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
                tab === key ? 'bg-[#071110] text-white' : 'border border-border-secondary text-text-primary'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {error ? <div className="rounded-xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">{error}</div> : null}
        {notice ? <div className="rounded-xl border border-accent-green/40 bg-accent-green/10 px-4 py-3 text-sm text-accent-green">{notice}</div> : null}

        {tab === 'config' ? (
          <SectionCard title="Quiz Config" description="控制答题系统的开关、抽题规模、通过标准和每日次数规则。">
            <form onSubmit={submitConfig} className="grid gap-4 lg:grid-cols-2">
              <Field label="系统启用">
                <label className="inline-flex items-center gap-2 rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  <input
                    type="checkbox"
                    checked={Boolean(configDraft.isEnabled)}
                    onChange={(event) => setConfigDraft((current) => ({ ...current, isEnabled: event.target.checked }))}
                  />
                  <span>{configDraft.isEnabled ? '已启用' : '未启用'}</span>
                </label>
              </Field>
              <Field label="通过后允许再次答题">
                <label className="inline-flex items-center gap-2 rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  <input
                    type="checkbox"
                    checked={Boolean(configDraft.allowRetakeAfterPass)}
                    onChange={(event) => setConfigDraft((current) => ({ ...current, allowRetakeAfterPass: event.target.checked }))}
                  />
                  <span>{configDraft.allowRetakeAfterPass ? '允许' : '不允许'}</span>
                </label>
              </Field>
              <Field label="答题数量">
                <input
                  value={String(configDraft.questionCount ?? '')}
                  onChange={(event) => setConfigDraft((current) => ({ ...current, questionCount: Number(event.target.value || 0) }))}
                  className={inputClassName()}
                />
              </Field>
              <Field label="通过所需正确题数">
                <input
                  value={String(configDraft.passCorrectCount ?? '')}
                  onChange={(event) => setConfigDraft((current) => ({ ...current, passCorrectCount: Number(event.target.value || 0) }))}
                  className={inputClassName()}
                />
              </Field>
              <Field label="默认每日次数">
                <input
                  value={String(configDraft.dailyAttemptLimit ?? '')}
                  onChange={(event) => setConfigDraft((current) => ({ ...current, dailyAttemptLimit: Number(event.target.value || 0) }))}
                  className={inputClassName()}
                />
              </Field>
              <Field label="默认单题时长（秒）">
                <input
                  value={String(configDraft.defaultTimeLimitSec ?? '')}
                  onChange={(event) => setConfigDraft((current) => ({ ...current, defaultTimeLimitSec: Number(event.target.value || 0) }))}
                  className={inputClassName()}
                />
              </Field>
              <Field label="日限额时区">
                <input
                  value={String(configDraft.dailyLimitTimeZone ?? '')}
                  onChange={(event) => setConfigDraft((current) => ({ ...current, dailyLimitTimeZone: event.target.value }))}
                  className={inputClassName()}
                />
              </Field>
              <Field label="允许答题中重启">
                <label className="inline-flex items-center gap-2 rounded-xl border border-border-secondary bg-bg-tertiary px-3 py-2 text-sm">
                  <input
                    type="checkbox"
                    checked={Boolean(configDraft.allowRestartDuringSession)}
                    onChange={(event) => setConfigDraft((current) => ({ ...current, allowRestartDuringSession: event.target.checked }))}
                  />
                  <span>{configDraft.allowRestartDuringSession ? '允许' : '不允许'}</span>
                </label>
              </Field>
              <div className="lg:col-span-2 flex items-center justify-between rounded-xl border border-border-secondary bg-bg-tertiary px-4 py-3 text-sm text-text-secondary">
                <span>最后更新时间：{config ? formatTime(config.updatedAt) : configLoading ? '加载中...' : '-'}</span>
                <button
                  type="submit"
                  disabled={!canWrite || configSaving || configLoading}
                  className="rounded-full bg-[#071110] px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
                >
                  {configSaving ? '保存中...' : '保存配置'}
                </button>
              </div>
            </form>
          </SectionCard>
        ) : null}

        {tab === 'questions' ? (
          <div className="grid gap-5 xl:grid-cols-[420px_minmax(0,1fr)]">
            <SectionCard
              title="Question Library"
              description="搜索、筛选题目并进入右侧编辑器。"
              actions={
                <button
                  type="button"
                  onClick={() => {
                    setEditorMode('create');
                    setSelectedQuestionId(null);
                    setQuestionDraft(createDefaultQuestionDraft());
                  }}
                  className="rounded-full bg-[#071110] px-4 py-2 text-sm font-semibold text-white"
                >
                  新建题目
                </button>
              }
            >
              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  setQuestionPage(1);
                  setQuestionQuery(questionQueryInput);
                }}
                className="space-y-3"
              >
                <input
                  value={questionQueryInput}
                  onChange={(event) => setQuestionQueryInput(event.target.value)}
                  placeholder="搜索题干 / 难度 / id"
                  className={inputClassName()}
                />
                <div className="grid gap-3 sm:grid-cols-[1fr_auto]">
                  <select
                    value={questionStatus}
                    onChange={(event) => {
                      setQuestionStatus(event.target.value as QuizQuestionStatus | '');
                      setQuestionPage(1);
                    }}
                    className={inputClassName()}
                  >
                    <option value="">全部状态</option>
                    <option value="draft">draft</option>
                    <option value="active">active</option>
                    <option value="archived">archived</option>
                  </select>
                  <button type="submit" className="rounded-xl border border-border-secondary px-4 py-2.5 text-sm font-semibold text-text-primary">
                    搜索
                  </button>
                </div>
              </form>

              <div className="mt-4 space-y-3">
                {questionLoading ? <div className="text-sm text-text-secondary">题库加载中...</div> : null}
                {questions.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      setSelectedQuestionId(item.id);
                      setEditorMode('edit');
                      setQuestionDraft(createDraftFromQuestion(item));
                    }}
                    className={`w-full rounded-2xl border p-4 text-left transition ${
                      selectedQuestionId === item.id
                        ? 'border-primary-blue bg-primary-blue/10'
                        : 'border-border-secondary bg-bg-tertiary hover:border-primary-blue/50'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="line-clamp-2 text-sm font-semibold text-text-primary">{item.stemText}</div>
                        <div className="mt-2 flex flex-wrap gap-2 text-[11px] text-text-tertiary">
                          <span className={`rounded-full border px-2 py-1 ${statusClassName(item.status)}`}>{item.status}</span>
                          <span className="rounded-full border border-border-secondary px-2 py-1">选项 {item.options.length}</span>
                          <span className="rounded-full border border-border-secondary px-2 py-1">限时 {item.timeLimitSec ?? '-'}</span>
                        </div>
                      </div>
                    </div>
                    <div className="mt-3 text-[11px] text-text-tertiary">{item.id}</div>
                  </button>
                ))}
              </div>

              <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
                <span>
                  第 {questionPage} / {totalQuestionPages} 页，共 {questionTotal} 题
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    disabled={questionPage <= 1}
                    onClick={() => setQuestionPage((current) => Math.max(1, current - 1))}
                    className="rounded-full border border-border-secondary px-3 py-1.5 disabled:opacity-50"
                  >
                    上一页
                  </button>
                  <button
                    type="button"
                    disabled={questionPage >= totalQuestionPages}
                    onClick={() => setQuestionPage((current) => Math.min(totalQuestionPages, current + 1))}
                    className="rounded-full border border-border-secondary px-3 py-1.5 disabled:opacity-50"
                  >
                    下一页
                  </button>
                </div>
              </div>
            </SectionCard>

            <SectionCard
              title={editorMode === 'edit' ? 'Question Editor' : 'Create Question'}
              description="当前版本只支持单选题。题干和选项都可以上传图片。"
              actions={
                <div className="flex gap-2">
                  {editorMode === 'edit' ? (
                    <button
                      type="button"
                      onClick={archiveQuestion}
                      disabled={!canWrite || !selectedQuestionId || questionSaving}
                      className="rounded-full border border-red-500/40 px-4 py-2 text-sm font-semibold text-red-300 disabled:opacity-50"
                    >
                      归档
                    </button>
                  ) : null}
                </div>
              }
            >
              <form onSubmit={submitQuestion} className="space-y-5">
                <div className="grid gap-4 lg:grid-cols-2">
                  <Field label="题目状态">
                    <select
                      value={questionDraft.status}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, status: event.target.value as QuizQuestionStatus }))}
                      className={inputClassName()}
                    >
                      <option value="draft">draft</option>
                      <option value="active">active</option>
                      <option value="archived">archived</option>
                    </select>
                  </Field>
                  <Field label="正确答案 optionId" hint="必须对应某个选项 id">
                    <input
                      value={questionDraft.correctOptionId}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, correctOptionId: event.target.value }))}
                      className={inputClassName()}
                    />
                  </Field>
                  <Field label="单题时长（秒）">
                    <input
                      value={questionDraft.timeLimitSec}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, timeLimitSec: event.target.value }))}
                      className={inputClassName()}
                    />
                  </Field>
                  <Field label="排序值">
                    <input
                      value={questionDraft.sortOrder}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, sortOrder: event.target.value }))}
                      className={inputClassName()}
                    />
                  </Field>
                  <div className="lg:col-span-2">
                    <Field label="题干文本">
                      <textarea
                        value={questionDraft.stemText}
                        onChange={(event) => setQuestionDraft((current) => ({ ...current, stemText: event.target.value }))}
                        className={inputClassName(true)}
                      />
                    </Field>
                  </div>
                  <Field label="题干图片 URL">
                    <div className="space-y-2">
                      <input
                        value={questionDraft.stemImageUrl}
                        onChange={(event) => setQuestionDraft((current) => ({ ...current, stemImageUrl: event.target.value }))}
                        className={inputClassName()}
                      />
                      <div className="flex items-center gap-3">
                        <label className="rounded-full border border-border-secondary px-3 py-1.5 text-sm font-semibold text-text-primary">
                          <input type="file" accept="image/*" className="hidden" onChange={(event) => void uploadImage(event, 'stem')} />
                          {uploadingTarget === 'stem' ? '上传中...' : '上传题干图片'}
                        </label>
                        {questionDraft.stemImageUrl ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={questionDraft.stemImageUrl} alt="stem" className="h-16 w-16 rounded-xl object-cover" />
                        ) : null}
                      </div>
                    </div>
                  </Field>
                  <Field label="标签" hint="逗号分隔">
                    <input
                      value={questionDraft.tags}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, tags: event.target.value }))}
                      className={inputClassName()}
                    />
                  </Field>
                  <Field label="难度">
                    <input
                      value={questionDraft.difficulty}
                      onChange={(event) => setQuestionDraft((current) => ({ ...current, difficulty: event.target.value }))}
                      className={inputClassName()}
                    />
                  </Field>
                  <div className="lg:col-span-2">
                    <Field label="解释说明" hint="后台可维护，答题过程中不展示">
                      <textarea
                        value={questionDraft.explanation}
                        onChange={(event) => setQuestionDraft((current) => ({ ...current, explanation: event.target.value }))}
                        className={inputClassName(true)}
                      />
                    </Field>
                  </div>
                </div>

                <div className="space-y-4 rounded-2xl border border-border-secondary bg-bg-tertiary p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-sm font-semibold text-text-primary">选项列表</div>
                      <div className="text-xs text-text-tertiary">至少 2 个，最多 6 个。每个选项可文字、图片或图文同时存在。</div>
                    </div>
                    <button
                      type="button"
                      disabled={questionDraft.options.length >= 6}
                      onClick={() =>
                        setQuestionDraft((current) => ({
                          ...current,
                          options: [...current.options, buildDraftOption(current.options.length)],
                        }))
                      }
                      className="rounded-full border border-border-secondary px-3 py-1.5 text-sm font-semibold disabled:opacity-50"
                    >
                      新增选项
                    </button>
                  </div>

                  <div className="space-y-4">
                    {questionDraft.options.map((option, index) => (
                      <div key={option.id} className="rounded-2xl border border-border-secondary bg-bg-secondary p-4">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-semibold text-text-primary">
                            选项 {index + 1} · id: <span className="font-mono text-xs">{option.id}</span>
                          </div>
                          <button
                            type="button"
                            disabled={questionDraft.options.length <= 2}
                            onClick={() =>
                              setQuestionDraft((current) => {
                                const nextOptions = current.options.filter((item) => item.id !== option.id);
                                const nextCorrectOptionId =
                                  current.correctOptionId === option.id ? nextOptions[0]?.id || '' : current.correctOptionId;
                                return {
                                  ...current,
                                  correctOptionId: nextCorrectOptionId,
                                  options: nextOptions.map((item, nextIndex) => ({ ...item, sortOrder: nextIndex })),
                                };
                              })
                            }
                            className="text-xs text-red-300 disabled:opacity-50"
                          >
                            删除
                          </button>
                        </div>
                        <div className="mt-4 grid gap-4 lg:grid-cols-2">
                          <Field label="选项文本">
                            <input
                              value={option.text}
                              onChange={(event) =>
                                setQuestionDraft((current) => ({
                                  ...current,
                                  options: current.options.map((item) =>
                                    item.id === option.id ? { ...item, text: event.target.value } : item
                                  ),
                                }))
                              }
                              className={inputClassName()}
                            />
                          </Field>
                          <Field label="选项图片 URL">
                            <div className="space-y-2">
                              <input
                                value={option.imageUrl}
                                onChange={(event) =>
                                  setQuestionDraft((current) => ({
                                    ...current,
                                    options: current.options.map((item) =>
                                      item.id === option.id ? { ...item, imageUrl: event.target.value } : item
                                    ),
                                  }))
                                }
                                className={inputClassName()}
                              />
                              <div className="flex items-center gap-3">
                                <label className="rounded-full border border-border-secondary px-3 py-1.5 text-sm font-semibold text-text-primary">
                                  <input
                                    type="file"
                                    accept="image/*"
                                    className="hidden"
                                    onChange={(event) => void uploadImage(event, option.id)}
                                  />
                                  {uploadingTarget === option.id ? '上传中...' : '上传选项图片'}
                                </label>
                                {option.imageUrl ? (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img src={option.imageUrl} alt={option.text || option.id} className="h-14 w-14 rounded-xl object-cover" />
                                ) : null}
                              </div>
                            </div>
                          </Field>
                        </div>
                        <label className="mt-3 inline-flex items-center gap-2 text-sm text-text-secondary">
                          <input
                            type="radio"
                            checked={questionDraft.correctOptionId === option.id}
                            onChange={() => setQuestionDraft((current) => ({ ...current, correctOptionId: option.id }))}
                          />
                          设为正确答案
                        </label>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="space-y-4 rounded-2xl border border-border-secondary bg-bg-tertiary p-4">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-semibold text-text-primary">题目预览</div>
                      <div className="text-xs text-text-tertiary">按当前草稿实时预览最终答题展示结构，不显示正确答案反馈。</div>
                    </div>
                    <div className="rounded-full border border-border-secondary px-3 py-1 text-xs text-text-tertiary">
                      单选题 · {questionDraft.options.length} 个选项
                    </div>
                  </div>

                  <div className="rounded-[24px] border border-border-secondary bg-bg-secondary p-5">
                    <div className="flex flex-wrap items-center gap-2 text-xs text-text-tertiary">
                      <span className={`rounded-full border px-2 py-1 ${statusClassName(questionDraft.status)}`}>
                        {questionDraft.status}
                      </span>
                      <span className="rounded-full border border-border-secondary px-2 py-1">
                        限时 {questionDraft.timeLimitSec.trim() || '-'} 秒
                      </span>
                      <span className="rounded-full border border-border-secondary px-2 py-1">
                        正确答案 {questionDraft.correctOptionId.trim() || '未指定'}
                      </span>
                    </div>

                    <div className="mt-4 space-y-4">
                      <div className="text-lg font-semibold leading-8 text-text-primary">
                        {questionDraft.stemText.trim() || '题干预览将在这里显示'}
                      </div>

                      {questionDraft.stemImageUrl.trim() ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={questionDraft.stemImageUrl.trim()}
                          alt="题干预览"
                          className="max-h-[260px] w-full rounded-2xl border border-border-secondary object-contain bg-bg-tertiary"
                        />
                      ) : null}

                      <div className="space-y-3">
                        {questionDraft.options.map((option, index) => {
                          const isCorrect = questionDraft.correctOptionId === option.id;
                          return (
                            <div
                              key={`preview-${option.id}`}
                              className={`rounded-2xl border p-4 ${
                                isCorrect
                                  ? 'border-accent-green/40 bg-accent-green/10'
                                  : 'border-border-secondary bg-bg-tertiary'
                              }`}
                            >
                              <div className="flex items-start gap-3">
                                <div
                                  className={`mt-0.5 h-5 w-5 rounded-full border ${
                                    isCorrect ? 'border-accent-green bg-accent-green/15' : 'border-border-secondary'
                                  }`}
                                />
                                <div className="min-w-0 flex-1 space-y-3">
                                  <div className="flex flex-wrap items-center gap-2">
                                    <span className="rounded-full border border-border-secondary px-2 py-1 text-[11px] text-text-tertiary">
                                      选项 {index + 1}
                                    </span>
                                    <span className="font-mono text-[11px] text-text-tertiary">{option.id}</span>
                                  </div>
                                  <div className="text-sm font-medium leading-6 text-text-primary">
                                    {previewOptionLabel(option.text, option.imageUrl)}
                                  </div>
                                  {option.imageUrl.trim() ? (
                                    // eslint-disable-next-line @next/next/no-img-element
                                    <img
                                      src={option.imageUrl.trim()}
                                      alt={previewOptionLabel(option.text, option.imageUrl)}
                                      className="max-h-[220px] w-full rounded-2xl border border-border-secondary object-contain bg-bg-secondary"
                                    />
                                  ) : null}
                                </div>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between rounded-xl border border-border-secondary bg-bg-tertiary px-4 py-3">
                  <div className="text-sm text-text-secondary">
                    {editorMode === 'edit' && selectedQuestion ? `最后更新：${formatTime(selectedQuestion.updatedAt)}` : '新建题目后会自动进入编辑状态'}
                  </div>
                  <button
                    type="submit"
                    disabled={!canWrite || questionSaving}
                    className="rounded-full bg-[#071110] px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {questionSaving ? '保存中...' : editorMode === 'edit' ? '保存题目' : '创建题目'}
                  </button>
                </div>
              </form>
            </SectionCard>
          </div>
        ) : null}

        {tab === 'overrides' ? (
          <SectionCard
            title="User Attempt Overrides"
            description="按用户设置 quiz 次数策略。`default` 继承全局默认；`custom_limit` 使用专属次数；`unlimited` 供官方测试或特殊用户使用。"
          >
            <form
              onSubmit={(event) => {
                event.preventDefault();
                setOverridePage(1);
                setOverrideQuery(overrideQueryInput);
              }}
              className="grid gap-3 md:grid-cols-[1fr_auto]"
            >
              <input
                value={overrideQueryInput}
                onChange={(event) => setOverrideQueryInput(event.target.value)}
                placeholder="搜索邮箱 / 用户名 / displayName / userId"
                className={inputClassName()}
              />
              <button type="submit" className="rounded-xl border border-border-secondary px-4 py-2.5 text-sm font-semibold text-text-primary">
                搜索
              </button>
            </form>

            <div className="mt-4 space-y-4">
              {overrideLoading ? <div className="text-sm text-text-secondary">加载用户覆盖中...</div> : null}
              {overrides.map((item) => {
                const draft = overrideDrafts[item.userId] || {
                  attemptMode: item.attemptMode,
                  dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
                  note: item.note || '',
                };
                return (
                  <div key={item.id} className="rounded-2xl border border-border-secondary bg-bg-tertiary p-4">
                    <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                      <div className="min-w-0">
                        <div className="text-sm font-semibold text-text-primary">
                          {item.user.displayName || item.user.username}
                        </div>
                        <div className="mt-1 text-sm text-text-secondary">{item.user.email}</div>
                        <div className="mt-1 font-mono text-[11px] text-text-tertiary">{item.userId}</div>
                        <div className="mt-2 text-xs text-text-tertiary">最近更新时间：{formatTime(item.updatedAt)}</div>
                      </div>
                      <div className="grid min-w-0 flex-1 gap-3 lg:grid-cols-[180px_180px_minmax(0,1fr)_auto]">
                        <select
                          value={draft.attemptMode}
                          onChange={(event) =>
                            setOverrideDrafts((current) => ({
                              ...current,
                              [item.userId]: {
                                ...draft,
                                attemptMode: event.target.value as QuizAttemptMode,
                              },
                            }))
                          }
                          className={inputClassName()}
                        >
                          <option value="default">default</option>
                          <option value="custom_limit">custom_limit</option>
                          <option value="unlimited">unlimited</option>
                        </select>
                        <input
                          value={draft.dailyAttemptLimitOverride}
                          disabled={draft.attemptMode !== 'custom_limit'}
                          onChange={(event) =>
                            setOverrideDrafts((current) => ({
                              ...current,
                              [item.userId]: {
                                ...draft,
                                dailyAttemptLimitOverride: event.target.value,
                              },
                            }))
                          }
                          placeholder="专属次数"
                          className={inputClassName()}
                        />
                        <input
                          value={draft.note}
                          onChange={(event) =>
                            setOverrideDrafts((current) => ({
                              ...current,
                              [item.userId]: {
                                ...draft,
                                note: event.target.value,
                              },
                            }))
                          }
                          placeholder="备注，例如官方测试 / 白名单"
                          className={inputClassName()}
                        />
                        <button
                          type="button"
                          onClick={() => void saveOverride(item.userId)}
                          disabled={!canWrite || overrideSavingUserId === item.userId}
                          className="rounded-xl bg-[#071110] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
                        >
                          {overrideSavingUserId === item.userId ? '保存中...' : '保存'}
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
              <span>
                第 {overridePage} / {totalOverridePages} 页，共 {overrideTotal} 条
              </span>
              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={overridePage <= 1}
                  onClick={() => setOverridePage((current) => Math.max(1, current - 1))}
                  className="rounded-full border border-border-secondary px-3 py-1.5 disabled:opacity-50"
                >
                  上一页
                </button>
                <button
                  type="button"
                  disabled={overridePage >= totalOverridePages}
                  onClick={() => setOverridePage((current) => Math.min(totalOverridePages, current + 1))}
                  className="rounded-full border border-border-secondary px-3 py-1.5 disabled:opacity-50"
                >
                  下一页
                </button>
              </div>
            </div>
          </SectionCard>
        ) : null}
      </section>
    </AdminAppShell>
  );
}
