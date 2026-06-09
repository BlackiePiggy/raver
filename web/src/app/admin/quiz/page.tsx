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
  type AdminQuizQuestionImportInput,
  type AdminQuizQuestionInput,
  type AdminQuizUserOverride,
  type QuizAttemptMode,
  type QuizQuestionStatus,
} from '@/lib/api/admin-quiz';

type TabKey = 'config' | 'questions' | 'overrides';
type EditorMode = 'create' | 'edit';

const QUIZ_IMPORT_EXAMPLE = `[
  {
    "status": "draft",
    "stemText": "以下哪一项最符合 House 的典型特征？",
    "timeLimitSec": 20,
    "tags": ["house", "genre"],
    "difficulty": "easy",
    "options": [
      { "id": "opt_a", "text": "稳定四拍地板鼓", "isCorrect": true },
      { "id": "opt_b", "text": "极端 breakcore 节奏" },
      { "id": "opt_c", "text": "完全无鼓点环境音" }
    ]
  },
  {
    "status": "active",
    "stemText": "图中这个术语对应哪种设备？",
    "stemImageUrl": "https://example.com/question-image.jpg",
    "correctOptionIndex": 1,
    "options": [
      { "text": "调音台" },
      { "text": "CDJ / 播放器" },
      { "text": "监听耳机" }
    ]
  }
]`;

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

const OPTION_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

const statusBadgeClass = (status: QuizQuestionStatus): string => {
  if (status === 'active') return 'bg-emerald-50 text-emerald-700 border border-emerald-200';
  if (status === 'archived') return 'bg-red-50 text-red-600 border border-red-200';
  return 'bg-amber-50 text-amber-700 border border-amber-200';
};

const previewOptionLabel = (text: string, imageUrl: string): string => {
  const normalized = text.trim();
  if (normalized) return normalized;
  return imageUrl.trim() ? '图片选项' : '未填写内容';
};

/* ─── shared input style ─── */
const inputCls = (multiline = false) =>
  `w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 outline-none transition focus:border-gray-900 focus:ring-0 ${
    multiline ? 'min-h-[96px] resize-y' : ''
  }`;

const selectCls = () =>
  `w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 outline-none transition focus:border-gray-900`;

/* ─── Field label wrapper ─── */
function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-xs font-medium text-gray-500 tracking-wide">
        {label}
        {hint ? <span className="ml-1.5 font-normal text-gray-400">{hint}</span> : null}
      </span>
      {children}
    </label>
  );
}

/* ─── Inline notice / error banner ─── */
function Banner({ type, message }: { type: 'error' | 'notice'; message: string }) {
  return (
    <div
      className={`rounded-xl px-4 py-3 text-sm font-medium ${
        type === 'error'
          ? 'bg-red-50 text-red-700 border border-red-200'
          : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
      }`}
    >
      {message}
    </div>
  );
}

/* ─── Main page ─── */
export default function AdminQuizPage() {
  const { user, isLoading } = useAuth();
  const rolePolicy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canOperate = rolePolicy.canAccessOperations;
  const canWrite = user?.role === 'admin';

  const [tab, setTab] = useState<TabKey>('config');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  /* config */
  const [config, setConfig] = useState<AdminQuizConfig | null>(null);
  const [configDraft, setConfigDraft] = useState<Partial<AdminQuizConfig>>({});
  const [configLoading, setConfigLoading] = useState(false);
  const [configSaving, setConfigSaving] = useState(false);

  /* questions */
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
  const [showImportPanel, setShowImportPanel] = useState(false);
  const [importText, setImportText] = useState(QUIZ_IMPORT_EXAMPLE);
  const [importingQuestions, setImportingQuestions] = useState(false);

  /* overrides */
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

  /* ── loaders ── */
  const loadConfig = useCallback(async () => {
    if (!canOperate) return;
    try {
      setConfigLoading(true);
      const result = await adminQuizApi.getConfig();
      setConfig(result.config);
      setConfigDraft(result.config);
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载答题配置失败');
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
      setSelectedQuestionId((cur) =>
        cur && result.items.some((i) => i.id === cur) ? cur : result.items[0]?.id || null
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载题库失败');
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
      setOverrideDrafts((cur) => {
        const next = { ...cur };
        for (const item of result.items) {
          next[item.userId] = next[item.userId] || {
            attemptMode: item.attemptMode,
            dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
            note: item.note || '',
          };
        }
        return next;
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : '加载用户覆盖失败');
    } finally {
      setOverrideLoading(false);
    }
  }, [canOperate, overridePage, overrideQuery]);

  useEffect(() => { void loadConfig(); }, [loadConfig]);
  useEffect(() => { void loadQuestions(); }, [loadQuestions]);
  useEffect(() => { void loadOverrides(); }, [loadOverrides]);

  useEffect(() => {
    if (selectedQuestion && editorMode === 'edit') {
      setQuestionDraft(createDraftFromQuestion(selectedQuestion));
    }
  }, [editorMode, selectedQuestion]);

  const totalQuestionPages = Math.max(1, Math.ceil(questionTotal / PAGE_SIZE));
  const totalOverridePages = Math.max(1, Math.ceil(overrideTotal / PAGE_SIZE));

  /* ── submit handlers ── */
  const submitConfig = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存答题配置失败');
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
    tags: questionDraft.tags.split(',').map((t) => t.trim()).filter(Boolean),
    difficulty: questionDraft.difficulty.trim() || null,
    explanation: questionDraft.explanation.trim() || null,
    options: questionDraft.options.map((opt, i) => ({
      id: opt.id,
      text: opt.text.trim() || null,
      imageUrl: opt.imageUrl.trim() || null,
      sortOrder: Number.isFinite(opt.sortOrder) ? opt.sortOrder : i,
    })),
  });

  const submitQuestion = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
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
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const archiveQuestion = async () => {
    if (!canWrite || !selectedQuestionId) return;
    if (!window.confirm('确认归档这道题吗？归档后不会参与抽题。')) return;
    try {
      setQuestionSaving(true);
      setError(null);
      setNotice(null);
      await adminQuizApi.archiveQuestion(selectedQuestionId);
      setNotice('题目已归档');
      await loadQuestions();
    } catch (e) {
      setError(e instanceof Error ? e.message : '归档题目失败');
    } finally {
      setQuestionSaving(false);
    }
  };

  const uploadImage = async (e: ChangeEvent<HTMLInputElement>, target: 'stem' | string) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      setUploadingTarget(target);
      setError(null);
      const uploaded = await adminQuizApi.uploadImage(file);
      if (target === 'stem') {
        setQuestionDraft((cur) => ({ ...cur, stemImageUrl: uploaded.url }));
      } else {
        setQuestionDraft((cur) => ({
          ...cur,
          options: cur.options.map((opt) => (opt.id === target ? { ...opt, imageUrl: uploaded.url } : opt)),
        }));
      }
      setNotice('图片上传成功');
    } catch (e) {
      setError(e instanceof Error ? e.message : '图片上传失败');
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
        dailyAttemptLimitOverride:
          draft.attemptMode === 'custom_limit' ? Number(draft.dailyAttemptLimitOverride || 0) : null,
        note: draft.note.trim() || null,
      });
      setNotice('用户次数覆盖已保存');
      await loadOverrides();
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存用户覆盖失败');
    } finally {
      setOverrideSavingUserId(null);
    }
  };

  const submitImportQuestions = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canWrite) return;
    try {
      setImportingQuestions(true);
      setError(null);
      setNotice(null);
      const parsed = JSON.parse(importText) as unknown;
      if (!Array.isArray(parsed)) throw new Error('导入内容必须是 JSON 数组');
      const result = await adminQuizApi.importQuestions({ questions: parsed as AdminQuizQuestionImportInput[] });
      setNotice(`成功导入 ${result.count} 道题目`);
      setShowImportPanel(false);
      setQuestionPage(1);
      await loadQuestions();
    } catch (e) {
      if (e instanceof SyntaxError) setError(`JSON 格式错误：${e.message}`);
      else setError(e instanceof Error ? e.message : '批量导入题目失败');
    } finally {
      setImportingQuestions(false);
    }
  };

  /* ── gate states ── */
  if (isLoading) {
    return (
      <AdminAppShell title="答题系统" description="加载答题系统配置中。">
        <div className="p-8 text-sm text-gray-400">加载中...</div>
      </AdminAppShell>
    );
  }
  if (!user || !canOperate) {
    return (
      <AdminAppShell title="答题系统" description="当前账号暂时不能访问答题系统后台。">
        <section className="mx-auto max-w-4xl">
          <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <h1 className="text-2xl font-semibold text-gray-900">答题系统</h1>
            <p className="mt-3 text-sm text-gray-500">当前账号无权限访问该页面。</p>
            <Link
              href={user ? '/admin' : '/login'}
              className="mt-5 inline-flex rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white"
            >
              {user ? '返回后台' : '去登录'}
            </Link>
          </div>
        </section>
      </AdminAppShell>
    );
  }

  /* ════════════════════════════════════════════
     RENDER
  ════════════════════════════════════════════ */
  return (
    <div className="flex min-h-screen flex-col bg-gray-50">
      {/* ── top header bar ── */}
      <div className="flex items-center justify-between border-b border-gray-200 bg-white px-6 py-4">
        <div>
          <h1 className="text-xl font-bold text-gray-900">答题系统</h1>
          <p className="mt-0.5 text-sm text-gray-500">围绕主线维护题库、全局配置与用户级答题次数覆盖。</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => { void loadConfig(); void loadQuestions(); void loadOverrides(); }}
            className="flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
          >
            <svg className="h-3.5 w-3.5" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M1 8a7 7 0 1 1 .6 2.8M1 8V3m0 5H6" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            刷新
          </button>
          {tab === 'questions' ? (
            <button
              type="button"
              onClick={() => {
                const form = document.getElementById('question-form') as HTMLFormElement | null;
                form?.requestSubmit();
              }}
              disabled={!canWrite || questionSaving}
              className="rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
            >
              {questionSaving ? '保存中...' : editorMode === 'edit' ? '保存题目' : '创建题目'}
            </button>
          ) : null}
          {tab === 'config' ? (
            <button
              type="button"
              onClick={() => {
                const form = document.getElementById('config-form') as HTMLFormElement | null;
                form?.requestSubmit();
              }}
              disabled={!canWrite || configSaving || configLoading}
              className="rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
            >
              {configSaving ? '保存中...' : '保存配置'}
            </button>
          ) : null}
        </div>
      </div>

      {/* ── tab bar ── */}
      <div className="flex items-center gap-1 border-b border-gray-200 bg-white px-6 pt-3">
        {([
          ['config', '配置'],
          ['questions', '题库'],
          ['overrides', '用户次数覆盖'],
        ] as Array<[TabKey, string]>).map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={`rounded-t-lg px-4 py-2 text-sm font-medium transition mb-[-1px] border-b-2 ${
              tab === key
                ? 'border-gray-900 text-gray-900'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* ── page body ── */}
      <div className="flex-1 overflow-auto p-6">
        {/* banners */}
        {error ? <Banner type="error" message={error} /> : null}
        {notice ? <div className="mb-4"><Banner type="notice" message={notice} /></div> : null}

        {/* ══ CONFIG TAB ══ */}
        {tab === 'config' ? (
          <div className="mx-auto max-w-3xl">
            <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div className="border-b border-gray-100 px-6 py-4">
                <div className="text-xs font-semibold uppercase tracking-widest text-gray-400">Quiz Config</div>
                <p className="mt-1 text-sm text-gray-500">控制答题系统的开关、抽题规模、通过标准和每日次数规则。</p>
              </div>
              <form id="config-form" onSubmit={submitConfig} className="p-6">
                <div className="grid gap-5 sm:grid-cols-2">
                  {/* toggles */}
                  <Field label="系统启用">
                    <label className="flex items-center gap-2.5 cursor-pointer">
                      <div
                        onClick={() => setConfigDraft((c) => ({ ...c, isEnabled: !c.isEnabled }))}
                        className={`relative h-5 w-9 rounded-full transition-colors ${
                          configDraft.isEnabled ? 'bg-gray-900' : 'bg-gray-300'
                        }`}
                      >
                        <span
                          className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${
                            configDraft.isEnabled ? 'translate-x-4' : 'translate-x-0.5'
                          }`}
                        />
                      </div>
                      <span className="text-sm text-gray-700">{configDraft.isEnabled ? '已启用' : '未启用'}</span>
                    </label>
                  </Field>

                  <Field label="通过后允许再次答题">
                    <label className="flex items-center gap-2.5 cursor-pointer">
                      <div
                        onClick={() => setConfigDraft((c) => ({ ...c, allowRetakeAfterPass: !c.allowRetakeAfterPass }))}
                        className={`relative h-5 w-9 rounded-full transition-colors ${
                          configDraft.allowRetakeAfterPass ? 'bg-gray-900' : 'bg-gray-300'
                        }`}
                      >
                        <span
                          className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${
                            configDraft.allowRetakeAfterPass ? 'translate-x-4' : 'translate-x-0.5'
                          }`}
                        />
                      </div>
                      <span className="text-sm text-gray-700">{configDraft.allowRetakeAfterPass ? '允许' : '不允许'}</span>
                    </label>
                  </Field>

                  <Field label="允许答题中重启">
                    <label className="flex items-center gap-2.5 cursor-pointer">
                      <div
                        onClick={() => setConfigDraft((c) => ({ ...c, allowRestartDuringSession: !c.allowRestartDuringSession }))}
                        className={`relative h-5 w-9 rounded-full transition-colors ${
                          configDraft.allowRestartDuringSession ? 'bg-gray-900' : 'bg-gray-300'
                        }`}
                      >
                        <span
                          className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${
                            configDraft.allowRestartDuringSession ? 'translate-x-4' : 'translate-x-0.5'
                          }`}
                        />
                      </div>
                      <span className="text-sm text-gray-700">{configDraft.allowRestartDuringSession ? '允许' : '不允许'}</span>
                    </label>
                  </Field>

                  {/* number fields */}
                  <Field label="答题数量">
                    <input
                      type="number"
                      value={String(configDraft.questionCount ?? '')}
                      onChange={(e) => setConfigDraft((c) => ({ ...c, questionCount: Number(e.target.value || 0) }))}
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="通过所需正确题数">
                    <input
                      type="number"
                      value={String(configDraft.passCorrectCount ?? '')}
                      onChange={(e) => setConfigDraft((c) => ({ ...c, passCorrectCount: Number(e.target.value || 0) }))}
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="默认每日次数">
                    <input
                      type="number"
                      value={String(configDraft.dailyAttemptLimit ?? '')}
                      onChange={(e) => setConfigDraft((c) => ({ ...c, dailyAttemptLimit: Number(e.target.value || 0) }))}
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="默认单题时长（秒）">
                    <input
                      type="number"
                      value={String(configDraft.defaultTimeLimitSec ?? '')}
                      onChange={(e) => setConfigDraft((c) => ({ ...c, defaultTimeLimitSec: Number(e.target.value || 0) }))}
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="日限额时区">
                    <input
                      value={String(configDraft.dailyLimitTimeZone ?? '')}
                      onChange={(e) => setConfigDraft((c) => ({ ...c, dailyLimitTimeZone: e.target.value }))}
                      className={inputCls()}
                    />
                  </Field>
                </div>

                <div className="mt-6 flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                  <span className="text-xs text-gray-400">
                    最后更新：{config ? formatTime(config.updatedAt) : configLoading ? '加载中...' : '-'}
                  </span>
                  <button
                    type="submit"
                    disabled={!canWrite || configSaving || configLoading}
                    className="rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                  >
                    {configSaving ? '保存中...' : '保存配置'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        ) : null}

        {/* ══ QUESTIONS TAB ══ */}
        {tab === 'questions' ? (
          <div className="grid gap-4 xl:grid-cols-[320px_minmax(0,1fr)_340px]">

            {/* ── col 1: question list ── */}
            <div className="flex flex-col gap-3">
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-widest text-gray-400">Question Library</div>
                    <p className="mt-0.5 text-xs text-gray-400">搜索、筛选题目并进入右侧编辑器。</p>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setEditorMode('create');
                      setSelectedQuestionId(null);
                      setQuestionDraft(createDefaultQuestionDraft());
                    }}
                    className="rounded-full bg-gray-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-gray-800 transition"
                  >
                    新建题目
                  </button>
                </div>

                <div className="p-3">
                  {/* import panel toggle */}
                  <button
                    type="button"
                    onClick={() => setShowImportPanel((c) => !c)}
                    className="mb-3 w-full rounded-lg border border-dashed border-gray-300 py-2 text-xs font-medium text-gray-500 hover:border-gray-400 hover:text-gray-700 transition"
                  >
                    {showImportPanel ? '收起批量导入' : '＋ 批量导入'}
                  </button>

                  {showImportPanel ? (
                    <form onSubmit={submitImportQuestions} className="mb-3 space-y-3 rounded-xl border border-gray-200 bg-gray-50 p-3">
                      <p className="text-xs text-gray-500 leading-5">
                        粘贴 JSON 数组，支持 correctOptionId / correctOptionIndex / options[].isCorrect 指定正确答案。
                      </p>
                      <textarea
                        value={importText}
                        onChange={(e) => setImportText(e.target.value)}
                        className="w-full rounded-lg border border-gray-200 bg-white px-2.5 py-2 font-mono text-[11px] leading-5 text-gray-800 outline-none min-h-[160px] resize-y focus:border-gray-900"
                        spellCheck={false}
                      />
                      <div className="flex items-center justify-between gap-2">
                        <button
                          type="button"
                          onClick={() => setImportText(QUIZ_IMPORT_EXAMPLE)}
                          className="text-xs text-gray-500 underline"
                        >
                          填入示例
                        </button>
                        <button
                          type="submit"
                          disabled={!canWrite || importingQuestions}
                          className="rounded-full bg-gray-900 px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
                        >
                          {importingQuestions ? '导入中...' : '开始导入'}
                        </button>
                      </div>
                    </form>
                  ) : null}

                  {/* search */}
                  <form
                    onSubmit={(e) => { e.preventDefault(); setQuestionPage(1); setQuestionQuery(questionQueryInput); }}
                    className="space-y-2"
                  >
                    <input
                      value={questionQueryInput}
                      onChange={(e) => setQuestionQueryInput(e.target.value)}
                      placeholder="搜索题干 / 难度 / id"
                      className={inputCls()}
                    />
                    <div className="flex gap-2">
                      <select
                        value={questionStatus}
                        onChange={(e) => { setQuestionStatus(e.target.value as QuizQuestionStatus | ''); setQuestionPage(1); }}
                        className={selectCls() + ' flex-1'}
                      >
                        <option value="">全部状态</option>
                        <option value="draft">draft</option>
                        <option value="active">active</option>
                        <option value="archived">archived</option>
                      </select>
                      <button
                        type="submit"
                        className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-50 transition"
                      >
                        搜索
                      </button>
                    </div>
                  </form>
                </div>

                {/* question cards */}
                <div className="divide-y divide-gray-100">
                  {questionLoading ? (
                    <div className="px-4 py-6 text-center text-xs text-gray-400">加载中...</div>
                  ) : questions.length === 0 ? (
                    <div className="px-4 py-6 text-center text-xs text-gray-400">暂无题目</div>
                  ) : (
                    questions.map((item) => {
                      const isSelected = selectedQuestionId === item.id;
                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => {
                            setSelectedQuestionId(item.id);
                            setEditorMode('edit');
                            setQuestionDraft(createDraftFromQuestion(item));
                          }}
                          className={`w-full px-4 py-3 text-left transition hover:bg-gray-50 ${
                            isSelected ? 'bg-emerald-50' : ''
                          }`}
                        >
                          <div className="flex items-start justify-between gap-2">
                            <div className="min-w-0 flex-1">
                              <div className="line-clamp-2 text-sm font-semibold text-gray-900">{item.stemText}</div>
                              <div className="mt-1.5 flex flex-wrap gap-1.5">
                                <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${statusBadgeClass(item.status)}`}>
                                  {item.status}
                                </span>
                                <span className="rounded-full border border-gray-200 bg-gray-50 px-2 py-0.5 text-[10px] text-gray-500">
                                  选项 {item.options.length}
                                </span>
                                <span className="rounded-full border border-gray-200 bg-gray-50 px-2 py-0.5 text-[10px] text-gray-500">
                                  限时 {item.timeLimitSec ?? '-'}
                                </span>
                              </div>
                              <div className="mt-1.5 truncate font-mono text-[10px] text-gray-400">{item.id}</div>
                            </div>
                            {isSelected ? (
                              <div className="mt-0.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-emerald-500">
                                <svg className="h-3 w-3 text-white" viewBox="0 0 12 12" fill="none">
                                  <path d="M2 6l3 3 5-5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                                </svg>
                              </div>
                            ) : (
                              <div className="mt-0.5 h-5 w-5 flex-shrink-0 rounded-full border-2 border-gray-200" />
                            )}
                          </div>
                        </button>
                      );
                    })
                  )}
                </div>

                {/* pagination */}
                <div className="flex items-center justify-between border-t border-gray-100 px-4 py-3 text-xs text-gray-500">
                  <span>
                    {questionPage} / {totalQuestionPages} · 共 {questionTotal} 条
                  </span>
                  <div className="flex gap-1">
                    <button
                      type="button"
                      disabled={questionPage <= 1}
                      onClick={() => setQuestionPage((p) => Math.max(1, p - 1))}
                      className="rounded border border-gray-200 px-2.5 py-1 disabled:opacity-40 hover:bg-gray-50"
                    >
                      ‹
                    </button>
                    <button
                      type="button"
                      disabled={questionPage >= totalQuestionPages}
                      onClick={() => setQuestionPage((p) => Math.min(totalQuestionPages, p + 1))}
                      className="rounded border border-gray-200 px-2.5 py-1 disabled:opacity-40 hover:bg-gray-50"
                    >
                      ›
                    </button>
                  </div>
                </div>
              </div>
            </div>

            {/* ── col 2: question editor ── */}
            <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
                <div>
                  <div className="text-xs font-semibold uppercase tracking-widest text-gray-400">
                    {editorMode === 'edit' ? 'Question Editor' : 'Create Question'}
                  </div>
                  <p className="mt-0.5 text-xs text-gray-400">当前版本只支持单选题。题干和选项都可以上传图片。</p>
                </div>
                {editorMode === 'edit' && selectedQuestionId ? (
                  <button
                    type="button"
                    onClick={archiveQuestion}
                    disabled={!canWrite || questionSaving}
                    className="rounded-full border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-100 transition disabled:opacity-50"
                  >
                    归档
                  </button>
                ) : null}
              </div>

              <form id="question-form" onSubmit={submitQuestion} className="p-5 space-y-5">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label="题目状态">
                    <select
                      value={questionDraft.status}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, status: e.target.value as QuizQuestionStatus }))}
                      className={selectCls()}
                    >
                      <option value="draft">draft</option>
                      <option value="active">active</option>
                      <option value="archived">archived</option>
                    </select>
                  </Field>

                  <Field label="正确答案 optionId" hint="必须对应某个选项 id">
                    <input
                      value={questionDraft.correctOptionId}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, correctOptionId: e.target.value }))}
                      placeholder="请填入某个选项 id"
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="单题时长（秒）">
                    <input
                      type="number"
                      value={questionDraft.timeLimitSec}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, timeLimitSec: e.target.value }))}
                      className={inputCls()}
                    />
                  </Field>

                  <Field label="排序值">
                    <input
                      type="number"
                      value={questionDraft.sortOrder}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, sortOrder: e.target.value }))}
                      className={inputCls()}
                    />
                  </Field>
                </div>

                <Field label="题干文本">
                  <textarea
                    value={questionDraft.stemText}
                    onChange={(e) => setQuestionDraft((c) => ({ ...c, stemText: e.target.value }))}
                    className={inputCls(true)}
                  />
                </Field>

                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label="题干图片 URL">
                    <div className="space-y-2">
                      <input
                        value={questionDraft.stemImageUrl}
                        onChange={(e) => setQuestionDraft((c) => ({ ...c, stemImageUrl: e.target.value }))}
                        placeholder="请输入图片 URL"
                        className={inputCls()}
                      />
                      <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-100 transition">
                        <input type="file" accept="image/*" className="hidden" onChange={(e) => void uploadImage(e, 'stem')} />
                        {uploadingTarget === 'stem' ? '上传中...' : '上传题干图片'}
                      </label>
                      {questionDraft.stemImageUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={questionDraft.stemImageUrl} alt="stem" className="h-16 w-16 rounded-lg object-cover border border-gray-200" />
                      ) : null}
                    </div>
                  </Field>

                  <Field label="标签" hint="逗号分隔">
                    <input
                      value={questionDraft.tags}
                      onChange={(e) => setQuestionDraft((c) => ({ ...c, tags: e.target.value }))}
                      className={inputCls()}
                    />
                  </Field>
                </div>

                <Field label="难度">
                  <select
                    value={questionDraft.difficulty}
                    onChange={(e) => setQuestionDraft((c) => ({ ...c, difficulty: e.target.value }))}
                    className={selectCls()}
                  >
                    <option value="">请选择难度</option>
                    <option value="easy">easy</option>
                    <option value="medium">medium</option>
                    <option value="hard">hard</option>
                  </select>
                </Field>

                <Field label="解释说明" hint="后台可维护，答题过程中不显示">
                  <textarea
                    value={questionDraft.explanation}
                    onChange={(e) => setQuestionDraft((c) => ({ ...c, explanation: e.target.value }))}
                    placeholder="请输入解释说明"
                    className={inputCls(true)}
                  />
                </Field>

                <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                  <span className="text-xs text-gray-400">
                    {editorMode === 'edit' && selectedQuestion
                      ? `最后更新：${formatTime(selectedQuestion.updatedAt)}`
                      : '新建题目后会自动进入编辑状态'}
                  </span>
                  <button
                    type="submit"
                    disabled={!canWrite || questionSaving}
                    className="rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                  >
                    {questionSaving ? '保存中...' : editorMode === 'edit' ? '保存题目' : '创建题目'}
                  </button>
                </div>
              </form>
            </div>

            {/* ── col 3: options + preview ── */}
            <div className="flex flex-col gap-4">
              {/* options panel */}
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                  <div>
                    <div className="text-sm font-semibold text-gray-900">选项列表</div>
                    <div className="mt-0.5 text-xs text-gray-400">至少 2 个，最多 6 个。每个选项可文字、图片或图文同时存在。</div>
                  </div>
                  <button
                    type="button"
                    disabled={questionDraft.options.length >= 6}
                    onClick={() =>
                      setQuestionDraft((c) => ({
                        ...c,
                        options: [...c.options, buildDraftOption(c.options.length)],
                      }))
                    }
                    className="rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-semibold text-gray-700 hover:bg-gray-100 transition disabled:opacity-50"
                  >
                    新增选项
                  </button>
                </div>

                <div className="divide-y divide-gray-100">
                  {questionDraft.options.map((option, index) => {
                    const isCorrect = questionDraft.correctOptionId === option.id;
                    const letter = OPTION_LETTERS[index] || String(index + 1);
                    return (
                      <div key={option.id} className="p-4 space-y-3">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div
                              className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                                isCorrect
                                  ? 'bg-emerald-500 text-white'
                                  : 'border-2 border-gray-300 text-gray-500'
                              }`}
                            >
                              {letter}
                            </div>
                            <span className="font-mono text-[10px] text-gray-400 truncate max-w-[180px]">{option.id}</span>
                          </div>
                          <button
                            type="button"
                            disabled={questionDraft.options.length <= 2}
                            onClick={() =>
                              setQuestionDraft((c) => {
                                const nextOptions = c.options.filter((o) => o.id !== option.id);
                                const nextCorrect =
                                  c.correctOptionId === option.id
                                    ? nextOptions[0]?.id || ''
                                    : c.correctOptionId;
                                return {
                                  ...c,
                                  correctOptionId: nextCorrect,
                                  options: nextOptions.map((o, i) => ({ ...o, sortOrder: i })),
                                };
                              })
                            }
                            className="text-xs font-medium text-red-500 hover:text-red-700 disabled:opacity-40"
                          >
                            删除
                          </button>
                        </div>

                        <div className="grid gap-2">
                          <Field label="选项文本">
                            <input
                              value={option.text}
                              onChange={(e) =>
                                setQuestionDraft((c) => ({
                                  ...c,
                                  options: c.options.map((o) =>
                                    o.id === option.id ? { ...o, text: e.target.value } : o
                                  ),
                                }))
                              }
                              className={inputCls()}
                            />
                          </Field>

                          <Field label="选项图片 URL">
                            <div className="space-y-1.5">
                              <input
                                value={option.imageUrl}
                                onChange={(e) =>
                                  setQuestionDraft((c) => ({
                                    ...c,
                                    options: c.options.map((o) =>
                                      o.id === option.id ? { ...o, imageUrl: e.target.value } : o
                                    ),
                                  }))
                                }
                                placeholder="请输入图片 URL"
                                className={inputCls()}
                              />
                              <div className="flex items-center gap-2">
                                <label
                                  className={`inline-flex cursor-pointer items-center rounded-lg border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-100 transition ${
                                    isCorrect ? '' : 'opacity-70'
                                  }`}
                                >
                                  <input
                                    type="file"
                                    accept="image/*"
                                    className="hidden"
                                    onChange={(e) => void uploadImage(e, option.id)}
                                  />
                                  {uploadingTarget === option.id ? '上传中...' : '上传选项图片'}
                                </label>
                                {option.imageUrl ? (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img
                                    src={option.imageUrl}
                                    alt={option.text || option.id}
                                    className="h-10 w-10 rounded-lg object-cover border border-gray-200"
                                  />
                                ) : null}
                              </div>
                            </div>
                          </Field>
                        </div>

                        <label className="flex cursor-pointer items-center gap-2">
                          <div
                            className={`h-4 w-4 rounded-full border-2 flex items-center justify-center ${
                              isCorrect ? 'border-emerald-500 bg-emerald-500' : 'border-gray-300'
                            }`}
                            onClick={() => setQuestionDraft((c) => ({ ...c, correctOptionId: option.id }))}
                          >
                            {isCorrect ? <div className="h-1.5 w-1.5 rounded-full bg-white" /> : null}
                          </div>
                          <span className="text-xs text-gray-500">设为正确答案</span>
                        </label>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* preview panel */}
              <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
                <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
                  <div>
                    <div className="text-sm font-semibold text-gray-900">题目预览</div>
                    <div className="mt-0.5 text-xs text-gray-400">按当前草稿实时预览最终答题展示结构。</div>
                  </div>
                  <span className="rounded-full border border-gray-200 bg-gray-50 px-2.5 py-1 text-[10px] text-gray-500">
                    单选题 · {questionDraft.options.length} 个选项
                  </span>
                </div>

                <div className="p-4 space-y-3">
                  <div className="text-sm font-semibold leading-6 text-gray-900">
                    {questionDraft.stemText.trim() || '题干预览将在这里显示'}
                  </div>

                  {questionDraft.stemImageUrl.trim() ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={questionDraft.stemImageUrl.trim()}
                      alt="题干预览"
                      className="w-full max-h-48 rounded-xl object-contain border border-gray-100 bg-gray-50"
                    />
                  ) : null}

                  <div className="space-y-2">
                    {questionDraft.options.map((option, index) => {
                      const letter = OPTION_LETTERS[index] || String(index + 1);
                      return (
                        <div
                          key={`preview-${option.id}`}
                          className="flex items-center gap-3 rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5"
                        >
                          <div className="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full border border-gray-300 bg-white text-xs font-bold text-gray-600">
                            {letter}
                          </div>
                          <span className="text-sm text-gray-700">
                            {previewOptionLabel(option.text, option.imageUrl)}
                          </span>
                          {option.imageUrl.trim() ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={option.imageUrl.trim()}
                              alt={previewOptionLabel(option.text, option.imageUrl)}
                              className="ml-auto h-10 w-10 rounded-lg object-cover border border-gray-200"
                            />
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : null}

        {/* ══ OVERRIDES TAB ══ */}
        {tab === 'overrides' ? (
          <div className="mx-auto max-w-5xl">
            <div className="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div className="border-b border-gray-100 px-6 py-4">
                <div className="text-xs font-semibold uppercase tracking-widest text-gray-400">User Attempt Overrides</div>
                <p className="mt-1 text-sm text-gray-500">
                  按用户设置 quiz 次数策略。<code className="rounded bg-gray-100 px-1 text-xs">default</code> 继承全局默认；
                  <code className="rounded bg-gray-100 px-1 text-xs">custom_limit</code> 使用专属次数；
                  <code className="rounded bg-gray-100 px-1 text-xs">unlimited</code> 供官方测试或特殊用户使用。
                </p>
              </div>

              <div className="p-5">
                <form
                  onSubmit={(e) => { e.preventDefault(); setOverridePage(1); setOverrideQuery(overrideQueryInput); }}
                  className="flex gap-2"
                >
                  <input
                    value={overrideQueryInput}
                    onChange={(e) => setOverrideQueryInput(e.target.value)}
                    placeholder="搜索邮箱 / 用户名 / displayName / userId"
                    className={inputCls() + ' flex-1'}
                  />
                  <button
                    type="submit"
                    className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100 transition"
                  >
                    搜索
                  </button>
                </form>
              </div>

              <div className="divide-y divide-gray-100">
                {overrideLoading ? (
                  <div className="px-6 py-8 text-center text-sm text-gray-400">加载用户覆盖中...</div>
                ) : overrides.length === 0 ? (
                  <div className="px-6 py-8 text-center text-sm text-gray-400">暂无用户覆盖数据</div>
                ) : (
                  overrides.map((item) => {
                    const draft = overrideDrafts[item.userId] || {
                      attemptMode: item.attemptMode,
                      dailyAttemptLimitOverride: item.dailyAttemptLimitOverride ? String(item.dailyAttemptLimitOverride) : '',
                      note: item.note || '',
                    };
                    return (
                      <div key={item.id} className="px-5 py-4">
                        <div className="flex flex-col gap-4 lg:flex-row lg:items-center">
                          {/* user info */}
                          <div className="min-w-[200px]">
                            <div className="text-sm font-semibold text-gray-900">
                              {item.user.displayName || item.user.username}
                            </div>
                            <div className="text-sm text-gray-500">{item.user.email}</div>
                            <div className="mt-0.5 font-mono text-[10px] text-gray-400">{item.userId}</div>
                            <div className="mt-1 text-xs text-gray-400">更新：{formatTime(item.updatedAt)}</div>
                          </div>

                          {/* controls */}
                          <div className="flex flex-1 flex-wrap items-center gap-2">
                            <select
                              value={draft.attemptMode}
                              onChange={(e) =>
                                setOverrideDrafts((c) => ({
                                  ...c,
                                  [item.userId]: { ...draft, attemptMode: e.target.value as QuizAttemptMode },
                                }))
                              }
                              className={selectCls() + ' max-w-[160px]'}
                            >
                              <option value="default">default</option>
                              <option value="custom_limit">custom_limit</option>
                              <option value="unlimited">unlimited</option>
                            </select>

                            <input
                              value={draft.dailyAttemptLimitOverride}
                              disabled={draft.attemptMode !== 'custom_limit'}
                              onChange={(e) =>
                                setOverrideDrafts((c) => ({
                                  ...c,
                                  [item.userId]: { ...draft, dailyAttemptLimitOverride: e.target.value },
                                }))
                              }
                              placeholder="专属次数"
                              className={inputCls() + ' max-w-[120px]'}
                            />

                            <input
                              value={draft.note}
                              onChange={(e) =>
                                setOverrideDrafts((c) => ({
                                  ...c,
                                  [item.userId]: { ...draft, note: e.target.value },
                                }))
                              }
                              placeholder="备注，例如官方测试 / 白名单"
                              className={inputCls() + ' flex-1 min-w-[180px]'}
                            />

                            <button
                              type="button"
                              onClick={() => void saveOverride(item.userId)}
                              disabled={!canWrite || overrideSavingUserId === item.userId}
                              className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-gray-800 transition"
                            >
                              {overrideSavingUserId === item.userId ? '保存中...' : '保存'}
                            </button>
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {/* pagination */}
              <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3 text-sm text-gray-500">
                <span>
                  第 {overridePage} / {totalOverridePages} 页，共 {overrideTotal} 条
                </span>
                <div className="flex gap-1.5">
                  <button
                    type="button"
                    disabled={overridePage <= 1}
                    onClick={() => setOverridePage((p) => Math.max(1, p - 1))}
                    className="rounded-full border border-gray-200 px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-40"
                  >
                    上一页
                  </button>
                  <button
                    type="button"
                    disabled={overridePage >= totalOverridePages}
                    onClick={() => setOverridePage((p) => Math.min(totalOverridePages, p + 1))}
                    className="rounded-full border border-gray-200 px-3 py-1.5 text-xs hover:bg-gray-50 disabled:opacity-40"
                  >
                    下一页
                  </button>
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
