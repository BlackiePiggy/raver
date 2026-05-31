'use client';

import { useMemo, useState } from 'react';
import {
  labelStudioApi,
  mapLabelStudioDraftToCreateInput,
  validateLabelStudioDraft,
  type LabelStudioCreateResult,
  type LabelStudioDraft,
  type LabelStudioValidationErrors,
} from '@/features/admin-content/label-studio';

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

type LabelStudioFormProps = {
  mode: 'create' | 'edit';
  labelId?: string;
  draft: LabelStudioDraft;
  setDraft: React.Dispatch<React.SetStateAction<LabelStudioDraft>>;
  onSubmit: (result: LabelStudioCreateResult) => void;
  submitButtonText?: string;
};

export default function LabelStudioForm({
  mode,
  labelId,
  draft,
  setDraft,
  onSubmit,
  submitButtonText,
}: LabelStudioFormProps) {
  const [errors, setErrors] = useState<LabelStudioValidationErrors>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const canSubmit = useMemo(() => Object.keys(validateLabelStudioDraft(draft)).length === 0, [draft]);

  const updateDraft = <K extends keyof LabelStudioDraft>(key: K, value: LabelStudioDraft[K]) => {
    setDraft((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key as keyof LabelStudioValidationErrors]) return current;
      const next = { ...current };
      delete next[key as keyof LabelStudioValidationErrors];
      return next;
    });
  };

  const handleSubmit = async () => {
    const nextErrors = validateLabelStudioDraft(draft);
    setErrors(nextErrors);
    setSubmitError(null);
    if (Object.keys(nextErrors).length > 0) return;

    try {
      setSubmitting(true);
      const payload = mapLabelStudioDraftToCreateInput(draft);
      const result =
        mode === 'edit' && labelId
          ? await labelStudioApi.updateLabel(labelId, payload)
          : await labelStudioApi.createLabel(payload);
      onSubmit(result);
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '厂牌提交失败');
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
          <div className="admin-studio-label">{mode === 'create' ? 'Label Studio' : 'Label Edit'}</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">
            {draft.name || '厂牌资料编辑'}
          </h2>
          <div className="mt-5 grid gap-3 md:grid-cols-3">
            <div className="admin-studio-pastel-mint px-4 py-3 text-sm">
              <div className="text-black/42">国家</div>
              <div className="mt-1 font-semibold text-[#071110]">{draft.nation || '待补充'}</div>
            </div>
            <div className="admin-studio-pastel-sand px-4 py-3 text-sm">
              <div className="text-black/42">风格标签</div>
              <div className="mt-1 font-semibold text-[#071110]">
                {draft.genresText
                  .split(',')
                  .map((item) => item.trim())
                  .filter(Boolean).length || 0}
              </div>
            </div>
            <div className="admin-studio-pastel-rose px-4 py-3 text-sm">
              <div className="text-black/42">视觉素材</div>
              <div className="mt-1 font-semibold text-[#071110]">
                {[draft.logoUrl, draft.avatarUrl, draft.backgroundUrl].filter((item) => item.trim()).length}
              </div>
            </div>
          </div>
        </div>

        <div className="admin-studio-pastel-mint p-6">
          <div className="admin-studio-label">Profile Focus</div>
          <h2 className="mt-2 text-[24px] font-semibold tracking-[-0.03em] text-[#071110]">重点区域</h2>
          <div className="mt-4 space-y-3 text-sm leading-6 text-black/52">
            <p>这一版把厂牌名称、简介、视觉和官方链接做成主要操作区，次级统计信息放在后段。</p>
            <p>视觉素材先用 URL 模式，便于先把后台编辑链路完整打通。</p>
          </div>
        </div>
      </section>

      <Section title="身份与视觉" description="先确定厂牌的主名称、slug、国家和三张核心视觉图。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="厂牌名称" error={errors.name}>
            <input
              value={draft.name}
              onChange={(event) => updateDraft('name', event.target.value)}
              className={textInputClassName}
              placeholder="例如：Afterlife"
            />
          </Field>
          <Field label="Slug">
            <input
              value={draft.slug}
              onChange={(event) => updateDraft('slug', event.target.value)}
              className={textInputClassName}
              placeholder="afterlife"
            />
          </Field>
          <Field label="国家 / 地区">
            <input
              value={draft.nation}
              onChange={(event) => updateDraft('nation', event.target.value)}
              className={textInputClassName}
              placeholder="Italy"
            />
          </Field>
          <Field label="Profile URL">
            <input
              value={draft.profileUrl}
              onChange={(event) => updateDraft('profileUrl', event.target.value)}
              className={textInputClassName}
              placeholder="community://afterlife"
            />
          </Field>
          <Field label="Logo URL">
            <input
              value={draft.logoUrl}
              onChange={(event) => updateDraft('logoUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="Avatar URL">
            <input
              value={draft.avatarUrl}
              onChange={(event) => updateDraft('avatarUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <div className="lg:col-span-2">
            <Field label="Background URL">
              <input
                value={draft.backgroundUrl}
                onChange={(event) => updateDraft('backgroundUrl', event.target.value)}
                className={textInputClassName}
                placeholder="https://..."
              />
            </Field>
          </div>
        </div>
      </Section>

      <Section title="品牌资料" description="把厂牌简介、预览文案、风格和时间地点信息集中维护。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="风格 Tags">
            <input
              value={draft.genresText}
              onChange={(event) => updateDraft('genresText', event.target.value)}
              className={textInputClassName}
              placeholder="melodic techno, house"
            />
          </Field>
          <Field label="Genres Preview">
            <input
              value={draft.genresPreview}
              onChange={(event) => updateDraft('genresPreview', event.target.value)}
              className={textInputClassName}
              placeholder="Melodic Techno / House"
            />
          </Field>
          <Field label="Latest Release">
            <input
              value={draft.latestReleaseListing}
              onChange={(event) => updateDraft('latestReleaseListing', event.target.value)}
              className={textInputClassName}
              placeholder="Anyma - Genesys"
            />
          </Field>
          <Field label="Location Period">
            <input
              value={draft.locationPeriod}
              onChange={(event) => updateDraft('locationPeriod', event.target.value)}
              className={textInputClassName}
              placeholder="Milan / 2016-now"
            />
          </Field>
          <div className="lg:col-span-2">
            <Field label="Introduction Preview">
              <textarea
                value={draft.introductionPreview}
                onChange={(event) => updateDraft('introductionPreview', event.target.value)}
                className={textAreaClassName}
                placeholder="用于列表或卡片的简版简介"
              />
            </Field>
          </div>
          <div className="lg:col-span-2">
            <Field label="Introduction">
              <textarea
                value={draft.introduction}
                onChange={(event) => updateDraft('introduction', event.target.value)}
                className="admin-studio-textarea min-h-[260px]"
                placeholder="完整厂牌介绍"
              />
            </Field>
          </div>
        </div>
      </Section>

      <Section title="官方链接与联系" description="把对外渠道、demo 投递和基础联系邮箱弱化放在次一级区域。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="官方网站">
            <input
              value={draft.officialWebsiteUrl}
              onChange={(event) => updateDraft('officialWebsiteUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="SoundCloud">
            <input
              value={draft.soundcloudUrl}
              onChange={(event) => updateDraft('soundcloudUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="Facebook">
            <input
              value={draft.facebookUrl}
              onChange={(event) => updateDraft('facebookUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="Music Purchase">
            <input
              value={draft.musicPurchaseUrl}
              onChange={(event) => updateDraft('musicPurchaseUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="General Contact Email">
            <input
              value={draft.generalContactEmail}
              onChange={(event) => updateDraft('generalContactEmail', event.target.value)}
              className={textInputClassName}
              placeholder="contact@example.com"
            />
          </Field>
          <Field label="Demo Submission URL">
            <input
              value={draft.demoSubmissionUrl}
              onChange={(event) => updateDraft('demoSubmissionUrl', event.target.value)}
              className={textInputClassName}
              placeholder="https://..."
            />
          </Field>
          <Field label="Demo Submission Display">
            <input
              value={draft.demoSubmissionDisplay}
              onChange={(event) => updateDraft('demoSubmissionDisplay', event.target.value)}
              className={textInputClassName}
              placeholder="Open / Invite Only"
            />
          </Field>
        </div>
      </Section>

      <Section title="创始人与统计" description="最后维护创始人信息和较弱的关注度统计。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="Founder Name">
            <input
              value={draft.founderName}
              onChange={(event) => updateDraft('founderName', event.target.value)}
              className={textInputClassName}
              placeholder="Carmine Conte"
            />
          </Field>
          <Field label="Founded At">
            <input
              value={draft.foundedAt}
              onChange={(event) => updateDraft('foundedAt', event.target.value)}
              className={textInputClassName}
              placeholder="2016"
            />
          </Field>
          <Field label="Founder DJ ID">
            <input
              value={draft.founderDjId}
              onChange={(event) => updateDraft('founderDjId', event.target.value)}
              className={textInputClassName}
              placeholder="dj_001"
            />
          </Field>
          <Field label="SoundCloud Followers">
            <input
              value={draft.soundcloudFollowers}
              onChange={(event) => updateDraft('soundcloudFollowers', event.target.value)}
              className={textInputClassName}
              placeholder="100000"
            />
          </Field>
          <Field label="Likes">
            <input
              value={draft.likes}
              onChange={(event) => updateDraft('likes', event.target.value)}
              className={textInputClassName}
              placeholder="34000"
            />
          </Field>
        </div>
      </Section>

      <Section title="提交" description="确认厂牌主信息后即可直接保存。">
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => void handleSubmit()}
            disabled={submitting || !canSubmit}
            className="admin-studio-button-primary px-6 py-3 text-sm"
          >
            {submitting ? '提交中...' : submitButtonText || (mode === 'create' ? '创建厂牌' : '保存厂牌')}
          </button>
        </div>
      </Section>
    </div>
  );
}
