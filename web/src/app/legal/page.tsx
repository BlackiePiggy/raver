import Link from 'next/link';
import Navigation from '@/components/Navigation';
import { legalDocuments } from '@/lib/legal-documents';

export default function LegalIndexPage() {
  return (
    <div className="min-h-screen bg-bg-primary text-text-primary">
      <Navigation />
      <main className="mx-auto max-w-5xl px-6 pb-10 pt-24">
        <div className="mb-8">
          <h1 className="text-3xl font-semibold">Legal</h1>
          <p className="mt-2 text-sm text-text-secondary">Public policy and compliance pages.</p>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          {legalDocuments.map((doc) => (
            <Link key={doc.slug} href={`/legal/${doc.slug}`} className="rounded-lg border border-border-secondary bg-bg-secondary p-5 hover:border-primary-blue">
              <div className="text-sm text-text-tertiary">/legal/{doc.slug}</div>
              <div className="mt-2 text-lg font-semibold">{doc.title.ja}</div>
              <div className="mt-2 text-sm text-text-secondary">{doc.intro.ja}</div>
            </Link>
          ))}
        </div>
      </main>
    </div>
  );
}

