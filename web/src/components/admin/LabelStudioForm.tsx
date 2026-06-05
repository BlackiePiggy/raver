'use client';

import { useMemo, useState } from 'react';
import AdminCountedControl from '@/components/admin/AdminCountedControl';
import DynamicStringListField from '@/components/admin/DynamicStringListField';
import { notificationCenterAdminApi } from '@/lib/api/notification-center-admin';
import { INPUT_LIMITS, countText } from '@/lib/input-rules';
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
  hint,
  children,
}: {
  label: string;
  error?: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <div className="mb-2 admin-studio-label">{label}</div>
      {children}
      {hint ? <div className="mt-2 text-xs text-black/40">{hint}</div> : null}
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

  const updateGenres = (updater: (current: string[]) => string[]) => {
    setDraft((current) => ({
      ...current,
      genres: updater(current.genres),
    }));
    setErrors((current) => {
      if (!current.name) return current;
      const next = { ...current };
      delete next.name;
      return next;
    });
  };

  const handleGenreChange = (index: number, value: string) => {
    updateGenres((current) => current.map((item, itemIndex) => (itemIndex === index ? value : item)));
  };

  const handleGenreAdd = () => {
    updateGenres((current) =>
      current.length >= INPUT_LIMITS.label.genresMaxItems ? current : [...current, '']
    );
  };

  const handleGenreRemove = (index: number) => {
    updateGenres((current) => {
      const next = current.filter((_, itemIndex) => itemIndex !== index);
      return next.length ? next : [''];
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
      await notificationCenterAdminApi
        .logContentHistoryFailure({
          entityType: 'label',
          entityId: labelId ?? null,
          taskType: 'brand_release',
          operationType: mode === 'edit' ? 'edit' : 'create',
          title: draft.name || (mode === 'edit' ? '厂牌编辑失败' : '厂牌创建失败'),
          summary: draft.introduction || draft.introductionPreview || null,
          sourceRoute: mode === 'edit' && labelId ? `/admin/content/labels/${labelId}/edit` : '/admin/content/labels/new',
          errorMessage: error instanceof Error ? error.message : '厂牌提交失败',
          payload: {
            name: draft.name,
            nation: draft.nation,
          },
        })
        .catch(() => undefined);
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
                {draft.genres.map((item) => item.trim()).filter(Boolean).length}
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
            <AdminCountedControl count={countText(draft.name)} maxLength={INPUT_LIMITS.label.name}>
              <input
                value={draft.name}
                onChange={(event) => updateDraft('name', event.target.value)}
                className={textInputClassName}
                placeholder="例如：Afterlife"
                maxLength={INPUT_LIMITS.label.name}
              />
            </AdminCountedControl>
          </Field>
          <Field label="Slug">
            <AdminCountedControl count={countText(draft.slug)} maxLength={INPUT_LIMITS.label.slug}>
              <input
                value={draft.slug}
                onChange={(event) => updateDraft('slug', event.target.value)}
                className={textInputClassName}
                placeholder="afterlife"
                maxLength={INPUT_LIMITS.label.slug}
              />
            </AdminCountedControl>
          </Field>
          <Field label="国家 / 地区">
            <AdminCountedControl count={countText(draft.nation)} maxLength={INPUT_LIMITS.label.nation}>
              <input
                value={draft.nation}
                onChange={(event) => updateDraft('nation', event.target.value)}
                className={textInputClassName}
                placeholder="Italy"
                maxLength={INPUT_LIMITS.label.nation}
              />
            </AdminCountedControl>
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
          <DynamicStringListField
            label="风格 Tags"
            items={draft.genres}
            placeholder="例如：Melodic Techno"
            hint="逐条维护风格标签，避免依赖逗号或换行拆分。"
            itemMax={INPUT_LIMITS.label.genre}
            maxItems={INPUT_LIMITS.label.genresMaxItems}
            onChange={handleGenreChange}
            onAdd={handleGenreAdd}
            onRemove={handleGenreRemove}
          />
          <Field label="Genres Preview">
            <AdminCountedControl count={countText(draft.genresPreview)} maxLength={INPUT_LIMITS.label.genresPreview}>
              <input
                value={draft.genresPreview}
                onChange={(event) => updateDraft('genresPreview', event.target.value)}
                className={textInputClassName}
                placeholder="Melodic Techno / House"
                maxLength={INPUT_LIMITS.label.genresPreview}
              />
            </AdminCountedControl>
          </Field>
          <Field label="Latest Release">
            <AdminCountedControl count={countText(draft.latestReleaseListing)} maxLength={INPUT_LIMITS.label.latestReleaseListing}>
              <input
                value={draft.latestReleaseListing}
                onChange={(event) => updateDraft('latestReleaseListing', event.target.value)}
                className={textInputClassName}
                placeholder="Anyma - Genesys"
                maxLength={INPUT_LIMITS.label.latestReleaseListing}
              />
            </AdminCountedControl>
          </Field>
          <Field label="Location Period">
            <AdminCountedControl count={countText(draft.locationPeriod)} maxLength={INPUT_LIMITS.label.locationPeriod}>
              <input
                value={draft.locationPeriod}
                onChange={(event) => updateDraft('locationPeriod', event.target.value)}
                className={textInputClassName}
                placeholder="Milan / 2016-now"
                maxLength={INPUT_LIMITS.label.locationPeriod}
              />
            </AdminCountedControl>
          </Field>
          <div className="lg:col-span-2">
            <Field label="Introduction Preview">
              <AdminCountedControl count={countText(draft.introductionPreview, true)} maxLength={INPUT_LIMITS.label.introductionPreview} multiline>
                <textarea
                  value={draft.introductionPreview}
                  onChange={(event) => updateDraft('introductionPreview', event.target.value)}
                  className={textAreaClassName}
                  placeholder="用于列表或卡片的简版简介"
                  maxLength={INPUT_LIMITS.label.introductionPreview}
                />
              </AdminCountedControl>
            </Field>
          </div>
          <div className="lg:col-span-2">
            <Field label="Introduction">
              <AdminCountedControl count={countText(draft.introduction, true)} maxLength={INPUT_LIMITS.label.introduction} multiline>
                <textarea
                  value={draft.introduction}
                  onChange={(event) => updateDraft('introduction', event.target.value)}
                  className="admin-studio-textarea min-h-[260px]"
                  placeholder="完整厂牌介绍"
                  maxLength={INPUT_LIMITS.label.introduction}
                />
              </AdminCountedControl>
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
            <AdminCountedControl count={countText(draft.demoSubmissionDisplay)} maxLength={INPUT_LIMITS.label.demoSubmissionDisplay}>
              <input
                value={draft.demoSubmissionDisplay}
                onChange={(event) => updateDraft('demoSubmissionDisplay', event.target.value)}
                className={textInputClassName}
                placeholder="Open / Invite Only"
                maxLength={INPUT_LIMITS.label.demoSubmissionDisplay}
              />
            </AdminCountedControl>
          </Field>
        </div>
      </Section>

      <Section title="创始人与统计" description="最后维护创始人信息和较弱的关注度统计。">
        <div className="grid gap-4 lg:grid-cols-2">
          <Field label="Founder Name">
            <AdminCountedControl count={countText(draft.founderName)} maxLength={INPUT_LIMITS.label.founderName}>
              <input
                value={draft.founderName}
                onChange={(event) => updateDraft('founderName', event.target.value)}
                className={textInputClassName}
                placeholder="Carmine Conte"
                maxLength={INPUT_LIMITS.label.founderName}
              />
            </AdminCountedControl>
          </Field>
          <Field label="Founded At">
            <AdminCountedControl count={countText(draft.foundedAt)} maxLength={INPUT_LIMITS.label.foundedAt}>
              <input
                value={draft.foundedAt}
                onChange={(event) => updateDraft('foundedAt', event.target.value)}
                className={textInputClassName}
                placeholder="2016"
                maxLength={INPUT_LIMITS.label.foundedAt}
              />
            </AdminCountedControl>
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
