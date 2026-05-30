import OrganizerStudioCreatePageClient from '@/components/admin/OrganizerStudioCreatePageClient';

export default async function AdminContentOrganizerCreatePage({
  searchParams,
}: {
  searchParams: Promise<{ name?: string | string[] }>;
}) {
  const resolved = await searchParams;
  const name = Array.isArray(resolved.name) ? resolved.name[0] : resolved.name;
  const initialName = typeof name === 'string' ? name.trim() : '';

  return <OrganizerStudioCreatePageClient initialName={initialName} />;
}
