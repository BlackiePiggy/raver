'use client';

import Image from 'next/image';
import { ChangeEvent, useEffect, useMemo, useState } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';
import OverlayImageViewer, { type OverlayImageViewerAsset } from '@/components/admin/OverlayImageViewer';
import useOverlayBodyLock from '@/hooks/useOverlayBodyLock';
import { useAuth } from '@/contexts/AuthContext';
import { getAdminCmsRolePolicy } from '@/lib/admin/role-policy';
import {
  adminPersonalityApi,
  type AdminPersonalityConfig,
  type AdminPersonalityQuestion,
  type AdminPersonalityQuestionInput,
  type AdminPersonalityResultType,
  type AdminPersonalityResultTypeInput,
  type PersonalityQuestionStatus,
} from '@/lib/api/admin-personality';

type TabKey = 'config' | 'results' | 'questions' | 'debug_set';
type EditorMode = 'create' | 'edit';

type ResultDraft = {
  code: string;
  title: string;
  subtitle: string;
  slangTagline: string;
  genreMapping: string;
  description: string;
  imageUrl: string;
  sortOrder: string;
  isActive: boolean;
  isHidden: boolean;
  mbtiCode: string;
};

type QuestionDraftOption = {
  id: string;
  text: string;
  imageUrl: string;
  scoreAxis: string;
  scoreValue: string;
  directResultCode: string;
};

type QuestionDraft = {
  status: PersonalityQuestionStatus;
  stemText: string;
  stemImageUrl: string;
  isEasterEgg: boolean;
  options: QuestionDraftOption[];
};

const emptyResultDraft = (): ResultDraft => ({
  code: '',
  title: '',
  subtitle: '',
  slangTagline: '',
  genreMapping: '',
  description: '',
  imageUrl: '',
  sortOrder: '0',
  isActive: true,
  isHidden: false,
  mbtiCode: '',
});

const createEmptyQuestionOption = (index: number): QuestionDraftOption => ({
  id: `option_${index + 1}`,
  text: '',
  imageUrl: '',
  scoreAxis: '',
  scoreValue: '1',
  directResultCode: '',
});

const emptyQuestionDraft = (): QuestionDraft => ({
  status: 'draft',
  stemText: '',
  stemImageUrl: '',
  isEasterEgg: false,
  options: [createEmptyQuestionOption(0), createEmptyQuestionOption(1), createEmptyQuestionOption(2), createEmptyQuestionOption(3)],
});

const buildResultDraft = (item: AdminPersonalityResultType | null): ResultDraft =>
  item
    ? {
        code: item.code,
        title: item.title,
        subtitle: item.subtitle ?? '',
        slangTagline: item.slangTagline ?? '',
        genreMapping: item.genreMapping ?? '',
        description: item.description,
        imageUrl: item.imageUrl ?? '',
        sortOrder: String(item.sortOrder ?? 0),
        isActive: item.isActive,
        isHidden: item.isHidden,
        mbtiCode: item.mbtiCode ?? '',
      }
    : emptyResultDraft();

const buildQuestionDraft = (item: AdminPersonalityQuestion | null): QuestionDraft =>
  item
    ? {
        status: item.status,
        stemText: item.stemText,
        stemImageUrl: item.stemImageUrl ?? '',
        isEasterEgg: item.isEasterEgg,
        options: item.options.map((option, index) => ({
          id: option.id || `option_${index + 1}`,
          text: option.text ?? '',
          imageUrl: option.imageUrl ?? '',
          scoreAxis: Object.keys(option.scorePayload || {})[0] ?? '',
          scoreValue: String(Object.values(option.scorePayload || {})[0] ?? 1),
          directResultCode: option.directResultCode ?? '',
        })),
      }
    : emptyQuestionDraft();

export default function AdminPersonalityPage() {
  const { user } = useAuth();
  const policy = useMemo(() => getAdminCmsRolePolicy(user), [user]);
  const canRead = policy.canAccessOperations;
  const canWrite = policy.role === 'admin';

  const [tab, setTab] = useState<TabKey>('config');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [config, setConfig] = useState<AdminPersonalityConfig | null>(null);
  const [configDraft, setConfigDraft] = useState<AdminPersonalityConfig | null>(null);

  const [resultTypes, setResultTypes] = useState<AdminPersonalityResultType[]>([]);
  const [selectedResultTypeId, setSelectedResultTypeId] = useState<string | null>(null);
  const [resultEditorMode, setResultEditorMode] = useState<EditorMode>('create');
  const [resultDraft, setResultDraft] = useState<ResultDraft>(emptyResultDraft());

  const [questions, setQuestions] = useState<AdminPersonalityQuestion[]>([]);
  const [selectedQuestionId, setSelectedQuestionId] = useState<string | null>(null);
  const [questionEditorMode, setQuestionEditorMode] = useState<EditorMode>('create');
  const [questionDraft, setQuestionDraft] = useState<QuestionDraft>(emptyQuestionDraft());

  const [debugSetQuestionIds, setDebugSetQuestionIds] = useState<string[]>([]);
  const [overlayAssets, setOverlayAssets] = useState<OverlayImageViewerAsset[]>([]);
  const [overlayIndex, setOverlayIndex] = useState<number | null>(null);

  useOverlayBodyLock(overlayIndex !== null);

  const selectedResult = resultTypes.find((item) => item.id === selectedResultTypeId) ?? null;
  const selectedQuestion = questions.find((item) => item.id === selectedQuestionId) ?? null;

  const loadAll = async () => {
    setLoading(true);
    setError(null);
    try {
      const [configResult, resultTypesResult, questionsResult, debugSetResult] = await Promise.all([
        adminPersonalityApi.getConfig(),
        adminPersonalityApi.listResultTypes(),
        adminPersonalityApi.listQuestions({ page: 1, limit: 200 }),
        adminPersonalityApi.getDebugSet(),
      ]);
      setConfig(configResult.config);
      setConfigDraft(configResult.config);
      setResultTypes(resultTypesResult.items);
      setQuestions(questionsResult.items);
      setDebugSetQuestionIds(debugSetResult.questionIds);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : '加载 EDMTI 后台失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!canRead) return;
    void loadAll();
  }, [canRead]);

  useEffect(() => {
    if (resultEditorMode === 'edit' && selectedResult) {
      setResultDraft(buildResultDraft(selectedResult));
    } else if (resultEditorMode === 'create') {
      setResultDraft(emptyResultDraft());
    }
  }, [resultEditorMode, selectedResult]);

  useEffect(() => {
    if (questionEditorMode === 'edit' && selectedQuestion) {
      setQuestionDraft(buildQuestionDraft(selectedQuestion));
    } else if (questionEditorMode === 'create') {
      setQuestionDraft(emptyQuestionDraft());
    }
  }, [questionEditorMode, selectedQuestion]);

  const openViewer = (url: string) => {
    const trimmed = url.trim();
    if (!trimmed) return;
    setOverlayAssets([{ url: trimmed, alt: 'preview' }]);
    setOverlayIndex(0);
  };

  const handleConfigSave = async () => {
    if (!configDraft) return;
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const result = await adminPersonalityApi.updateConfig({
        isEnabled: configDraft.isEnabled,
        questionCount: configDraft.questionCount,
        axisThreshold: configDraft.axisThreshold,
        resultTypeCapacity: configDraft.resultTypeCapacity,
        standardQuestionIds: configDraft.standardQuestionIds,
        debugQuestionIds: configDraft.debugQuestionIds,
        easterEggQuestionId: configDraft.easterEggQuestionId,
        hiddenResultPriority: configDraft.hiddenResultPriority,
      });
      setConfig(result.config);
      setConfigDraft(result.config);
      setNotice('EDMTI 配置已保存');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存配置失败');
    } finally {
      setSaving(false);
    }
  };

  const handleResultSave = async () => {
    setSaving(true);
    setError(null);
    setNotice(null);
    const payload: AdminPersonalityResultTypeInput = {
      code: resultDraft.code,
      title: resultDraft.title,
      subtitle: resultDraft.subtitle || null,
      slangTagline: resultDraft.slangTagline || null,
      genreMapping: resultDraft.genreMapping || null,
      description: resultDraft.description,
      imageUrl: resultDraft.imageUrl || null,
      sortOrder: Number(resultDraft.sortOrder) || 0,
      isActive: resultDraft.isActive,
      isHidden: resultDraft.isHidden,
      mbtiCode: resultDraft.mbtiCode || null,
    };
    try {
      const result =
        resultEditorMode === 'edit' && selectedResultTypeId
          ? await adminPersonalityApi.updateResultType(selectedResultTypeId, payload)
          : await adminPersonalityApi.createResultType(payload);
      await loadAll();
      setSelectedResultTypeId(result.item.id);
      setResultEditorMode('edit');
      setNotice('人格结果已保存');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存人格结果失败');
    } finally {
      setSaving(false);
    }
  };

  const handleQuestionSave = async () => {
    setSaving(true);
    setError(null);
    setNotice(null);
    const payload: AdminPersonalityQuestionInput = {
      status: questionDraft.status,
      stemText: questionDraft.stemText,
      stemImageUrl: questionDraft.stemImageUrl || null,
      isEasterEgg: questionDraft.isEasterEgg,
      options: questionDraft.options.map((option, index) => ({
        id: option.id,
        text: option.text || null,
        imageUrl: option.imageUrl || null,
        sortOrder: index,
        scoreAxis: option.scoreAxis || null,
        scoreValue: Number(option.scoreValue) || 1,
        directResultCode: option.directResultCode || null,
      })),
    };
    try {
      const result =
        questionEditorMode === 'edit' && selectedQuestionId
          ? await adminPersonalityApi.updateQuestion(selectedQuestionId, payload)
          : await adminPersonalityApi.createQuestion(payload);
      await loadAll();
      setSelectedQuestionId(result.item.id);
      setQuestionEditorMode('edit');
      setNotice('题目已保存');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存题目失败');
    } finally {
      setSaving(false);
    }
  };

  const handleArchiveQuestion = async () => {
    if (!selectedQuestionId) return;
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await adminPersonalityApi.archiveQuestion(selectedQuestionId);
      await loadAll();
      setNotice('题目已归档');
    } catch (archiveError) {
      setError(archiveError instanceof Error ? archiveError.message : '归档题目失败');
    } finally {
      setSaving(false);
    }
  };

  const handleDebugSetSave = async () => {
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      const result = await adminPersonalityApi.updateDebugSet(debugSetQuestionIds);
      setDebugSetQuestionIds(result.questionIds);
      setNotice('调试套题已保存');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存调试套题失败');
    } finally {
      setSaving(false);
    }
  };

  const handleUploadImage = async (
    event: ChangeEvent<HTMLInputElement>,
    apply: (url: string) => void
  ) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    setSaving(true);
    setError(null);
    try {
      const uploaded = await adminPersonalityApi.uploadImage(file);
      apply(uploaded.url);
      setNotice(
        uploaded.compression.compressed
          ? `图片已上传，体积 ${Math.round(uploaded.compression.originalBytes / 1024)}KB -> ${Math.round(uploaded.compression.uploadedBytes / 1024)}KB`
          : '图片已上传'
      );
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : '图片上传失败');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <AdminAppShell title="EDMTI 人格" description="正在加载 EDMTI 后台配置…">
        <div />
      </AdminAppShell>
    );
  }

  if (!canRead) {
    return (
      <AdminAppShell title="EDMTI 人格" description="当前账号暂时不能访问 EDMTI 后台。">
        <div />
      </AdminAppShell>
    );
  }

  return (
    <AdminAppShell title="EDMTI 人格" description="维护人格结果、题目配置与调试套题。" hidePageHeader>
      <div className="space-y-6">
        <div className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
          <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
            <div>
              <h1 className="text-xl font-bold text-gray-900">EDMTI 人格</h1>
              <p className="mt-1 text-sm text-gray-500">围绕主线维护人格结果、题库与调试模式。</p>
            </div>
            <div className="flex flex-wrap gap-2">
              {([
                ['config', '全局配置'],
                ['results', '人格结果'],
                ['questions', '题目管理'],
                ['debug_set', '调试套题'],
              ] as Array<[TabKey, string]>).map(([key, label]) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => setTab(key)}
                  className={`rounded-full px-4 py-2 text-sm font-medium transition ${
                    tab === key ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        </div>

        {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{notice}</div> : null}
        {error ? <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div> : null}

        {tab === 'config' && configDraft ? (
          <div className="grid gap-6 lg:grid-cols-2">
            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-semibold text-gray-900">全局配置</h2>
              <div className="mt-5 space-y-4">
                <label className="flex items-center gap-3 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={configDraft.isEnabled}
                    onChange={(event) => setConfigDraft({ ...configDraft, isEnabled: event.target.checked })}
                    disabled={!canWrite || saving}
                  />
                  启用 EDMTI 正式测试
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">正式题目数</span>
                  <input
                    type="number"
                    value={configDraft.questionCount}
                    onChange={(event) => setConfigDraft({ ...configDraft, questionCount: Number(event.target.value) || 16 })}
                    className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                    disabled={!canWrite || saving}
                  />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">维度阈值</span>
                  <input
                    type="number"
                    value={configDraft.axisThreshold}
                    onChange={(event) => setConfigDraft({ ...configDraft, axisThreshold: Number(event.target.value) || 9 })}
                    className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                    disabled={!canWrite || saving}
                  />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">人格容量预留</span>
                  <input
                    type="number"
                    value={configDraft.resultTypeCapacity}
                    onChange={(event) =>
                      setConfigDraft({ ...configDraft, resultTypeCapacity: Number(event.target.value) || 32 })
                    }
                    className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                    disabled={!canWrite || saving}
                  />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">隐藏人格优先级（逗号分隔）</span>
                  <input
                    type="text"
                    value={configDraft.hiddenResultPriority.join(', ')}
                    onChange={(event) =>
                      setConfigDraft({
                        ...configDraft,
                        hiddenResultPriority: event.target.value
                          .split(',')
                          .map((value) => value.trim())
                          .filter(Boolean),
                      })
                    }
                    className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                    disabled={!canWrite || saving}
                  />
                </label>
                <button
                  type="button"
                  onClick={handleConfigSave}
                  disabled={!canWrite || saving}
                  className="rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
                >
                  {saving ? '保存中…' : '保存配置'}
                </button>
              </div>
            </section>

            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-semibold text-gray-900">题目集合</h2>
              <div className="mt-5 space-y-4 text-sm text-gray-700">
                <label className="block">
                  <span className="mb-1 block">正式题目 IDs（逗号分隔，留空则从 active 题里随机抽）</span>
                  <textarea
                    value={configDraft.standardQuestionIds.join(', ')}
                    onChange={(event) =>
                      setConfigDraft({
                        ...configDraft,
                        standardQuestionIds: event.target.value
                          .split(',')
                          .map((value) => value.trim())
                          .filter(Boolean),
                      })
                    }
                    className="min-h-[120px] w-full rounded-2xl border border-gray-200 px-4 py-3"
                    disabled={!canWrite || saving}
                  />
                </label>
                <label className="block">
                  <span className="mb-1 block">彩蛋题 questionId</span>
                  <input
                    type="text"
                    value={configDraft.easterEggQuestionId ?? ''}
                    onChange={(event) =>
                      setConfigDraft({
                        ...configDraft,
                        easterEggQuestionId: event.target.value.trim() || null,
                      })
                    }
                    className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                    disabled={!canWrite || saving}
                  />
                </label>
              </div>
            </section>
          </div>
        ) : null}

        {tab === 'results' ? (
          <div className="grid gap-6 lg:grid-cols-[320px,minmax(0,1fr)]">
            <section className="rounded-3xl border border-gray-200 bg-white p-5 shadow-sm">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-gray-900">人格结果</h2>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedResultTypeId(null);
                    setResultEditorMode('create');
                  }}
                  className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700"
                >
                  新建
                </button>
              </div>
              <div className="mt-4 space-y-2">
                {resultTypes.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      setSelectedResultTypeId(item.id);
                      setResultEditorMode('edit');
                    }}
                    className={`w-full rounded-2xl border px-4 py-3 text-left transition ${
                      selectedResultTypeId === item.id ? 'border-gray-900 bg-gray-900 text-white' : 'border-gray-200 bg-white text-gray-800'
                    }`}
                  >
                    <div className="text-sm font-semibold">{item.code} · {item.title}</div>
                    <div className={`mt-1 text-xs ${selectedResultTypeId === item.id ? 'text-white/80' : 'text-gray-500'}`}>
                      {item.isHidden ? '隐藏人格' : item.mbtiCode || '常规人格'}
                    </div>
                  </button>
                ))}
              </div>
            </section>

            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-semibold text-gray-900">{resultEditorMode === 'edit' ? '编辑人格结果' : '新建人格结果'}</h2>
              <div className="mt-5 grid gap-4 md:grid-cols-2">
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">Code</span>
                  <input value={resultDraft.code} onChange={(e) => setResultDraft({ ...resultDraft, code: e.target.value })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving || resultEditorMode === 'edit'} />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">名称</span>
                  <input value={resultDraft.title} onChange={(e) => setResultDraft({ ...resultDraft, title: e.target.value })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving} />
                </label>
                <label className="block text-sm text-gray-700 md:col-span-2">
                  <span className="mb-1 block">副标题 / 黑话标签</span>
                  <input value={resultDraft.slangTagline} onChange={(e) => setResultDraft({ ...resultDraft, slangTagline: e.target.value })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving} />
                </label>
                <label className="block text-sm text-gray-700 md:col-span-2">
                  <span className="mb-1 block">曲风对标</span>
                  <textarea value={resultDraft.genreMapping} onChange={(e) => setResultDraft({ ...resultDraft, genreMapping: e.target.value })} className="min-h-[110px] w-full rounded-2xl border border-gray-200 px-4 py-3" disabled={!canWrite || saving} />
                </label>
                <label className="block text-sm text-gray-700 md:col-span-2">
                  <span className="mb-1 block">人设解读</span>
                  <textarea value={resultDraft.description} onChange={(e) => setResultDraft({ ...resultDraft, description: e.target.value })} className="min-h-[180px] w-full rounded-2xl border border-gray-200 px-4 py-3" disabled={!canWrite || saving} />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">MBTI Code</span>
                  <input value={resultDraft.mbtiCode} onChange={(e) => setResultDraft({ ...resultDraft, mbtiCode: e.target.value })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving} />
                </label>
                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">排序值</span>
                  <input type="number" value={resultDraft.sortOrder} onChange={(e) => setResultDraft({ ...resultDraft, sortOrder: e.target.value })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving} />
                </label>
                <div className="md:col-span-2 rounded-2xl border border-dashed border-gray-200 p-4">
                  <div className="flex flex-wrap items-center gap-3">
                    {resultDraft.imageUrl ? (
                      <button type="button" onClick={() => openViewer(resultDraft.imageUrl)} className="relative h-16 w-16 overflow-hidden rounded-2xl border border-gray-200">
                        <Image src={resultDraft.imageUrl} alt="result preview" fill className="object-cover" unoptimized />
                      </button>
                    ) : (
                      <div className="flex h-16 w-16 items-center justify-center rounded-2xl border border-dashed border-gray-200 text-xs text-gray-400">暂无图</div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-xs text-gray-400">{resultDraft.imageUrl || '未上传图片'}</p>
                      <div className="mt-2 flex gap-2">
                        <label className="inline-flex cursor-pointer rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700">
                          上传图片
                          <input type="file" accept="image/*" className="hidden" onChange={(event) => void handleUploadImage(event, (url) => setResultDraft({ ...resultDraft, imageUrl: url }))} />
                        </label>
                        {resultDraft.imageUrl ? (
                          <button type="button" onClick={() => setResultDraft({ ...resultDraft, imageUrl: '' })} className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700">
                            清空
                          </button>
                        ) : null}
                      </div>
                    </div>
                  </div>
                </div>
                <label className="flex items-center gap-3 text-sm text-gray-700">
                  <input type="checkbox" checked={resultDraft.isActive} onChange={(e) => setResultDraft({ ...resultDraft, isActive: e.target.checked })} disabled={!canWrite || saving} />
                  启用
                </label>
                <label className="flex items-center gap-3 text-sm text-gray-700">
                  <input type="checkbox" checked={resultDraft.isHidden} onChange={(e) => setResultDraft({ ...resultDraft, isHidden: e.target.checked })} disabled={!canWrite || saving} />
                  隐藏人格
                </label>
              </div>
              <div className="mt-6">
                <button type="button" onClick={handleResultSave} disabled={!canWrite || saving} className="rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
                  {saving ? '保存中…' : '保存人格结果'}
                </button>
              </div>
            </section>
          </div>
        ) : null}

        {tab === 'questions' ? (
          <div className="grid gap-6 lg:grid-cols-[340px,minmax(0,1fr)]">
            <section className="rounded-3xl border border-gray-200 bg-white p-5 shadow-sm">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-gray-900">题目列表</h2>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedQuestionId(null);
                    setQuestionEditorMode('create');
                  }}
                  className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700"
                >
                  新建
                </button>
              </div>
              <div className="mt-4 space-y-2">
                {questions.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      setSelectedQuestionId(item.id);
                      setQuestionEditorMode('edit');
                    }}
                    className={`w-full rounded-2xl border px-4 py-3 text-left transition ${
                      selectedQuestionId === item.id ? 'border-gray-900 bg-gray-900 text-white' : 'border-gray-200 bg-white text-gray-800'
                    }`}
                  >
                    <div className="line-clamp-2 text-sm font-semibold">{item.stemText}</div>
                    <div className={`mt-1 text-xs ${selectedQuestionId === item.id ? 'text-white/80' : 'text-gray-500'}`}>
                      {item.isEasterEgg ? '彩蛋题' : item.status}
                    </div>
                  </button>
                ))}
              </div>
            </section>

            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-gray-900">{questionEditorMode === 'edit' ? '编辑题目' : '新建题目'}</h2>
                  <p className="mt-1 text-sm text-gray-500">每个选项要么配置一个维度加分，要么配置一个直接触发的人格结果 code。</p>
                </div>
                {questionEditorMode === 'edit' && selectedQuestionId ? (
                  <button type="button" onClick={handleArchiveQuestion} disabled={!canWrite || saving} className="rounded-full border border-red-200 px-4 py-2 text-sm font-medium text-red-600 disabled:opacity-50">
                    归档题目
                  </button>
                ) : null}
              </div>

              <div className="mt-5 space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="block text-sm text-gray-700">
                    <span className="mb-1 block">状态</span>
                    <select value={questionDraft.status} onChange={(e) => setQuestionDraft({ ...questionDraft, status: e.target.value as PersonalityQuestionStatus })} className="w-full rounded-2xl border border-gray-200 px-4 py-2.5" disabled={!canWrite || saving}>
                      <option value="draft">draft</option>
                      <option value="active">active</option>
                      <option value="archived">archived</option>
                    </select>
                  </label>
                  <label className="flex items-center gap-3 pt-7 text-sm text-gray-700">
                    <input type="checkbox" checked={questionDraft.isEasterEgg} onChange={(e) => setQuestionDraft({ ...questionDraft, isEasterEgg: e.target.checked })} disabled={!canWrite || saving} />
                    设为彩蛋题
                  </label>
                </div>

                <label className="block text-sm text-gray-700">
                  <span className="mb-1 block">题干</span>
                  <textarea value={questionDraft.stemText} onChange={(e) => setQuestionDraft({ ...questionDraft, stemText: e.target.value })} className="min-h-[120px] w-full rounded-2xl border border-gray-200 px-4 py-3" disabled={!canWrite || saving} />
                </label>

                <div className="rounded-2xl border border-dashed border-gray-200 p-4">
                  <div className="flex flex-wrap items-center gap-3">
                    {questionDraft.stemImageUrl ? (
                      <button type="button" onClick={() => openViewer(questionDraft.stemImageUrl)} className="relative h-16 w-16 overflow-hidden rounded-2xl border border-gray-200">
                        <Image src={questionDraft.stemImageUrl} alt="stem preview" fill className="object-cover" unoptimized />
                      </button>
                    ) : (
                      <div className="flex h-16 w-16 items-center justify-center rounded-2xl border border-dashed border-gray-200 text-xs text-gray-400">暂无图</div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-xs text-gray-400">{questionDraft.stemImageUrl || '未上传题干图'}</p>
                      <div className="mt-2 flex gap-2">
                        <label className="inline-flex cursor-pointer rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700">
                          上传题干图
                          <input type="file" accept="image/*" className="hidden" onChange={(event) => void handleUploadImage(event, (url) => setQuestionDraft({ ...questionDraft, stemImageUrl: url }))} />
                        </label>
                        {questionDraft.stemImageUrl ? (
                          <button type="button" onClick={() => setQuestionDraft({ ...questionDraft, stemImageUrl: '' })} className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700">
                            清空
                          </button>
                        ) : null}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="space-y-3">
                  {questionDraft.options.map((option, index) => (
                    <div key={`${option.id}-${index}`} className="rounded-2xl border border-gray-200 p-4">
                      <div className="mb-3 flex items-center justify-between">
                        <h3 className="text-sm font-semibold text-gray-900">选项 {index + 1}</h3>
                        {questionDraft.options.length > 2 ? (
                          <button
                            type="button"
                            onClick={() =>
                              setQuestionDraft({
                                ...questionDraft,
                                options: questionDraft.options.filter((_, currentIndex) => currentIndex !== index),
                              })
                            }
                            className="text-xs font-medium text-red-600"
                          >
                            删除
                          </button>
                        ) : null}
                      </div>
                      <div className="grid gap-3 md:grid-cols-2">
                        <label className="block text-sm text-gray-700 md:col-span-2">
                          <span className="mb-1 block">文案</span>
                          <input
                            value={option.text}
                            onChange={(event) => {
                              const next = [...questionDraft.options];
                              next[index] = { ...next[index], text: event.target.value };
                              setQuestionDraft({ ...questionDraft, options: next });
                            }}
                            className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                            disabled={!canWrite || saving}
                          />
                        </label>
                        <label className="block text-sm text-gray-700">
                          <span className="mb-1 block">维度</span>
                          <select
                            value={option.scoreAxis}
                            onChange={(event) => {
                              const next = [...questionDraft.options];
                              next[index] = { ...next[index], scoreAxis: event.target.value };
                              setQuestionDraft({ ...questionDraft, options: next });
                            }}
                            className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                            disabled={!canWrite || saving}
                          >
                            <option value="">无</option>
                            {['E', 'I', 'S', 'N', 'T', 'F', 'J', 'P'].map((axis) => (
                              <option key={axis} value={axis}>
                                {axis}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="block text-sm text-gray-700">
                          <span className="mb-1 block">分值</span>
                          <input
                            type="number"
                            value={option.scoreValue}
                            onChange={(event) => {
                              const next = [...questionDraft.options];
                              next[index] = { ...next[index], scoreValue: event.target.value };
                              setQuestionDraft({ ...questionDraft, options: next });
                            }}
                            className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                            disabled={!canWrite || saving}
                          />
                        </label>
                        <label className="block text-sm text-gray-700 md:col-span-2">
                          <span className="mb-1 block">直接触发结果 Code（可选）</span>
                          <input
                            value={option.directResultCode}
                            onChange={(event) => {
                              const next = [...questionDraft.options];
                              next[index] = { ...next[index], directResultCode: event.target.value };
                              setQuestionDraft({ ...questionDraft, options: next });
                            }}
                            className="w-full rounded-2xl border border-gray-200 px-4 py-2.5"
                            disabled={!canWrite || saving}
                          />
                        </label>
                        <div className="md:col-span-2 rounded-2xl border border-dashed border-gray-200 p-3">
                          <div className="flex flex-wrap items-center gap-3">
                            {option.imageUrl ? (
                              <button type="button" onClick={() => openViewer(option.imageUrl)} className="relative h-14 w-14 overflow-hidden rounded-xl border border-gray-200">
                                <Image src={option.imageUrl} alt="option preview" fill className="object-cover" unoptimized />
                              </button>
                            ) : (
                              <div className="flex h-14 w-14 items-center justify-center rounded-xl border border-dashed border-gray-200 text-[10px] text-gray-400">暂无图</div>
                            )}
                            <div className="min-w-0 flex-1">
                              <p className="truncate text-xs text-gray-400">{option.imageUrl || '未上传选项图'}</p>
                              <div className="mt-2 flex gap-2">
                                <label className="inline-flex cursor-pointer rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700">
                                  上传图片
                                  <input
                                    type="file"
                                    accept="image/*"
                                    className="hidden"
                                    onChange={(event) =>
                                      void handleUploadImage(event, (url) => {
                                        const next = [...questionDraft.options];
                                        next[index] = { ...next[index], imageUrl: url };
                                        setQuestionDraft({ ...questionDraft, options: next });
                                      })
                                    }
                                  />
                                </label>
                                {option.imageUrl ? (
                                  <button
                                    type="button"
                                    onClick={() => {
                                      const next = [...questionDraft.options];
                                      next[index] = { ...next[index], imageUrl: '' };
                                      setQuestionDraft({ ...questionDraft, options: next });
                                    }}
                                    className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700"
                                  >
                                    清空
                                  </button>
                                ) : null}
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                <div className="flex flex-wrap gap-3">
                  <button
                    type="button"
                    onClick={() =>
                      setQuestionDraft({
                        ...questionDraft,
                        options: [...questionDraft.options, createEmptyQuestionOption(questionDraft.options.length)],
                      })
                    }
                    disabled={!canWrite || saving || questionDraft.options.length >= 5}
                    className="rounded-full border border-gray-200 px-4 py-2 text-sm font-medium text-gray-700 disabled:opacity-50"
                  >
                    添加选项
                  </button>
                  <button type="button" onClick={handleQuestionSave} disabled={!canWrite || saving} className="rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
                    {saving ? '保存中…' : '保存题目'}
                  </button>
                </div>
              </div>
            </section>
          </div>
        ) : null}

        {tab === 'debug_set' ? (
          <div className="grid gap-6 lg:grid-cols-2">
            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-semibold text-gray-900">题库</h2>
              <div className="mt-4 space-y-2">
                {questions
                  .filter((item) => item.status === 'active')
                  .map((item) => {
                    const checked = debugSetQuestionIds.includes(item.id);
                    return (
                      <label key={item.id} className="flex items-start gap-3 rounded-2xl border border-gray-200 px-4 py-3 text-sm text-gray-700">
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={(event) => {
                            setDebugSetQuestionIds((current) =>
                              event.target.checked ? [...current, item.id] : current.filter((id) => id !== item.id)
                            );
                          }}
                          disabled={!canWrite || saving}
                        />
                        <span>{item.stemText}</span>
                      </label>
                    );
                  })}
              </div>
            </section>

            <section className="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-gray-900">当前调试套题</h2>
                <button type="button" onClick={handleDebugSetSave} disabled={!canWrite || saving} className="rounded-full bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
                  {saving ? '保存中…' : '保存调试套题'}
                </button>
              </div>
              <div className="mt-4 space-y-2">
                {debugSetQuestionIds.map((id, index) => {
                  const item = questions.find((question) => question.id === id);
                  return (
                    <div key={`${id}-${index}`} className="rounded-2xl border border-gray-200 px-4 py-3 text-sm text-gray-700">
                      <div className="font-medium text-gray-900">#{index + 1}</div>
                      <div className="mt-1">{item?.stemText || id}</div>
                    </div>
                  );
                })}
                {debugSetQuestionIds.length === 0 ? <div className="rounded-2xl border border-dashed border-gray-200 px-4 py-8 text-center text-sm text-gray-400">当前还没有配置调试套题。</div> : null}
              </div>
            </section>
          </div>
        ) : null}
      </div>

      <OverlayImageViewer
        assets={overlayAssets}
        activeIndex={overlayIndex}
        onClose={() => setOverlayIndex(null)}
        onChange={(nextIndex) => setOverlayIndex(nextIndex)}
      />
    </AdminAppShell>
  );
}
