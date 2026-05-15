import { notFound } from 'next/navigation';
import LegalDocumentView from '@/components/legal/LegalDocumentView';
import { legalDocumentMap, legalDocuments } from '@/lib/legal-documents';

export function generateStaticParams() {
  return legalDocuments.flatMap((doc) =>
    doc.previousVersions.map((previous) => ({
      slug: doc.slug,
      version: previous.version,
    }))
  );
}

export default async function LegalArchivePage({
  params,
}: {
  params: Promise<{ slug: string; version: string }>;
}) {
  const { slug, version } = await params;
  const document = legalDocumentMap.get(slug);
  const previous = document?.previousVersions.find((item) => item.version === version);
  if (!document || !previous) {
    notFound();
  }

  return (
    <LegalDocumentView
      document={{
        ...document,
        version: previous.version,
        effectiveAt: previous.effectiveAt,
        updatedAt: previous.effectiveAt,
        previousVersions: [],
      }}
    />
  );
}
