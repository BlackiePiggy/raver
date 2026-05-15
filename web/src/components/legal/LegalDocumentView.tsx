'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import type { LegalDocument, LegalLanguage } from '@/lib/legal-documents';

const languageTabs: Array<{ value: LegalLanguage; label: string }> = [
  { value: 'zh', label: '中文' },
  { value: 'en', label: 'English' },
  { value: 'ja', label: '日本語' },
];

function pickText(value: Record<LegalLanguage, string>, language: LegalLanguage): string {
  return value[language];
}

export default function LegalDocumentView({ document }: { document: LegalDocument }) {
  const [language, setLanguage] = useState<LegalLanguage>('ja');
  const title = useMemo(() => pickText(document.title, language), [document.title, language]);
  const metadataLabels = {
    version: {
      zh: '版本',
      en: 'Version',
      ja: 'バージョン',
    },
    effectiveAt: {
      zh: '生效日期',
      en: 'Effective Date',
      ja: '施行日',
    },
    updatedAt: {
      zh: '更新日期',
      en: 'Updated',
      ja: '更新日',
    },
    previous: {
      zh: '上一版本',
      en: 'Previous Version',
      ja: '前のバージョン',
    },
  };

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <div className="mx-auto max-w-4xl px-6 py-10">
        <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
          <div>
            <Link href="/" className="text-sm text-text-secondary hover:text-text-primary">
              ← 返回首页
            </Link>
            <h1 className="mt-3 text-3xl font-semibold">{title}</h1>
            <p className="mt-2 text-sm text-text-secondary">{pickText(document.intro, language)}</p>
            <dl className="mt-4 grid gap-2 text-xs text-text-tertiary sm:grid-cols-3">
              <div className="rounded-lg border border-border-secondary bg-bg-secondary px-3 py-2">
                <dt>{pickText(metadataLabels.version, language)}</dt>
                <dd className="mt-1 text-text-secondary">{document.version}</dd>
              </div>
              <div className="rounded-lg border border-border-secondary bg-bg-secondary px-3 py-2">
                <dt>{pickText(metadataLabels.effectiveAt, language)}</dt>
                <dd className="mt-1 text-text-secondary">{document.effectiveAt}</dd>
              </div>
              <div className="rounded-lg border border-border-secondary bg-bg-secondary px-3 py-2">
                <dt>{pickText(metadataLabels.updatedAt, language)}</dt>
                <dd className="mt-1 text-text-secondary">{document.updatedAt}</dd>
              </div>
            </dl>
          </div>

          <div className="flex rounded-full border border-border-secondary bg-bg-secondary p-1">
            {languageTabs.map((tab) => (
              <button
                key={tab.value}
                type="button"
                onClick={() => setLanguage(tab.value)}
                className={`rounded-full px-4 py-2 text-sm transition-colors ${
                  language === tab.value
                    ? 'bg-primary-blue text-white'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {document.contact && (
          <section className="mb-6 rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <p className="text-sm leading-6 text-text-secondary">
              {pickText(document.contact, language)}
            </p>
          </section>
        )}

        {document.previousVersions.length > 0 && (
          <section className="mb-6 rounded-lg border border-border-secondary bg-bg-secondary p-5">
            <h2 className="text-sm font-semibold">{pickText(metadataLabels.previous, language)}</h2>
            <div className="mt-3 flex flex-wrap gap-2">
              {document.previousVersions.map((item) => (
                <Link
                  key={`${item.version}-${item.effectiveAt}`}
                  href={item.href}
                  className="rounded-full border border-border-secondary px-3 py-1.5 text-xs text-text-secondary hover:border-primary-blue hover:text-primary-blue"
                >
                  {item.version} · {item.effectiveAt}
                </Link>
              ))}
            </div>
          </section>
        )}

        <div className="space-y-4">
          {document.sections.map((section) => (
            <section key={pickText(section.title, language)} className="rounded-lg border border-border-secondary bg-bg-secondary p-5">
              <h2 className="text-lg font-semibold">{pickText(section.title, language)}</h2>
              <div className="mt-4 space-y-4">
                {section.paragraphs.map((paragraph) => (
                  <p key={pickText(paragraph, language)} className="text-sm leading-7 text-text-secondary">
                    {pickText(paragraph, language)}
                  </p>
                ))}
                {section.bullets && section.bullets.length > 0 && (
                  <ul className="space-y-2 text-sm leading-7 text-text-secondary">
                    {section.bullets.map((bullet) => (
                      <li key={pickText(bullet, language)} className="flex gap-2">
                        <span className="text-primary-purple">•</span>
                        <span>{pickText(bullet, language)}</span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </section>
          ))}
        </div>
      </div>
    </main>
  );
}
