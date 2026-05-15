import { notFound } from 'next/navigation';
import LegalDocumentView from '@/components/legal/LegalDocumentView';
import { legalDocumentMap, legalDocumentSlugs } from '@/lib/legal-documents';

export function generateStaticParams() {
  return legalDocumentSlugs.map((slug) => ({ slug }));
}

export default async function LegalPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const document = legalDocumentMap.get(slug);
  if (!document) {
    notFound();
  }
  return <LegalDocumentView document={document} />;
}
