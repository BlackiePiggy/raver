import DJStudioCreatePageClient from '@/components/admin/DJStudioCreatePageClient';

export default async function AdminContentDJCreatePage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const resolvedSearchParams = (await searchParams) || {};
  const nameValue = resolvedSearchParams.name;
  const initialName = Array.isArray(nameValue)
    ? nameValue[0] || ''
    : nameValue || '';

  return <DJStudioCreatePageClient initialName={initialName} />;
}
