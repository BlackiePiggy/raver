import { redirect } from 'next/navigation';

export default async function EditMyEventPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  redirect(`/admin/content/events/${id}/edit`);
}
