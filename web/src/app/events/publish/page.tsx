import { redirect } from 'next/navigation';

export default function PublishEventPage() {
  redirect('/admin/content/events/new');
}
