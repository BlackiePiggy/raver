import { Suspense } from 'react';
import EventOrganizerBindingPageClient from '@/components/admin/EventOrganizerBindingPageClient';

export default function AdminContentOrganizerBindingsPage() {
  return (
    <Suspense fallback={null}>
      <EventOrganizerBindingPageClient />
    </Suspense>
  );
}
