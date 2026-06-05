import { Suspense } from 'react';
import DJBindingReviewWorkspace from '@/components/admin/DJBindingReviewWorkspace';

export default function DJBindingReviewsAdminPage() {
  return (
    <Suspense fallback={null}>
      <DJBindingReviewWorkspace />
    </Suspense>
  );
}
