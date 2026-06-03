'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import EntityBindingField from '@/components/admin/EntityBindingField';
import MarkdownEditor from '@/components/admin/MarkdownEditor';
import {
  extractMarkdownImageUrls,
  mapNewsStudioDraftToCreateInput,
  newsStudioApi,
  validateNewsStudioDraft,
  type NewsStudioBindingItem,
  type NewsStudioCreateResult,
  type NewsStudioDraft,
  type NewsStudioValidationErrors,
} from '@/features/admin-content/news-studio';

function Section({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <section className="admin-studio-section p-6">
      <div>
        <div className="admin-studio-label">{title}</div>
        <p className="mt-3 text-sm leading-6 text-black/52">{description}</p>
      </div>
      <div className="mt-5">{children}</div>
    </section>
  );
}

function Field({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      {children}
      {error ? <div className="mt-2 text-xs text-[#6a3530]">{error}</div> : null}
    </label>
  );
}

const textInputClassName = 'admin-studio-input';
const textAreaClassName = 'admin-studio-textarea min-h-28';
const NEWS_CATEGORY_OPTIONS: NewsStudioDraft['category'][] = [
  'community',
  'festival',
  'scene',
  'gear',
  'industry',
];

type NewsStudioFormProps = {
  mode: 'create' | 'edit';
  newsId?: string;
  draft: NewsStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<NewsStudioDraft>>;
  onSubmit: (result: NewsStudioCreateResult) => void;
  submitButtonText?: string;
};

type SelectionSnapshot = {
  start: number;
  end: number;
};

const appendUniqueBinding = (
  current: NewsStudioBindingItem[],
  incoming: NewsStudioBindingItem
): NewsStudioBindingItem[] => {
  const exists = current.some((item) => item.id === incoming.id);
  if (exists) return current;
  return [...current, incoming];
};

const removeBindingById = (
  current: NewsStudioBindingItem[],
  targetId: string
): NewsStudioBindingItem[] => current.filter((item) => item.id !== targetId);

const toBindingText = (items: NewsStudioBindingItem[]): string =>
  items
    .map((item) => String(item.id || '').trim())
    .filter(Boolean)
    .join(', ');

const dedupeUrls = (items: Array<string | null | undefined>): string[] =>
  Array.from(
    new Set(
      items
        .map((item) => String(item || '').trim())
        .filter(Boolean)
    )
  );

const escapeRegExp = (value: string): string =>
  value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const stripMarkdownImageReferences = (body: string, url: string): string =>
  String(body || '')
    .replace(new RegExp(`!?\\[[^\\]]*\\]\\(${escapeRegExp(url)}\\)\\n?`, 'g'), '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

export default function NewsStudioForm({
  mode,
  newsId,
  draft,
  setDraft,
  onSubmit,
  submitButtonText,
}: NewsStudioFormProps) {
  const [errors, setErrors] = useState<NewsStudioValidationErrors>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [mediaUploading, setMediaUploading] = useState(false);
  const [mediaMessage, setMediaMessage] = useState<string | null>(null);
  const [mediaError, setMediaError] = useState<string | null>(null);
  const [cleaningResourceUrl, setCleaningResourceUrl] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const bodyTextareaRef = useRef<HTMLTextAreaElement | null>(null);
  const bodySelectionRef = useRef<SelectionSnapshot | null>(null);
  const pendingFocusSelectionRef = useRef<SelectionSnapshot | null>(null);

  const canSubmit = useMemo(() => Object.keys(validateNewsStudioDraft(draft)).length === 0, [draft]);

  const resourceUrls = useMemo(
    () =>
      dedupeUrls([
        draft.coverImageUrl,
        ...draft.bodyImageUrls,
        ...extractMarkdownImageUrls(draft.body),
      ]),
    [draft.body, draft.bodyImageUrls, draft.coverImageUrl]
  );

  useEffect(() => {
    const pending = pendingFocusSelectionRef.current;
    if (!pending) return;
    const textarea = bodyTextareaRef.current;
    if (!textarea) return;
    textarea.focus();
    textarea.setSelectionRange(pending.start, pending.end);
    pendingFocusSelectionRef.current = null;
    bodySelectionRef.current = pending;
  }, [draft.body]);

  const updateDraft = <K extends keyof NewsStudioDraft>(key: K, value: NewsStudioDraft[K]) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof NewsStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof NewsStudioValidationErrors];
      return next;
    });
  };

  const updateBody = (value: string) => {
    updateDraft('body', value);
  };

  const updateBindingDraft = (
    key: 'boundDjs' | 'boundBrands' | 'boundEvents',
    value: NewsStudioBindingItem[]
  ) => {
    setDraft((current) => ({
      ...current,
      [key]: value,
      ...(key === 'boundDjs' ? { boundDjIdsText: toBindingText(value) } : {}),
      ...(key === 'boundBrands' ? { boundBrandIdsText: toBindingText(value) } : {}),
      ...(key === 'boundEvents' ? { boundEventIdsText: toBindingText(value) } : {}),
    }));
  };

  const updateResourcePool = (items: string[]) => {
    const normalized = dedupeUrls(items);
    setDraft((current) => ({
      ...current,
      coverImageUrl: normalized[0] || '',
      bodyImageUrls: normalized.slice(1),
    }));
  };

  const captureBodySelection = () => {
    const textarea = bodyTextareaRef.current;
    if (!textarea) return;
    bodySelectionRef.current = {
      start: Number.isFinite(textarea.selectionStart) ? textarea.selectionStart : draft.body.length,
      end: Number.isFinite(textarea.selectionEnd) ? textarea.selectionEnd : draft.body.length,
    };
  };

  const preserveBodyFocus = () => {
    captureBodySelection();
  };

  const openFilePicker = () => {
    fileInputRef.current?.click();
  };

  const insertResourceIntoBody = (url: string) => {
    const safeUrl = String(url || '').trim();
    if (!safeUrl) return;

    const snippet = `\n![image](${safeUrl})\n`;
    const selection = bodySelectionRef.current ?? {
      start: draft.body.length,
      end: draft.body.length,
    };
    const nextBody = `${draft.body.slice(0, selection.start)}${snippet}${draft.body.slice(selection.end)}`;
    const nextCursor = selection.start + snippet.length;
    pendingFocusSelectionRef.current = {
      start: nextCursor,
      end: nextCursor,
    };
    updateBody(nextBody);
    setMediaError(null);
    setMediaMessage('已插入正文，并保持编辑焦点。');
  };

  const setResourceAsCover = (url: string) => {
    const safeUrl = String(url || '').trim();
    if (!safeUrl) return;
    updateResourcePool([safeUrl, ...resourceUrls.filter((item) => item !== safeUrl)]);
    setMediaError(null);
    setMediaMessage('已设为封面。');
  };

  const removeResource = async (url: string) => {
    const safeUrl = String(url || '').trim();
    if (!safeUrl) return;

    const needsDraftCleanup =
      mode === 'create' &&
      !newsId &&
      draft.uploadNewsKey.trim().length > 0 &&
      draft.sessionUploadedResources.includes(safeUrl);

    if (needsDraftCleanup) {
      try {
        setCleaningResourceUrl(safeUrl);
        await newsStudioApi.cleanupDraftMedia({
          draftKey: draft.uploadNewsKey,
          urls: [safeUrl],
        });
      } catch (error) {
        setMediaMessage(null);
        setMediaError(error instanceof Error ? error.message : '草稿资源清理失败，已取消本次移除。');
        setCleaningResourceUrl(null);
        return;
      }
    }

    const nextPool = resourceUrls.filter((item) => item !== safeUrl);
    setDraft((current) => ({
      ...current,
      body: stripMarkdownImageReferences(current.body, safeUrl),
      coverImageUrl: nextPool[0] || '',
      bodyImageUrls: nextPool.slice(1),
      sessionUploadedResources: current.sessionUploadedResources.filter((item) => item !== safeUrl),
    }));
    setCleaningResourceUrl(null);
    setMediaError(null);
    setMediaMessage(needsDraftCleanup ? '已移除资源，并完成草稿图清理。' : '已移除资源。');
  };

  const handleUploadFiles = async (fileList: FileList | null) => {
    const files = Array.from(fileList || []).filter((file) => /^image\//i.test(file.type));
    if (!files.length) {
      setMediaMessage(null);
      setMediaError('请选择图片文件后再上传。');
      return;
    }

    setMediaUploading(true);
    setMediaError(null);
    setMediaMessage(null);

    let successCount = 0;

    try {
      for (const file of files) {
        const uploaded = await newsStudioApi.uploadImage(file, {
          newsId: mode === 'edit' ? newsId : undefined,
          draftKey: mode === 'create' ? draft.uploadNewsKey : undefined,
        });
        const nextUrl = String(uploaded.url || '').trim();
        if (!nextUrl) continue;

        setDraft((current) => {
          const currentPool = dedupeUrls([current.coverImageUrl, ...current.bodyImageUrls]);
          const nextPool = currentPool.length ? [...currentPool, nextUrl] : [nextUrl];
          const normalized = dedupeUrls(nextPool);
          return {
            ...current,
            coverImageUrl: normalized[0] || '',
            bodyImageUrls: normalized.slice(1),
            sessionUploadedResources: dedupeUrls([...current.sessionUploadedResources, nextUrl]),
          };
        });
        successCount += 1;
      }

      if (!successCount) {
        setMediaError('上传成功但没有返回可用的资源地址。');
        return;
      }

      setMediaMessage(`资源上传完成：${successCount}/${files.length} 张。`);
    } catch (error) {
      setMediaError(error instanceof Error ? error.message : '资讯资源上传失败。');
    } finally {
      setMediaUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleSubmit = async () => {
    const nextErrors = validateNewsStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) return;

    try {
      setSubmitting(true);
      const payload = mapNewsStudioDraftToCreateInput(draft);
      const result =
        mode === 'edit' && newsId
          ? await newsStudioApi.updateNews(newsId, payload)
          : await newsStudioApi.createNews(payload);
      onSubmit(result);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '资讯提交失败。');
    } finally {
      setSubmitting(false);
    }
  };

  const totalBindings = draft.boundDjs.length + draft.boundBrands.length + draft.boundEvents.length;

  return (
    <div className="space-y-5">
      {submitError ? (
        <section className="admin-studio-pastel-rose p-4 text-sm text-[#6a3530]">
          {submitError}
        </section>
      ) : null}

      <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
        <div className="admin-studio-section p-6">
          <div className="admin-studio-label">{mode === 'create' ? 'News Studio' : 'News Edit'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">
            {draft.title || '资讯内容编辑'}
          </h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            <div className="admin-studio-pastel-mint px-4 py-3 text-sm">
              <div className="text-black/42">分类</div>
              <div className="mt-1 font-semibold text-[#071110]">{draft.category}</div>
            </div>
            <div className="admin-studio-pastel-sand px-4 py-3 text-sm">
              <div className="text-black/42">来源</div>
              <div className="mt-1 font-semibold text-[#071110]">{draft.source || 'Raver'}</div>
            </div>
            <div className="admin-studio-pastel-rose px-4 py-3 text-sm">
              <div className="text-black/42">绑定对象</div>
              <div className="mt-1 font-semibold text-[#071110]">{totalBindings}</div>
            </div>
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">Publish Flow</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">发布摘要</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>正文继续采用 Markdown 编辑与实时预览，尽量对齐 legacy 资讯编辑器的工作方式。</p>
            <p>对象绑定统一走共享搜索绑定层，一篇资讯可以同时关联多个 DJ、品牌和活动。</p>
          </div>
        </div>
      </section>

      <Section title="核心内容" description="先完成标题、来源、分类和发布时间，确保资讯主体信息完整。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="资讯标题" error={errors.title}>
            <input
              value={draft.title}
              onChange={(event) => updateDraft('title', event.target.value)}
              className={textInputClassName}
              placeholder="填写资讯标题"
            />
          </Field>
          <Field label="来源">
            <input
              value={draft.source}
              onChange={(event) => updateDraft('source', event.target.value)}
              className={textInputClassName}
              placeholder="Raver / Billboard / Resident Advisor"
            />
          </Field>
          <Field label="资讯分类">
            <select
              value={draft.category}
              onChange={(event) => updateDraft('category', event.target.value as NewsStudioDraft['category'])}
              className={textInputClassName}
            >
              {NEWS_CATEGORY_OPTIONS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Field>
          <Field label="发布时间">
            <input
              type="datetime-local"
              value={draft.publishedAt}
              onChange={(event) => updateDraft('publishedAt', event.target.value)}
              className={textInputClassName}
            />
          </Field>
        </div>
      </Section>

      <Section title="摘要与正文" description="先完成摘要、原始链接和封面信息，再进入正文工作区。Markdown 原文与渲染结果并排独占，并限制高度为固定容器内滚动。">
        <div className="space-y-5">
          <div className="grid gap-4 xl:grid-cols-[1.2fr_1fr]">
            <Field label="摘要">
              <textarea
                value={draft.summary}
                onChange={(event) => updateDraft('summary', event.target.value)}
                className={`${textAreaClassName} min-h-[148px]`}
                placeholder="写一个适合列表展示的摘要"
              />
            </Field>

            <div className="grid gap-4">
              <Field label="原始链接">
                <input
                  value={draft.link}
                  onChange={(event) => updateDraft('link', event.target.value)}
                  className={textInputClassName}
                  placeholder="https://..."
                />
              </Field>
              <Field label="封面图 URL">
                <input
                  value={draft.coverImageUrl}
                  onChange={(event) => updateDraft('coverImageUrl', event.target.value)}
                  className={textInputClassName}
                  placeholder="https://..."
                />
              </Field>
            </div>
          </div>

          <div className="grid gap-5 xl:grid-cols-[minmax(0,1.5fr)_minmax(320px,0.9fr)]">
            <div className="admin-reference-card p-4">
              <MarkdownEditor
                label="正文内容"
                value={draft.body}
                onChange={updateBody}
                placeholder="填写资讯正文，支持 Markdown"
                error={errors.body}
                textareaRef={bodyTextareaRef}
                minHeightClassName="h-[560px]"
                scrollablePanels
                gridClassName="grid gap-4 xl:grid-cols-2"
              />
            </div>

            <div className="space-y-4">
              <div className="admin-reference-card p-4">
                <div className="admin-studio-label">封面预览</div>
                <div className="mt-4 overflow-hidden rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8]">
                  {draft.coverImageUrl.trim() ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={draft.coverImageUrl} alt="news cover" className="h-56 w-full object-cover" />
                  ) : (
                    <div className="flex h-56 items-center justify-center text-sm text-black/40">封面预览区</div>
                  )}
                </div>
              </div>

              <div className="admin-reference-card p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <div className="admin-studio-label">媒体资源区</div>
                    <div className="mt-2 text-sm leading-6 text-black/48">
                      这里维护资讯素材池，支持上传图片、插入正文、设为封面。
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      multiple
                      className="hidden"
                      onChange={(event) => void handleUploadFiles(event.target.files)}
                    />
                    <button
                      type="button"
                      onClick={openFilePicker}
                      disabled={mediaUploading}
                      className="admin-studio-button-secondary px-4 py-2 text-sm disabled:opacity-60"
                    >
                      {mediaUploading ? '上传中...' : '上传资源'}
                    </button>
                  </div>
                </div>

                {mediaError ? (
                  <div className="mt-4 rounded-[16px] border border-[#f0d7d5] bg-[#fff7f6] px-3 py-2 text-xs text-[#8b3a3a]">
                    {mediaError}
                  </div>
                ) : null}
                {mediaMessage ? (
                  <div className="mt-4 rounded-[16px] border border-[#d8e5dc] bg-[#f5fbf6] px-3 py-2 text-xs text-[#2f5d43]">
                    {mediaMessage}
                  </div>
                ) : null}

                <div className="mt-4 max-h-[420px] space-y-3 overflow-y-auto pr-1">
                  {resourceUrls.length ? (
                    resourceUrls.map((url) => {
                      const isCover = draft.coverImageUrl.trim() === url;
                      const isCleaning = cleaningResourceUrl === url;
                      return (
                        <div key={url} className="rounded-[20px] border border-[#e8eceb] bg-white p-3">
                          <div className="flex gap-3">
                            <div className="h-16 w-16 overflow-hidden rounded-[16px] border border-[#edf0f2] bg-[#f8f9f8]">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img src={url} alt="news resource" className="h-full w-full object-cover" />
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="flex flex-wrap items-center gap-2">
                                {isCover ? (
                                  <span className="rounded-full bg-[#071110] px-2.5 py-1 text-[11px] font-semibold text-white">
                                    当前封面
                                  </span>
                                ) : null}
                                {isCleaning ? (
                                  <span className="rounded-full bg-[#f4f5f7] px-2.5 py-1 text-[11px] font-semibold text-[#6b7280]">
                                    清理中
                                  </span>
                                ) : null}
                              </div>
                              <div className="mt-2 break-all text-xs leading-5 text-black/52">{url}</div>
                              <div className="mt-3 flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onMouseDown={(event) => {
                                    event.preventDefault();
                                    preserveBodyFocus();
                                  }}
                                  onClick={() => insertResourceIntoBody(url)}
                                  className="rounded-full border border-[#d7ded9] bg-white px-3 py-1.5 text-xs font-semibold text-[#18211f]"
                                >
                                  插入正文
                                </button>
                                {!isCover ? (
                                  <button
                                    type="button"
                                    onMouseDown={(event) => {
                                      event.preventDefault();
                                      preserveBodyFocus();
                                    }}
                                    onClick={() => setResourceAsCover(url)}
                                    className="rounded-full border border-[#d7ded9] bg-white px-3 py-1.5 text-xs font-semibold text-[#18211f]"
                                  >
                                    设为封面
                                  </button>
                                ) : null}
                                <button
                                  type="button"
                                  onMouseDown={(event) => {
                                    event.preventDefault();
                                    preserveBodyFocus();
                                  }}
                                  onClick={() => void removeResource(url)}
                                  disabled={isCleaning}
                                  className="rounded-full border border-[#ead6d6] bg-white px-3 py-1.5 text-xs font-semibold text-[#8b3a3a] disabled:opacity-60"
                                >
                                  {isCleaning ? '清理中...' : '移除资源'}
                                </button>
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })
                  ) : (
                    <div className="rounded-[18px] border border-dashed border-[#d7ded9] px-4 py-5 text-sm text-black/48">
                      还没有上传任何资源。先上传图片，之后可以在这里插入正文或设为封面。
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </Section>

      <Section title="关联对象" description="使用共享绑定能力添加多个 DJ、品牌和活动，操作逻辑与新的后台绑定层保持一致。">
        <div className="grid gap-5 xl:grid-cols-3">
          <EntityBindingField
            kind="dj"
            mode="multiple"
            title="绑定 DJs"
            emptyLabel="还没有绑定任何 DJ。"
            items={draft.boundDjs}
            onAdd={(value) => updateBindingDraft('boundDjs', appendUniqueBinding(draft.boundDjs, value))}
            onRemove={(value) => updateBindingDraft('boundDjs', removeBindingById(draft.boundDjs, value.id))}
          />

          <EntityBindingField
            kind="brand"
            mode="multiple"
            title="绑定 Brands"
            emptyLabel="还没有绑定任何品牌或主办方。"
            items={draft.boundBrands}
            onAdd={(value) => updateBindingDraft('boundBrands', appendUniqueBinding(draft.boundBrands, value))}
            onRemove={(value) => updateBindingDraft('boundBrands', removeBindingById(draft.boundBrands, value.id))}
          />

          <EntityBindingField
            kind="event"
            mode="multiple"
            title="绑定 Events"
            emptyLabel="还没有绑定任何活动。"
            items={draft.boundEvents}
            onAdd={(value) => updateBindingDraft('boundEvents', appendUniqueBinding(draft.boundEvents, value))}
            onRemove={(value) => updateBindingDraft('boundEvents', removeBindingById(draft.boundEvents, value.id))}
          />
        </div>
      </Section>

      <Section title="提交" description="确认正文和关联对象后即可保存，出站 payload 仍保持当前后端契约兼容。">
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => void handleSubmit()}
            disabled={submitting || !canSubmit}
            className="admin-studio-button-primary px-6 py-3 text-sm"
          >
            {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '发布资讯' : '保存资讯')}
          </button>
        </div>
      </Section>
    </div>
  );
}
