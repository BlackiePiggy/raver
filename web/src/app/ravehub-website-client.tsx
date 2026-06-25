'use client';

import dynamic from 'next/dynamic';

const RavehubWebsiteApp = dynamic(() => import('@/ravehub-website/App'), {
  ssr: false,
  loading: () => (
    <main className="flex min-h-screen items-center justify-center bg-white text-black">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tighter md:text-6xl">Ravehub</h1>
        <div className="mx-auto mt-4 h-px w-32 bg-black/20" />
      </div>
    </main>
  ),
});

export default function RavehubWebsiteClient() {
  return <RavehubWebsiteApp />;
}
