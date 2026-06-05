import { Suspense } from 'react';
import DJBindingReviewWorkspace from '@/components/admin/DJBindingReviewWorkspace';

export default function AdminContentReviewDjBindingsPage() {
  return (
    <Suspense fallback={null}>
      <DJBindingReviewWorkspace embedded />
    </Suspense>
  );
}
