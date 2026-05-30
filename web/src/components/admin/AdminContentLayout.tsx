'use client';

import { ReactNode } from 'react';
import AdminAppShell from '@/components/admin/AdminAppShell';

type AdminContentLayoutProps = {
  title: string;
  eyebrow?: string;
  description: string;
  actions?: ReactNode;
  children: ReactNode;
};

export default function AdminContentLayout({
  title,
  eyebrow = 'Raver Admin / Content Workspace',
  description,
  actions,
  children,
}: AdminContentLayoutProps) {
  return (
    <AdminAppShell title={title} eyebrow={eyebrow} description={description} actions={actions}>
      {children}
    </AdminAppShell>
  );
}
