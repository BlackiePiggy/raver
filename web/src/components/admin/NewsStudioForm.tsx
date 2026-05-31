'use client';

import { useMemo, useState } from 'react';
import {
  mapNewsStudioDraftToCreateInput,
  newsStudioApi,
  validateNewsStudioDraft,
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

type NewsStudioFormProps = {
  mode: 'create' | 'edit';
  newsId?: string;
  draft: NewsStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<NewsStudioDraft>>;
  onSubmit: (result: NewsStudioCreateResult) => void;
  submitButtonText?: string;
};

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

  const canSubmit = useMemo(() => Object.keys(validateNewsStudioDraft(draft)).length === 0, [draft]);

  const updateDraft = <K extends keyof NewsStudioDraft>(key: K, value: NewsStudioDraft[K]) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof NewsStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof NewsStudioValidationErrors];
      return next;
    });
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
      setSubmitError(error instanceof Error ? error.message : '资讯提交失败');
    } finally {
      setSubmitting(false);
    }
  };

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
              <div className="text-black/42">绑定数</div>
              <div className="mt-1 font-semibold text-[#071110]">
                {[
                  draft.boundDjIdsText,
                  draft.boundBrandIdsText,
                  draft.boundEventIdsText,
                ]
                  .join(',')
                  .split(',')
                  .map((item) => item.trim())
                  .filter(Boolean).length}
              </div>
            </div>
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">Publish Flow</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">发布摘要</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>这里优先突出标题、正文和关联实体，弱化次级状态信息。</p>
            <p>正文、摘要、封面和关联 ID 会在一次提交里一起保存，便于运营快速完成更新。</p>
          </div>
        </div>
      </section>

      <Section title="核心内容" description="先完成标题、来源、分类和发布时间，确保资讯本体信息完整。">
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
              {['community', 'festival', 'scene', 'gear', 'industry'].map((item) => (
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
          <div className="lg:col-span-2">
            <Field label="原始链接">
              <input
                value={draft.link}
                onChange={(event) => updateDraft('link', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
          </div>
        </div>
      </Section>

      <Section title="摘要与正文" description="把阅读区做成最主要的操作区，封面与摘要都围绕正文组织。">
        <div className="grid gap-5 xl:grid-cols-[0.8fr_1.2fr]">
          <div className="admin-reference-card p-4">
            <Field label="封面图 URL">
              <input
                value={draft.coverImageUrl}
                onChange={(event) => updateDraft('coverImageUrl', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
            <div className="mt-4 overflow-hidden rounded-[24px] border border-[#e8eceb] bg-[#f8f9f8]">
              {draft.coverImageUrl.trim() ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={draft.coverImageUrl} alt="news cover" className="h-56 w-full object-cover" />
              ) : (
                <div className="flex h-56 items-center justify-center text-sm text-black/40">封面预览区</div>
              )}
            </div>
          </div>

          <div className="space-y-4">
            <Field label="摘要">
              <textarea
                value={draft.summary}
                onChange={(event) => updateDraft('summary', event.target.value)}
                className={textAreaClassName}
                placeholder="写一个适合列表展示的摘要"
              />
            </Field>
            <Field label="正文内容" error={errors.body}>
              <textarea
                value={draft.body}
                onChange={(event) => updateDraft('body', event.target.value)}
                className="admin-studio-textarea min-h-[360px]"
                placeholder="填写资讯正文"
              />
            </Field>
          </div>
        </div>
      </Section>

      <Section title="关联实体" description="这里先采用 ID 绑定模式，便于快速把资讯挂到 DJ、主办方和活动下。">
        <div className="grid gap-4 lg:grid-cols-3">
          <Field label="绑定 DJ IDs">
            <textarea
              value={draft.boundDjIdsText}
              onChange={(event) => updateDraft('boundDjIdsText', event.target.value)}
              className="admin-studio-textarea min-h-32"
              placeholder="dj_001, dj_002"
            />
          </Field>
          <Field label="绑定主办方 IDs">
            <textarea
              value={draft.boundBrandIdsText}
              onChange={(event) => updateDraft('boundBrandIdsText', event.target.value)}
              className="admin-studio-textarea min-h-32"
              placeholder="brand_001, brand_002"
            />
          </Field>
          <Field label="绑定活动 IDs">
            <textarea
              value={draft.boundEventIdsText}
              onChange={(event) => updateDraft('boundEventIdsText', event.target.value)}
              className="admin-studio-textarea min-h-32"
              placeholder="event_001, event_002"
            />
          </Field>
        </div>
      </Section>

      <Section title="提交" description="确认阅读内容与关联关系后即可直接保存到当前资讯。">
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
